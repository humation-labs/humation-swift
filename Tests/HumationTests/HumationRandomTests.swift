import XCTest

@testable import Humation

final class HumationRandomTests: XCTestCase {

    /// Deterministic generator so random tests are reproducible (SplitMix64).
    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func manifest() throws -> HumationManifest {
        try XCTUnwrap(HumationManifestStore.shared, "bundled manifest should load")
    }

    // MARK: random(in:using:)

    func testRandomIsReproducibleWithSeededGenerator() throws {
        let manifest = try manifest()
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        XCTAssertEqual(
            HumationProfile.random(in: manifest, using: &a),
            HumationProfile.random(in: manifest, using: &b)
        )
    }

    func testDifferentSeedsGiveDifferentProfiles() throws {
        let manifest = try manifest()
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 99)
        XCTAssertNotEqual(
            HumationProfile.random(in: manifest, using: &a),
            HumationProfile.random(in: manifest, using: &b)
        )
    }

    func testRandomSelectionsAreValidPartsInTheRightSlot() throws {
        let manifest = try manifest()
        var gen = SeededGenerator(seed: 7)
        let profile = HumationProfile.random(in: manifest, using: &gen)
        for (slot, partId) in profile.selections {
            let part = try XCTUnwrap(manifest.part(id: partId), "\(partId) should exist")
            XCTAssertEqual(part.selectionSlot, slot.rawValue)
        }
    }

    func testRandomColorsComeFromDefaultSwatches() throws {
        let manifest = try manifest()
        var gen = SeededGenerator(seed: 3)
        let profile = HumationProfile.random(in: manifest, using: &gen)
        for (slot, hex) in profile.colors {
            XCTAssertTrue(
                slot.defaultSwatches.contains(hex),
                "\(hex) not in \(slot) swatches"
            )
        }
    }

    func testRandomProfileResolvesAndRenders() throws {
        let manifest = try manifest()
        var gen = SeededGenerator(seed: 5)
        let resolved = HumationProfile.random(in: manifest, using: &gen).resolved(against: manifest)
        let image = HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: 64)
        XCTAssertNotNil(image)
    }

    func testFacadeRandomProfile() {
        XCTAssertNotNil(Humation.randomProfile())
        var gen = SeededGenerator(seed: 11)
        XCTAssertNotNil(Humation.randomProfile(using: &gen))
    }

    // MARK: slot metadata

    func testDefaultSwatchesAreNormalizedHex() {
        for slot in HumationColorSlot.allCases {
            let swatches = slot.defaultSwatches
            XCTAssertFalse(swatches.isEmpty, "\(slot) has no swatches")
            for hex in swatches {
                XCTAssertEqual(hex, HumationEngine.normalizeHex(hex), "\(hex) not normalized")
                XCTAssertEqual(hex.count, 6, "\(hex) is not 6-char hex")
            }
        }
    }

    func testDisplayNamesArePresent() {
        for slot in HumationSelectionSlot.allCases {
            XCTAssertFalse(slot.displayName.isEmpty)
        }
        for slot in HumationColorSlot.allCases {
            XCTAssertFalse(slot.displayName.isEmpty)
        }
    }
}
