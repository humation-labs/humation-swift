import Foundation

// MARK: - Slot display metadata
//
// Human-readable titles and curated colour swatches for the avatar slots. These
// let callers build their own picker / editor UI (tabs, swatch grids) without
// hand-maintaining parallel tables, and back the randomisation API.

extension HumationSelectionSlot {
    /// Human-readable title for UI, e.g. a slot tab label.
    public var displayName: String {
        switch self {
        case .head: return "Head"
        case .body: return "Body"
        case .bottom: return "Bottom"
        case .item: return "Item"
        case .glasses: return "Glasses"
        }
    }
}

extension HumationColorSlot {
    /// Human-readable title for UI, e.g. a colour-slot label.
    public var displayName: String {
        switch self {
        case .background: return "Background"
        case .stroke: return "Outline"
        case .hair: return "Hair"
        case .skin: return "Skin"
        case .clothes: return "Clothes"
        case .bottom: return "Bottom"
        }
    }

    /// A curated set of sensible swatches for this colour slot — suitable for a
    /// colour picker or for randomising an avatar. Values are 6-char uppercase
    /// hex without a leading `#`.
    public var defaultSwatches: [String] {
        switch self {
        case .background:
            return ["FFFFFF", "F2F2F7", "E5E5EA", "D1D1D6", "FFD8A8", "D0EBFF", "E7F5D0", "FFE3E3"]
        case .stroke:
            return ["1C1C1E", "3A3A3C", "8E8E93"]
        case .hair:
            return ["1C1C1E", "3A3A3C", "8E8E93", "A2845E", "6B4423", "C9A227", "FF9500", "AF52DE"]
        case .skin:
            return ["FFE0BD", "F1C27D", "E0AC69", "C68642", "8D5524", "FFDFC4", "F0D5B1"]
        case .clothes, .bottom:
            return [
                "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE", "32ADE6",
                "007AFF", "5856D6", "AF52DE", "FF2D55", "1C1C1E", "FFFFFF",
            ]
        }
    }
}
