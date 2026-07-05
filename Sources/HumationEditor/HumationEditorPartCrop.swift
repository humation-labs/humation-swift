@preconcurrency import CoreGraphics
import Humation

enum HumationEditorPartCrop {
    static func crop(
        for part: HumationManifest.Part,
        slot: HumationSelectionSlot,
        in manifest: HumationManifest
    ) -> HumationManifest.ViewBox? {
        guard let bounds = HumationRenderer.contentBounds(of: part, in: manifest) else {
            return nil
        }

        switch slot {
        case .head:
            return manifest.avatarCrop
        case .body:
            return HumationManifest.ViewBox(x: -18, y: 35, width: 116, height: 116)
        case .bottom:
            return HumationManifest.ViewBox(x: -18, y: 69, width: 116, height: 116)
        case .item:
            return scaledCrop(bounds: bounds, minimumSide: 108, scale: 1.42)
        case .glasses:
            return scaledCrop(bounds: bounds, minimumSide: 126, scale: 1.82)
        }
    }

    static func previewSize(for slot: HumationSelectionSlot) -> CGFloat {
        switch slot {
        case .item:
            return 98
        default:
            return 88
        }
    }

    private static func scaledCrop(
        bounds: CGRect,
        minimumSide: CGFloat,
        scale: CGFloat
    ) -> HumationManifest.ViewBox {
        let side = max(max(bounds.width, bounds.height) * scale, minimumSide)
        return HumationManifest.ViewBox(
            x: Double(bounds.midX - side / 2),
            y: Double(bounds.midY - side / 2),
            width: Double(side),
            height: Double(side)
        )
    }
}
