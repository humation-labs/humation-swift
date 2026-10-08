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
// One-stop entry point: the default manifest, off-main prewarming, custom-pack
// loading, and seed → image one-liners. The lower-level types
// (`HumationManifest`, `HumationTraits`, `HumationRenderer`, `HumationAvatarView`)
// remain available for full control.

public enum Humation {

    /// The default manifest: the bundled `humation-1` asset set (decoded once and
    /// cached), or the override installed via `setDefaultManifest(_:)`. `nil` only
    /// if no override is set and the packaged resource is unreadable (should never
    /// happen in practice).
    public static var manifest: HumationManifest? { HumationManifestStore.current }

    /// Replace the process-wide default manifest used by every convenience API
    /// (`manifest`, `resolved`, `cgImage`/`image`, `randomProfile`, `pngData`,
    /// `HumationAvatarView`, …) — e.g. to ship a full custom asset pack. Pass
    /// `nil` to restore the bundled manifest. Thread-safe; call once at launch,
    /// before rendering, since already-resolved designs keep their part ids.
    /// Run `HumationValidator.validate` on author-made packs first.
    public static func setDefaultManifest(_ manifest: HumationManifest?) {
        HumationManifestStore.setOverride(manifest)
    }

    /// Decode the default manifest on a background thread ahead of first use, so
    /// the first on-screen avatar doesn't pay the ~660 KB JSON parse on the main
    /// thread. Safe to call multiple times; call once at app launch.
    public static func prewarm() {
        Task.detached(priority: .utility) { _ = HumationManifestStore.current }
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

    // MARK: Seed → design / image (default manifest)

    /// Seed → resolved design (selections + default colours).
    public static func resolved(seed: String) -> ResolvedHumation? {
        guard let manifest = HumationManifestStore.current else { return nil }
        return HumationTraits(seed: seed).resolved(against: manifest)
    }

    /// Profile → resolved design using the default manifest.
    ///
    /// Partial profiles are completed from `seed` when provided, then from
    /// manifest defaults. Stale or slot-mismatched profile part ids are healed by
    /// `HumationTraits.resolved(against:)`.
    public static func resolved(
        profile: HumationProfile,
        seed: String? = nil
    ) -> ResolvedHumation? {
        guard let manifest = HumationManifestStore.current else { return nil }
        return profile.resolved(against: manifest, seed: seed)
    }

    /// Seed → `CGImage` (cross-platform).
    public static func cgImage(seed: String, pixels: Int) -> CGImage? {
        guard let manifest = HumationManifestStore.current else { return nil }
        let resolved = HumationTraits(seed: seed).resolved(against: manifest)
        return HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: pixels)
    }

    /// Profile → `CGImage` (cross-platform) using the default manifest.
    public static func cgImage(
        profile: HumationProfile,
        seed: String? = nil,
        pixels: Int
    ) -> CGImage? {
        guard let manifest = HumationManifestStore.current else { return nil }
        let resolved = profile.resolved(against: manifest, seed: seed)
        return HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: pixels)
    }

    #if canImport(UIKit)
    /// Seed → `UIImage`.
    public static func image(seed: String, pixels: Int) -> UIImage? {
        cgImage(seed: seed, pixels: pixels).map { UIImage(cgImage: $0) }
    }

    /// Profile → `UIImage` using the default manifest.
    public static func image(
        profile: HumationProfile,
        seed: String? = nil,
        pixels: Int
    ) -> UIImage? {
        cgImage(profile: profile, seed: seed, pixels: pixels).map { UIImage(cgImage: $0) }
    }
    #endif

    #if canImport(AppKit)
    /// Seed → `NSImage`.
    public static func nsImage(seed: String, pixels: Int) -> NSImage? {
        cgImage(seed: seed, pixels: pixels).map {
            NSImage(cgImage: $0, size: NSSize(width: pixels, height: pixels))
        }
    }

    /// Profile → `NSImage` using the default manifest.
    public static func nsImage(
        profile: HumationProfile,
        seed: String? = nil,
        pixels: Int
    ) -> NSImage? {
        cgImage(profile: profile, seed: seed, pixels: pixels).map {
            NSImage(cgImage: $0, size: NSSize(width: pixels, height: pixels))
        }
    }
    #endif
}
