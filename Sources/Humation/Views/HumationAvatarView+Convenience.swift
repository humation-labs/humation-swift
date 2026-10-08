import CoreGraphics
import SwiftUI

// MARK: - Ergonomic initialisers
//
// Convenience inits that resolve against the default manifest (bundled unless
// overridden via `Humation.setDefaultManifest(_:)`) so callers don't have to
// thread `Humation.resolved(...)` through every call site. If the default
// manifest is somehow unavailable, they fall back to an empty design (renders the
// skeleton) rather than failing — the manifest loads synchronously on first
// access, so this only bites if the bundle resource is missing.

extension HumationAvatarView {
    /// Render the avatar for a `seed`, resolved against the default manifest.
    public init(seed: String, size: CGFloat, crop: HumationManifest.ViewBox? = nil) {
        let resolved = Humation.resolved(seed: seed) ?? .empty
        self.init(resolved: resolved, size: size, crop: crop)
    }

    /// Render a `profile`, resolved against the default manifest, with `seed`
    /// completing any slots the profile leaves unset.
    public init(
        profile: HumationProfile,
        seed: String? = nil,
        size: CGFloat,
        crop: HumationManifest.ViewBox? = nil
    ) {
        let resolved = Humation.resolved(profile: profile, seed: seed) ?? .empty
        self.init(resolved: resolved, size: size, crop: crop)
    }
}

extension ResolvedHumation {
    /// Empty design used as a graceful fallback when the manifest is unavailable.
    static let empty = ResolvedHumation(selections: [:], colors: [:], background: "transparent")
}
