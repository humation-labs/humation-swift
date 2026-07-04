import Foundation

/// Codable wire-format profile for sharing humation avatar state across apps
/// and platforms. JSON keys are slot raw values; unknown keys are ignored when
/// decoding for forward compatibility.
public struct HumationProfile: Codable, Equatable, Hashable, Sendable {
    /// selectionSlot -> partId. Missing slots are seed/default-derived.
    public var selections: [HumationSelectionSlot: String]
    /// colorSlot -> normalized hex, or `"transparent"` for background.
    public var colors: [HumationColorSlot: String]

    public init(
        selections: [HumationSelectionSlot: String] = [:],
        colors: [HumationColorSlot: String] = [:]
    ) {
        self.selections = selections
        self.colors = colors.mapValues(HumationEngine.normalizeHex)
    }

    public init(resolved: ResolvedHumation) {
        var colors = resolved.colors
        let background = HumationEngine.normalizeHex(resolved.background)
        if background != "transparent" {
            colors[.background] = background
        }
        self.init(selections: resolved.selections, colors: colors)
    }

    public func traits(seed: String? = nil) -> HumationTraits {
        HumationTraits(selections: selections, colors: colors, seed: seed)
    }

    public func resolved(
        against manifest: HumationManifest,
        seed: String? = nil
    ) -> ResolvedHumation {
        traits(seed: seed).resolved(against: manifest)
    }
}

extension HumationProfile {
    private enum CodingKeys: String, CodingKey {
        case selections
        case colors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawSelections = try container.decodeIfPresent(
            [String: String].self,
            forKey: .selections
        ) ?? [:]
        let rawColors = try container.decodeIfPresent(
            [String: String].self,
            forKey: .colors
        ) ?? [:]

        var selections: [HumationSelectionSlot: String] = [:]
        for (rawSlot, partId) in rawSelections {
            guard let slot = HumationSelectionSlot(rawValue: rawSlot) else { continue }
            selections[slot] = partId
        }

        var colors: [HumationColorSlot: String] = [:]
        for (rawSlot, hex) in rawColors {
            guard let slot = HumationColorSlot(rawValue: rawSlot) else { continue }
            colors[slot] = HumationEngine.normalizeHex(hex)
        }

        self.selections = selections
        self.colors = colors
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        var rawSelections: [String: String] = [:]
        for (slot, partId) in selections {
            rawSelections[slot.rawValue] = partId
        }

        var rawColors: [String: String] = [:]
        for (slot, hex) in colors {
            rawColors[slot.rawValue] = HumationEngine.normalizeHex(hex)
        }

        try container.encode(rawSelections, forKey: .selections)
        try container.encode(rawColors, forKey: .colors)
    }
}
