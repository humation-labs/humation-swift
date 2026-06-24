import CoreGraphics
import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Humation facade
//
// One-stop entry point: the bundled manifest, off-main prewarming, custom-pack
// loading, and seed → image one-liners. The lower-level types
// (`HumationManifest`, `HumationTraits`, `HumationRenderer`, `HumationAvatarView`)
// remain available for full control.

public enum Humation {

    /// The bundled `humation-1` manifest, decoded once and cached. `nil` only if
    /// the packaged resource is unreadable (should never happen in practice).
    public static var manifest: HumationManifest? { HumationManifestStore.shared }

    /// Decode the bundled manifest on a background thread ahead of first use, so
    /// the first on-screen avatar doesn't pay the ~660 KB JSON parse on the main
    /// thread. Safe to call multiple times; call once at app launch.
    public static func prewarm() {
        Task.detached(priority: .utility) { _ = HumationManifestStore.shared }
    }

    // MARK: Custom packs

    /// Decode a manifest from JSON data (e.g. an additional/served asset pack).
    /// Run `HumationValidator.validate` on it before shipping author-made parts.
    public static func manifest(from data: Data) throws -> HumationManifest {
        try JSONDecoder().decode(HumationManifest.self, from: data)
    }

    /// Decode a manifest from a JSON file URL.
    public static func manifest(contentsOf url: URL) throws -> HumationManifest {
        try manifest(from: Data(contentsOf: url))
    }

    // MARK: Seed → design / image (bundled manifest)

    /// Seed → resolved design (selections + default colours).
    public static func resolved(seed: String) -> ResolvedHumation? {
        guard let manifest = HumationManifestStore.shared else { return nil }
        return HumationTraits(seed: seed).resolved(against: manifest)
    }

    /// Seed → `CGImage` (cross-platform).
    public static func cgImage(seed: String, pixels: Int) -> CGImage? {
        guard let manifest = HumationManifestStore.shared else { return nil }
        let resolved = HumationTraits(seed: seed).resolved(against: manifest)
        return HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: pixels)
    }

    #if canImport(UIKit)
    /// Seed → `UIImage`.
    public static func image(seed: String, pixels: Int) -> UIImage? {
        cgImage(seed: seed, pixels: pixels).map { UIImage(cgImage: $0) }
    }
    #endif

    #if canImport(AppKit)
    /// Seed → `NSImage`.
    public static func nsImage(seed: String, pixels: Int) -> NSImage? {
        cgImage(seed: seed, pixels: pixels).map {
            NSImage(cgImage: $0, size: NSSize(width: pixels, height: pixels))
        }
    }
    #endif
}
