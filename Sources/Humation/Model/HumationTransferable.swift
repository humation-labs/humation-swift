import Foundation

// MARK: - PNG export
//
// A direct-to-bytes convenience so callers can hand an avatar to the share
// sheet, a drag session, or any API that wants image `Data` without reaching for
// the manifest themselves.

extension ResolvedHumation {
    /// PNG bytes for this design rendered against the bundled manifest, or `nil`
    /// if the manifest is unavailable.
    public func pngData(pixels: Int = 512, shape: HumationAvatarShape = .square) -> Data? {
        guard let manifest = HumationManifestStore.shared else { return nil }
        return HumationRenderer.pngData(
            resolved: self, manifest: manifest, pixels: pixels, shape: shape
        )
    }
}

// MARK: - Transferable
//
// Conforming `ResolvedHumation` to `Transferable` makes avatars work out of the
// box with `ShareLink(item:)`, drag-and-drop, and copy/paste — the item exports
// as a 512px square PNG. Gated to the OS versions where `Transferable` exists
// (the package itself still deploys back to iOS 15 / macOS 12).

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers

/// Error surfaced when a `Transferable` avatar export cannot render (the bundled
/// manifest is missing).
public enum HumationExportError: Error, Sendable {
    case renderingUnavailable
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, visionOS 1.0, *)
extension ResolvedHumation: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { resolved in
            guard let data = resolved.pngData() else {
                throw HumationExportError.renderingUnavailable
            }
            return data
        }
        .suggestedFileName("avatar.png")
    }
}
#endif
