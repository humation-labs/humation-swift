import Foundation

// MARK: - Slots

/// The five exclusive part slots a humation avatar is composed from.
public enum HumationSelectionSlot: String, CaseIterable, Codable, Sendable {
    case head, body, bottom, item, glasses
}

/// The six recolourable colour slots. `background` is the tile fill; the rest
/// bind to `var(--hm-*)` references inside the SVG fragments.
public enum HumationColorSlot: String, CaseIterable, Codable, Sendable {
    case background, stroke, hair, skin, clothes, bottom
}

// MARK: - Traits

/// A humation avatar's input state. Slots left unset fall back to the seed
/// (for selections) or the manifest defaults (for colours) at resolve time.
public struct HumationTraits: Equatable, Hashable, Sendable {
    /// selectionSlot → partId. Missing slots are seed/default-derived.
    public var selections: [HumationSelectionSlot: String]
    /// colorSlot → 6-char uppercase hex (no `#`). Missing slots use defaults.
    public var colors: [HumationColorSlot: String]
    /// Seed used to derive any unset selection slots. Typically the user id.
    public var seed: String?

    public init(
        selections: [HumationSelectionSlot: String] = [:],
        colors: [HumationColorSlot: String] = [:],
        seed: String? = nil
    ) {
        self.selections = selections
        self.colors = colors
        self.seed = seed
    }
}

// MARK: - Resolution (the engine)

/// Fully-resolved render state: every selection slot has a concrete partId and
/// every colour slot a concrete hex. Produced from `HumationTraits` against the
/// manifest; consumed by `HumationRenderer`.
public struct ResolvedHumation: Equatable, Hashable, Sendable {
    public var selections: [HumationSelectionSlot: String]
    public var colors: [HumationColorSlot: String]
    public var background: String

    public init(
        selections: [HumationSelectionSlot: String],
        colors: [HumationColorSlot: String],
        background: String
    ) {
        self.selections = selections
        self.colors = colors
        self.background = background
    }

    /// Stable identity for caching (order-independent over the dictionaries).
    public var cacheToken: UInt64 {
        var hasher = Hasher()
        for slot in HumationSelectionSlot.allCases { hasher.combine(selections[slot]) }
        for slot in HumationColorSlot.allCases { hasher.combine(colors[slot]) }
        hasher.combine(background)
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    /// Hex for a colour slot (`background` lives separately from `colors`).
    public func hex(for slot: HumationColorSlot) -> String? {
        slot == .background ? background : colors[slot]
    }
}

extension HumationTraits {
    /// Resolve to concrete parts/colours. Mirrors the reference `resolveAvatarState`:
    /// start from manifest defaults, apply seeded picks for every slot when a
    /// seed is present, then let explicit `selections`/`colors` override.
    public func resolved(against manifest: HumationManifest) -> ResolvedHumation {
        // 1. Defaults.
        var resolvedSelections: [HumationSelectionSlot: String] = [:]
        for slot in HumationSelectionSlot.allCases {
            if let def = manifest.defaults.selections[slot.rawValue] {
                resolvedSelections[slot] = def
            }
        }

        // 2. Seeded picks (override defaults for every slot that has parts).
        if let seed {
            for slot in HumationSelectionSlot.allCases {
                let slotParts = manifest.parts(in: slot)
                guard !slotParts.isEmpty else { continue }
                let hash = HumationEngine.fnv1a("\(seed):\(slot.rawValue)")
                resolvedSelections[slot] = slotParts[Int(hash % UInt32(slotParts.count))].id
            }
        }

        // 3. Explicit selection overrides.
        for (slot, partId) in selections {
            resolvedSelections[slot] = partId
        }

        // 4. Colours: defaults then overrides.
        var resolvedColors: [HumationColorSlot: String] = [:]
        for slot in HumationColorSlot.allCases where slot != .background {
            if let def = manifest.defaults.colors[slot.rawValue] {
                resolvedColors[slot] = HumationEngine.normalizeHex(def)
            }
        }
        for (slot, hex) in colors where slot != .background {
            resolvedColors[slot] = HumationEngine.normalizeHex(hex)
        }

        let background = HumationEngine.normalizeHex(
            colors[.background] ?? manifest.defaults.background
        )

        return ResolvedHumation(
            selections: resolvedSelections,
            colors: resolvedColors,
            background: background
        )
    }
}

// MARK: - Engine primitives

public enum HumationEngine {
    /// FNV-1a 32-bit hash. Matches the reference TypeScript byte-for-byte:
    /// `charCodeAt` → UTF-16 code units (`.utf16`); `Math.imul` 32-bit wrap →
    /// `&*`; `>>> 0` is a no-op for `UInt32`. Determinism across web/iOS depends
    /// on this being identical, so do not "optimise" `.utf16` to `.utf8`.
    public static func fnv1a(_ input: String) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5
        for unit in input.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 0x0100_0193
        }
        return hash
    }

    /// Uppercased, `#`-stripped hex. Leaves the literal `"transparent"` intact.
    public static func normalizeHex(_ value: String) -> String {
        if value.caseInsensitiveCompare("transparent") == .orderedSame {
            return "transparent"
        }
        var hex = value
        if hex.hasPrefix("#") { hex.removeFirst() }
        return hex.uppercased()
    }
}
