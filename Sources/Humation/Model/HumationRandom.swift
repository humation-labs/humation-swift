import Foundation

// MARK: - Random avatars
//
// A random avatar picks a random part per selection slot (from the manifest) and
// a random colour per slot (from `HumationColorSlot.defaultSwatches`). Passing an
// explicit `RandomNumberGenerator` makes the result reproducible — handy for
// tests, previews, or seeded "shuffle" experiences.

extension HumationProfile {
    /// A random profile resolved against `manifest`, drawing randomness from
    /// `generator`. Every selection slot with available parts gets a random pick;
    /// every colour slot gets a random swatch.
    public static func random(
        in manifest: HumationManifest,
        using generator: inout some RandomNumberGenerator
    ) -> HumationProfile {
        var selections: [HumationSelectionSlot: String] = [:]
        for slot in HumationSelectionSlot.allCases {
            if let pick = manifest.parts(in: slot).randomElement(using: &generator) {
                selections[slot] = pick.id
            }
        }

        var colors: [HumationColorSlot: String] = [:]
        for slot in HumationColorSlot.allCases {
            if let hex = slot.defaultSwatches.randomElement(using: &generator) {
                colors[slot] = hex
            }
        }

        return HumationProfile(selections: selections, colors: colors)
    }

    /// A random profile using the system random number generator.
    public static func random(in manifest: HumationManifest) -> HumationProfile {
        var generator = SystemRandomNumberGenerator()
        return random(in: manifest, using: &generator)
    }
}

extension Humation {
    /// A random profile using the bundled manifest, or `nil` if the manifest is
    /// unavailable. Pair with `image(profile:pixels:)` for a one-line "surprise
    /// me" avatar.
    public static func randomProfile() -> HumationProfile? {
        guard let manifest = HumationManifestStore.shared else { return nil }
        return HumationProfile.random(in: manifest)
    }

    /// A random profile using the bundled manifest and an explicit generator
    /// (reproducible), or `nil` if the manifest is unavailable.
    public static func randomProfile(
        using generator: inout some RandomNumberGenerator
    ) -> HumationProfile? {
        guard let manifest = HumationManifestStore.shared else { return nil }
        return HumationProfile.random(in: manifest, using: &generator)
    }
}
