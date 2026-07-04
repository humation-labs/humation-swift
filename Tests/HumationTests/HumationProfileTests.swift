import Foundation
import XCTest

@testable import Humation

final class HumationProfileTests: XCTestCase {

    func testProfileRoundTripNormalizesHex() throws {
        let profile = HumationProfile(
            selections: [
                .head: "hm1-p-000001",
                .item: "hm1-p-000041",
            ],
            colors: [
                .background: "#f6f5f4",
                .hair: "#1c1c1e",
                .skin: "ffffff",
            ]
        )

        XCTAssertEqual(profile.colors[.background], "F6F5F4")
        XCTAssertEqual(profile.colors[.hair], "1C1C1E")
        XCTAssertEqual(profile.colors[.skin], "FFFFFF")

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(HumationProfile.self, from: data)
        XCTAssertEqual(decoded, profile)

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let colors = try XCTUnwrap(json["colors"] as? [String: Any])
        XCTAssertEqual(colors["hair"] as? String, "1C1C1E")

        let emptyData = try JSONEncoder().encode(HumationProfile())
        let emptyJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: emptyData) as? [String: Any])
        XCTAssertEqual((emptyJSON["selections"] as? [String: Any])?.isEmpty, true)
        XCTAssertEqual((emptyJSON["colors"] as? [String: Any])?.isEmpty, true)
    }

    func testProfileDecodeIgnoresUnknownKeys() throws {
        let data = Data(
            """
            {
              "selections": {
                "head": "hm1-p-000001",
                "pet": "hm1-p-999999"
              },
              "colors": {
                "hair": "#abcdef",
                "background": "TRANSPARENT",
                "aura": "123456"
              }
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(HumationProfile.self, from: data)
        XCTAssertEqual(decoded.selections, [.head: "hm1-p-000001"])
        XCTAssertEqual(decoded.colors, [
            .background: "transparent",
            .hair: "ABCDEF",
        ])
    }

    func testProfileResolutionHealsMissingAndMismatchedParts() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let headPart = try XCTUnwrap(manifest.parts(in: .head).first?.id)
        let profile = HumationProfile(
            selections: [
                .head: "hm1-p-missing",
                .body: headPart,
            ]
        )

        let seeded = HumationTraits(seed: "heal-seed").resolved(against: manifest)
        let seededResolved = profile.resolved(against: manifest, seed: "heal-seed")
        XCTAssertEqual(seededResolved.selections[.head], seeded.selections[.head])
        XCTAssertEqual(seededResolved.selections[.body], seeded.selections[.body])

        let defaultResolved = profile.resolved(against: manifest)
        XCTAssertEqual(defaultResolved.selections[.head], manifest.defaults.selections["head"])
        XCTAssertEqual(defaultResolved.selections[.body], manifest.defaults.selections["body"])

        for slot in HumationSelectionSlot.allCases {
            XCTAssertNotNil(seededResolved.selections[slot], "\(slot.rawValue) was not resolved")
            XCTAssertNotNil(defaultResolved.selections[slot], "\(slot.rawValue) was not resolved")
        }
    }

    func testProfileInitFromResolvedIncludesOnlyOpaqueBackground() {
        let opaque = ResolvedHumation(
            selections: [.head: "hm1-p-000001"],
            colors: [.hair: "#abc123"],
            background: "#f6f5f4"
        )
        let opaqueProfile = HumationProfile(resolved: opaque)
        XCTAssertEqual(opaqueProfile.colors[.hair], "ABC123")
        XCTAssertEqual(opaqueProfile.colors[.background], "F6F5F4")

        let transparent = ResolvedHumation(
            selections: [.head: "hm1-p-000001"],
            colors: [.hair: "#abc123"],
            background: "TRANSPARENT"
        )
        let transparentProfile = HumationProfile(resolved: transparent)
        XCTAssertEqual(transparentProfile.colors[.hair], "ABC123")
        XCTAssertNil(transparentProfile.colors[.background])
    }

    func testFacadeProfileResolutionIsDeterministicWithPartialProfileAndSeed() throws {
        let manifest = try XCTUnwrap(Humation.manifest)
        let explicitHead = try XCTUnwrap(manifest.parts(in: .head).last?.id)
        let profile = HumationProfile(
            selections: [.head: explicitHead],
            colors: [.hair: "#123abc"]
        )

        let a = try XCTUnwrap(Humation.resolved(profile: profile, seed: "sender-seed"))
        let b = try XCTUnwrap(Humation.resolved(profile: profile, seed: "sender-seed"))

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.selections[.head], explicitHead)
        XCTAssertEqual(a.colors[.hair], "123ABC")
        for slot in HumationSelectionSlot.allCases {
            XCTAssertNotNil(a.selections[slot], "\(slot.rawValue) was not resolved")
        }
    }
}
