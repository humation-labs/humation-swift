import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Humation renderer (pure)
//
// Composes a resolved avatar into a `CGImage`, matching the reference engine 1:1:
//   • each selected part's layers are positioned by their `layerSlot.offset`
//     and drawn in `layerSlot.order` (ascending);
//   • the crop viewBox (default avatar head-shot, -4/-4.5/88/88) frames the
//     result; the context is flipped to SVG's top-left, y-down space;
//   • the SVG's own width/height/viewBox are irrelevant (only inner geometry +
//     the layer offset matter), exactly as `stripSvgWrapper` does upstream.
//
// Pure and thread-agnostic — safe to call from the image-provider actor or
// synchronously.

public enum HumationAvatarShape: Sendable {
    case square
    case circle
}

public enum HumationRenderer {

    /// Render at an exact pixel size to a `CGImage` (cross-platform).
    ///
    /// `crop` overrides the framing viewBox — the avatar head-shot is the default,
    /// but the editor passes a part-focused square crop so a slot's thumbnails
    /// frame the part being edited. The crop is assumed square (output is
    /// `pixels × pixels`). Returns nil only if a context can't be created.
    public static func render(
        resolved: ResolvedHumation,
        manifest: HumationManifest,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) -> CGImage? {
        let crop = crop ?? manifest.avatarCrop
        let side = CGFloat(pixels)
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        let scale = side / CGFloat(crop.width) // crop is square

        let isOpaque = resolved.background != "transparent"
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard
            pixels > 0,
            let ctx = CGContext(
                data: nil,
                width: pixels,
                height: pixels,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }

        ctx.clear(rect)

        // Flip into SVG's top-left, y-down space.
        ctx.translateBy(x: 0, y: side)
        ctx.scaleBy(x: 1, y: -1)

        if shape == .circle {
            ctx.addEllipse(in: rect)
            ctx.clip()
        }

        if isOpaque, let bg = HumationRGBA(hex: resolved.background) {
            ctx.setFillColor(bg.cgColor)
            ctx.fill(rect)
        }

        // World → pixel: scale, then shift the crop origin to (0,0).
        let base = CGAffineTransform(
            a: scale, b: 0, c: 0, d: scale,
            tx: -CGFloat(crop.x) * scale,
            ty: -CGFloat(crop.y) * scale
        )

        ctx.saveGState()
        ctx.concatenate(base)
        for fragment in collectFragments(resolved: resolved, manifest: manifest) {
            ctx.saveGState()
            ctx.translateBy(x: fragment.offset.x, y: fragment.offset.y)
            draw(part: fragment.part, resolved: resolved, in: ctx)
            ctx.restoreGState()
        }
        ctx.restoreGState()

        return ctx.makeImage()
    }

    #if canImport(UIKit)
    /// `UIImage` convenience over `render`.
    public static func image(
        resolved: ResolvedHumation,
        manifest: HumationManifest,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) -> UIImage? {
        guard
            let cg = render(
                resolved: resolved, manifest: manifest, pixels: pixels, crop: crop, shape: shape
            )
        else { return nil }
        return UIImage(cgImage: cg)
    }
    #endif

    #if canImport(AppKit)
    /// `NSImage` convenience over `render`.
    public static func nsImage(
        resolved: ResolvedHumation,
        manifest: HumationManifest,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) -> NSImage? {
        guard
            let cg = render(
                resolved: resolved, manifest: manifest, pixels: pixels, crop: crop, shape: shape
            )
        else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: pixels, height: pixels))
    }
    #endif

    /// PNG data convenience for notification-extension image payloads.
    public static func pngData(
        resolved: ResolvedHumation,
        manifest: HumationManifest,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) -> Data? {
        guard
            let cg = render(
                resolved: resolved, manifest: manifest, pixels: pixels, crop: crop, shape: shape
            )
        else { return nil }

        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil
            )
        else { return nil }

        CGImageDestinationAddImage(destination, cg, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// World-space bounding box of a part's drawn content (path bounds + stroke
    /// allowance, offset by its layer). Lets callers frame a part tightly without
    /// touching the internal geometry model. Returns nil for empty parts.
    public static func contentBounds(
        of part: HumationManifest.Part, in manifest: HumationManifest
    ) -> CGRect? {
        var rect = CGRect.null
        for layer in part.layers {
            guard let svg = layer.svg, let ls = manifest.layerSlot(id: layer.layerSlot) else {
                continue
            }
            let parsed = HumationGeometryCache.shared.parsed(
                key: "\(part.id)#\(layer.layerSlot)", svg: svg
            )
            for shape in parsed.shapes {
                var bb = shape.path.boundingBoxOfPath
                guard !bb.isNull, bb.width.isFinite, bb.height.isFinite else { continue }
                if shape.paint.strokeWidth > 0 {
                    let half = shape.paint.strokeWidth / 2
                    bb = bb.insetBy(dx: -half, dy: -half)
                }
                bb = bb.offsetBy(dx: ls.offset.x, dy: ls.offset.y)
                rect = rect.union(bb)
            }
        }
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    // MARK: Fragment collection

    private struct Fragment {
        let part: HumationParsedPart
        let offset: CGPoint
        let order: Int
    }

    private static func collectFragments(
        resolved: ResolvedHumation,
        manifest: HumationManifest
    ) -> [Fragment] {
        var fragments: [Fragment] = []
        for slot in HumationSelectionSlot.allCases {
            guard
                let partId = resolved.selections[slot],
                let part = manifest.part(id: partId)
            else { continue }

            for layer in part.layers {
                guard
                    let svg = layer.svg,
                    let layerSlot = manifest.layerSlot(id: layer.layerSlot)
                else { continue }

                let key = "\(partId)#\(layer.layerSlot)"
                let parsed = HumationGeometryCache.shared.parsed(key: key, svg: svg)
                fragments.append(
                    Fragment(
                        part: parsed,
                        offset: CGPoint(x: layerSlot.offset.x, y: layerSlot.offset.y),
                        order: layerSlot.order
                    )
                )
            }
        }
        fragments.sort { $0.order < $1.order }
        return fragments
    }

    // MARK: Part drawing

    private static func draw(
        part: HumationParsedPart,
        resolved: ResolvedHumation,
        in ctx: CGContext
    ) {
        for shape in part.shapes {
            ctx.saveGState()

            for clipID in shape.clipPathIDs {
                if let clip = part.clips[clipID] {
                    ctx.addPath(clip.path)
                    ctx.clip(using: clip.fillRule)
                }
            }

            if shape.paint.opacity < 1 {
                ctx.setAlpha(shape.paint.opacity)
            }

            if let fill = color(shape.paint.fill, resolved: resolved) {
                ctx.setFillColor(fill)
                ctx.addPath(shape.path)
                ctx.fillPath(using: shape.paint.fillRule)
            }

            if let stroke = color(shape.paint.stroke, resolved: resolved) {
                ctx.setStrokeColor(stroke)
                ctx.setLineWidth(shape.paint.strokeWidth)
                ctx.setLineCap(shape.paint.lineCap)
                ctx.setLineJoin(shape.paint.lineJoin)
                ctx.setMiterLimit(shape.paint.miterLimit)
                ctx.addPath(shape.path)
                ctx.strokePath()
            }

            ctx.restoreGState()
        }
    }

    private static func color(
        _ svgColor: HumationSVGColor,
        resolved: ResolvedHumation
    ) -> CGColor? {
        switch svgColor {
        case .none:
            return nil
        case let .fixed(rgba):
            return rgba.cgColor
        case let .slot(slot, fallback):
            if let hex = resolved.hex(for: slot), let rgba = HumationRGBA(hex: hex) {
                return rgba.cgColor
            }
            return fallback.cgColor
        }
    }
}
