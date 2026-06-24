import Foundation

// MARK: - Manifest validation
//
// Catches author mistakes in custom/served asset packs before they render
// wrong: SVG features the native renderer doesn't implement (arcs `A`,
// quadratics `Q`/`T`), and structural references that don't resolve.

public struct HumationValidationIssue: Sendable, CustomStringConvertible {
    public let partId: String
    public let partName: String?
    public let message: String

    public var description: String {
        "[\(partId)\(partName.map { " \($0)" } ?? "")] \(message)"
    }
}

public enum HumationValidator {
    /// Validate every part in a manifest. An empty result means the pack is
    /// renderable by this engine.
    public static func validate(_ manifest: HumationManifest) -> [HumationValidationIssue] {
        var issues: [HumationValidationIssue] = []

        for part in manifest.parts {
            func add(_ message: String) {
                issues.append(
                    HumationValidationIssue(partId: part.id, partName: part.name, message: message)
                )
            }

            if HumationSelectionSlot(rawValue: part.selectionSlot) == nil {
                add("unknown selectionSlot '\(part.selectionSlot)'")
            }

            for layer in part.layers {
                if manifest.layerSlot(id: layer.layerSlot) == nil {
                    add("unknown layerSlot '\(layer.layerSlot)'")
                }
                guard let svg = layer.svg else { continue }
                for d in pathData(in: svg) where d.contains(where: { "AaQqTt".contains($0) }) {
                    add("layer '\(layer.layerSlot)' uses an unsupported path command "
                        + "(arcs A/a or quadratics Q/q/T/t are not rendered)")
                    break
                }
            }
        }
        return issues
    }

    /// Extract the values of every `d="…"` attribute in an SVG fragment.
    private static func pathData(in svg: String) -> [String] {
        var result: [String] = []
        var rest = Substring(svg)
        while let open = rest.range(of: "d=\"") {
            let after = rest[open.upperBound...]
            guard let close = after.firstIndex(of: "\"") else { break }
            result.append(String(after[..<close]))
            rest = after[after.index(after: close)...]
        }
        return result
    }
}
