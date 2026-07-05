import CoreGraphics
import Humation
import SwiftUI

/// Configuration for the reusable Humation avatar editor UI.
public struct HumationEditorConfiguration: Sendable {
    /// Segmented tab structure.
    public var tabs: [Tab]
    /// Hex colour palettes by Humation colour slot.
    public var colorPalettes: [HumationColorSlot: [String]]
    /// Selection highlight colour.
    public var accent: Color
    /// Cell background. When nil, a platform secondary background is used.
    public var cellBackground: Color?
    /// Cell corner radius.
    public var cornerRadius: CGFloat
    /// Font provider used by editor labels and controls.
    public var font: @Sendable (_ size: CGFloat, _ weight: Font.Weight) -> Font
    /// Whether the background colour slot is shown in the editor.
    public var showsBackgroundColors: Bool

    public init(
        tabs: [Tab] = Self.defaultTabs,
        colorPalettes: [HumationColorSlot: [String]] = Self.defaultColorPalettes,
        accent: Color = .accentColor,
        cellBackground: Color? = nil,
        cornerRadius: CGFloat = 20,
        font: @escaping @Sendable (_ size: CGFloat, _ weight: Font.Weight) -> Font = {
            .system(size: $0, weight: $1, design: .rounded)
        },
        showsBackgroundColors: Bool = true
    ) {
        self.tabs = tabs
        self.colorPalettes = colorPalettes
        self.accent = accent
        self.cellBackground = cellBackground
        self.cornerRadius = cornerRadius
        self.font = font
        self.showsBackgroundColors = showsBackgroundColors
    }

    public struct Tab: Sendable, Identifiable, Equatable {
        public var title: String
        public var slots: [HumationSelectionSlot]

        public var id: String {
            "\(title):\(slots.map(\.rawValue).joined(separator: ","))"
        }

        public init(title: String, slots: [HumationSelectionSlot]) {
            self.title = title
            self.slots = slots
        }
    }
}

public extension HumationEditorConfiguration {
    static let defaultTabs: [Tab] = [
        Tab(title: "Hair", slots: [.head]),
        Tab(title: "Wear", slots: [.body, .bottom]),
        Tab(title: "Gear", slots: [.item, .glasses]),
    ]

    static let defaultColorPalettes: [HumationColorSlot: [String]] = [
        .background: neutralPalette + osColorScale,
        .stroke: ["1C1C1E", "3A3A3C", "8E8E93"] + osColorScale,
        .hair: hairPalette,
        .skin: skinColorPalette,
        .clothes: clothesPalette,
        .bottom: clothesPalette,
    ]

    private static let osColorScale = [
        "FF3B30",
        "FF9500",
        "FFCC00",
        "34C759",
        "00C7BE",
        "30B0C7",
        "32ADE6",
        "007AFF",
        "5856D6",
        "AF52DE",
        "FF2D55",
    ]

    private static let neutralPalette = [
        "FFFFFF",
        "F2F2F7",
        "E5E5EA",
        "D1D1D6",
        "8E8E93",
        "3A3A3C",
        "1C1C1E",
    ]

    private static let hairPalette = [
        "1C1C1E",
        "3A3A3C",
        "8E8E93",
        "A2845E",
        "FF3B30",
        "FF9500",
        "FFCC00",
        "34C759",
        "00C7BE",
        "32ADE6",
        "007AFF",
        "5856D6",
        "AF52DE",
        "FF2D55",
    ]

    private static let skinPalette = [
        "FFF2E8",
        "FFD7B5",
        "F7C08A",
        "D99A5B",
        "A96A3A",
        "7A4A28",
    ]

    private static let skinColorPalette = [
        "FFFFFF",
    ] + skinPalette + [
        "1C1C1E",
    ]

    private static let clothesPalette = [
        "FFFFFF",
        "1C1C1E",
    ] + osColorScale
}
