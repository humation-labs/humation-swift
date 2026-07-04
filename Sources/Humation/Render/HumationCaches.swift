@preconcurrency import CoreGraphics
import Foundation

// MARK: - L1 geometry cache
//
// Parses each part-layer SVG once into transform-baked, colour-bound geometry,
// then reuses it across every recolour and size (geometry is colour/size
// independent). NSCache is thread-safe and evicts under memory pressure.

final class HumationGeometryCache: @unchecked Sendable {
    static let shared = HumationGeometryCache()

    private final class Box {
        let part: HumationParsedPart
        init(_ part: HumationParsedPart) { self.part = part }
    }

    private let cache = NSCache<NSString, Box>()

    private init() {
        cache.countLimit = 120 // a touch above the 86-part total
    }

    func parsed(key: String, svg: String) -> HumationParsedPart {
        if let box = cache.object(forKey: key as NSString) {
            return box.part
        }
        let parsed = HumationSVGParser.parse(svg)
        cache.setObject(Box(parsed), forKey: key as NSString)
        return parsed
    }
}

// MARK: - Size bucketing
//
// Editors render at a few point sizes (preview ~120pt, thumbnails ~96pt).
// Rendering one bitmap per exact pixel size would multiply renders, so snap up
// to a bucket and let `Image.resizable` downscale — vector raster downscaling
// stays crisp and identically-sized avatars share one cached bitmap.

enum HumationBucket {
    static let sizes = [32, 64, 128, 256, 512]

    static func pixels(forPoint pointSize: CGFloat, scale: CGFloat) -> Int {
        let target = Int((pointSize * scale).rounded(.up))
        return sizes.first { $0 >= target } ?? sizes.last!
    }
}

// MARK: - Image provider (memory-only bitmap cache)
//
// Backs the SwiftUI views' live preview + thumbnails. A dedicated memory-only
// NSCache of `CGImage`s (cross-platform — no UIKit) keeps these transient
// renders cheap to regenerate; the actor coalesces in-flight renders so a grid
// doesn't render the same design twice.

actor HumationImageProvider {
    static let shared = HumationImageProvider()

    // NSCache is internally thread-safe; the unsafe annotation just opts this
    // known-safe global out of Swift 6's Sendable check.
    private nonisolated(unsafe) static let bitmapCache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 24 * 1024 * 1024 // ~24 MB of editor renders
        return cache
    }()

    private var pending: [String: Task<CGImage?, Never>] = [:]

    /// Synchronous memory-cache peek for the view's no-flash fast path.
    nonisolated static func memoryImage(forKey key: String) -> CGImage? {
        bitmapCache.object(forKey: key as NSString)
    }

    nonisolated static func cacheKey(
        _ resolved: ResolvedHumation,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) -> String {
        let cropKey = crop.map { "\($0.x)_\($0.y)_\($0.width)_\($0.height)" } ?? "avatar"
        let base = "humation:\(resolved.cacheToken)@\(pixels)#\(cropKey)"
        switch shape {
        case .square:
            return base
        case .circle:
            return "\(base)|circle"
        }
    }

    func image(
        for resolved: ResolvedHumation,
        pixels: Int,
        crop: HumationManifest.ViewBox? = nil,
        shape: HumationAvatarShape = .square
    ) async -> CGImage? {
        let key = Self.cacheKey(resolved, pixels: pixels, crop: crop, shape: shape)

        if let cached = Self.memoryImage(forKey: key) { return cached }
        if let inFlight = pending[key] { return await inFlight.value }

        let task = Task { () -> CGImage? in
            guard let manifest = HumationManifestStore.shared else { return nil }
            guard
                let image = HumationRenderer.render(
                    resolved: resolved,
                    manifest: manifest,
                    pixels: pixels,
                    crop: crop,
                    shape: shape
                )
            else { return nil }
            Self.bitmapCache.setObject(image, forKey: key as NSString, cost: pixels * pixels * 4)
            return image
        }
        pending[key] = task
        let image = await task.value
        pending[key] = nil
        return image
    }
}
