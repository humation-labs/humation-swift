import Humation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum HumationEditorColor {
    static func color(hex raw: String) -> Color {
        let normalized = HumationEngine.normalizeHex(raw)
        if normalized == "transparent" {
            return .clear
        }

        guard normalized.count == 6, let value = UInt64(normalized, radix: 16) else {
            return .gray
        }

        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    static var background: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.clear
        #endif
    }

    static var secondaryBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.secondary.opacity(0.10)
        #endif
    }
}
