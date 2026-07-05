@preconcurrency import CoreGraphics
import Foundation
import Humation
import SwiftUI

struct HumationEditorRenderView: View {
    @Environment(\.displayScale) private var displayScale
    @State private var rendered: (key: String, image: CGImage)?

    let resolved: ResolvedHumation
    let manifest: HumationManifest
    let size: CGFloat
    var crop: HumationManifest.ViewBox?

    var body: some View {
        Group {
            if let image = displayImage {
                Image(decorative: image, scale: displayScale)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(skeletonColor)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .task(id: renderKey) {
            await loadImage()
        }
    }

    private var pixels: Int {
        let target = Int((size * displayScale).rounded(.up))
        return [32, 64, 128, 256, 512].first { $0 >= target } ?? 512
    }

    private var renderKey: String {
        let cropKey = crop.map { "\($0.x)_\($0.y)_\($0.width)_\($0.height)" } ?? "avatar"
        return "humation-editor:\(resolved.cacheToken)@\(pixels)#\(cropKey)"
    }

    private var displayImage: CGImage? {
        let key = renderKey
        if let rendered, rendered.key == key {
            return rendered.image
        }
        return HumationEditorRenderCache.shared.image(forKey: key)
    }

    private var skeletonColor: Color {
        if resolved.background != "transparent" {
            return HumationEditorColor.color(hex: resolved.background)
        }
        return .clear
    }

    private func loadImage() async {
        let key = renderKey
        if let image = HumationEditorRenderCache.shared.image(forKey: key) {
            rendered = (key, image)
            return
        }

        let resolved = resolved
        let manifest = manifest
        let pixels = pixels
        let crop = crop
        let image: CGImage? = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            if let image = HumationEditorRenderCache.shared.image(forKey: key) {
                return image
            }

            guard let image = HumationRenderer.render(
                resolved: resolved,
                manifest: manifest,
                pixels: pixels,
                crop: crop
            ) else {
                return nil
            }

            HumationEditorRenderCache.shared.set(image, forKey: key, cost: pixels * pixels * 4)
            return image
        }.value

        if !Task.isCancelled, let image {
            rendered = (key, image)
        }
    }
}

final class HumationEditorRenderCache: @unchecked Sendable {
    static let shared = HumationEditorRenderCache()

    private let cache: NSCache<NSString, CGImage>

    private init() {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        self.cache = cache
    }

    func image(forKey key: String) -> CGImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: CGImage, forKey key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}
