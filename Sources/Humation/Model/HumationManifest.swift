import Foundation

// MARK: - Humation Manifest
//
// Codable mirror of `humation-1.json` (generated from the open-source
// `@humation/assets-humation-1` embedded manifest). The JSON inlines each
// part's SVG fragment, so no per-file asset loading is required — one bundle
// resource holds the whole asset set.
//
// We only model the fields the native renderer needs; unknown keys
// (`label`, `source`, `aliases`, `tags`, `cssVariable`, …) are ignored by
// Codable. Coordinate/colour semantics match the reference engine exactly so
// rendering is 1:1 — see `HumationRenderer` for the composition math.

public struct HumationManifest: Codable, Sendable {
    public let schemaVersion: String
    public let template: Template
    public let defaults: Defaults
    public let crops: [String: ViewBox]
    public let selectionSlots: [SelectionSlot]
    public let layerSlots: [LayerSlot]
    public let parts: [Part]

    public struct Template: Codable, Sendable {
        public let id: String
        public let shortId: String
        public let name: String
        public let version: String
    }

    public struct Defaults: Codable, Sendable {
        /// selectionSlot.id → partId
        public let selections: [String: String]
        /// colorSlot.id → 6-char hex (no `#`); note `background` lives separately.
        public let colors: [String: String]
        /// 6-char hex or the literal `"transparent"`.
        public let background: String
        public let crop: String
    }

    public struct ViewBox: Codable, Sendable, Equatable, Hashable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double

        public init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }
    }

    public struct SelectionSlot: Codable, Sendable {
        public let id: String
        public let defaultPart: String
    }

    public struct LayerSlot: Codable, Sendable {
        public let id: String
        public let order: Int
        public let offset: Point
        public let size: Size
        public let hidden: Bool?

        public struct Point: Codable, Sendable {
            public let x: Double
            public let y: Double
        }

        public struct Size: Codable, Sendable {
            public let width: Double
            public let height: Double
        }
    }

    public struct Part: Codable, Sendable {
        public let id: String
        public let name: String?
        public let selectionSlot: String
        public let uiGroups: [String]
        public let layers: [Layer]

        public struct Layer: Codable, Sendable {
            public let layerSlot: String
            /// Inline SVG fragment (`<svg …>…</svg>`). Present in the embedded
            /// manifest we ship; `svgPath` is the non-embedded variant we don't use.
            public let svg: String?
            public let transform: String?
        }
    }
}

// MARK: - Lookup helpers

extension HumationManifest {
    /// The headshot crop used for avatars (falls back to the manifest default).
    public var avatarCrop: ViewBox {
        crops[defaults.crop] ?? crops["avatar"] ?? ViewBox(x: 0, y: 0, width: 80, height: 80)
    }

    /// Parts for a slot in raw manifest array order. This MUST stay unsorted:
    /// the reference engine seeds via `manifest.parts.filter(...)[hash % count]`
    /// in array order, and the item slot's array order differs from id order, so
    /// sorting here would pick a different part than the web for the same seed
    /// and break 1:1 determinism.
    public func parts(in slot: HumationSelectionSlot) -> [Part] {
        parts.filter { $0.selectionSlot == slot.rawValue }
    }

    public func part(id: String) -> Part? {
        parts.first { $0.id == id }
    }

    public func layerSlot(id: String) -> LayerSlot? {
        layerSlots.first { $0.id == id }
    }
}

// MARK: - Shared store

/// Loads and caches the bundled manifest once. Decoding ~660KB of JSON is done
/// lazily on first access and held for the process lifetime (the manifest is
/// immutable and small in memory once the inline SVG strings are parsed away by
/// the renderer's geometry cache).
public enum HumationManifestStore {
    /// Decoded manifest, or `nil` if the bundle resource is missing/corrupt.
    public static let shared: HumationManifest? = load()

    private static func load() -> HumationManifest? {
        guard
            let url = Bundle.module.url(forResource: "humation-1", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let manifest = try? JSONDecoder().decode(HumationManifest.self, from: data)
        else {
            return nil
        }
        return manifest
    }
}
