import CoreGraphics
import Foundation
import XCTest

@testable import Humation

final class HumationDefaultManifestTests: XCTestCase {

    override func tearDown() {
        // Global state: never let an override leak into other tests.
        Humation.setDefaultManifest(nil)
        super.tearDown()
    }

    // MARK: Fixtures

    private func bundled() throws -> HumationManifest {
        try XCTUnwrap(HumationManifestStore.shared, "bundled manifest should load")
    }

    /// Bundled JSON → mutate as a dictionary → decode, so the custom pack is a
    /// full, renderable manifest that differs only where `mutate` says.
    private func customManifest(
        _ mutate: (inout [String: Any]) throws -> Void
    ) throws -> HumationManifest {
        let data = try JSONEncoder().encode(try bundled())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try mutate(&json)
        return try Humation.manifest(from: JSONSerialization.data(withJSONObject: json))
    }

    /// Custom pack: template version bumped, and the head slot reduced to a
    /// single part so every seed resolves to it.
    private func singleHeadManifest(headId: String) throws -> HumationManifest {
        try customManifest { json in
            var template = try XCTUnwrap(json["template"] as? [String: Any])
            template["version"] = "override-test"
            json["template"] = template
            let parts = try XCTUnwrap(json["parts"] as? [[String: Any]])
            json["parts"] = parts.filter {
                $0["selectionSlot"] as? String != "head" || $0["id"] as? String == headId
            }
        }
    }

    /// A seed whose bundled head pick is not `headId`.
    private func seed(avoidingHead headId: String, in manifest: HumationManifest) throws -> String {
        let seeds = (0..<100).map { "default-manifest-\($0)" }
        return try XCTUnwrap(seeds.first(where: { seed in
            HumationTraits(seed: seed).resolved(against: manifest).selections[.head] != headId
        }))
    }

    private func rgba(_ image: CGImage) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &bytes,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return bytes
    }

    // MARK: setDefaultManifest

    func testDefaultIsBundledWithoutOverride() throws {
        XCTAssertEqual(
            Humation.manifest?.template.version,
            try bundled().template.version
        )
    }

    func testOverrideDrivesManifestAndConvenienceAPIs() throws {
        let bundled = try bundled()
        let headId = try XCTUnwrap(bundled.parts(in: .head).last?.id)
        let seed = try seed(avoidingHead: headId, in: bundled)
        let custom = try singleHeadManifest(headId: headId)
        let bundledImage = try XCTUnwrap(Humation.cgImage(seed: seed, pixels: 64))

        Humation.setDefaultManifest(custom)
        defer { Humation.setDefaultManifest(nil) }

        XCTAssertEqual(Humation.manifest?.template.version, "override-test")
        XCTAssertEqual(HumationManifestStore.current?.template.version, "override-test")
        // `shared` stays the bundled asset set.
        XCTAssertEqual(HumationManifestStore.shared?.template.version, bundled.template.version)

        XCTAssertEqual(Humation.resolved(seed: seed)?.selections[.head], headId)
        XCTAssertEqual(
            Humation.resolved(profile: HumationProfile(), seed: seed)?.selections[.head],
            headId
        )
        XCTAssertEqual(Humation.randomProfile()?.selections[.head], headId)

        let customImage = try XCTUnwrap(Humation.cgImage(seed: seed, pixels: 64))
        XCTAssertFalse(try rgba(customImage) == rgba(bundledImage), "override should change the render")
    }

    func testNilRestoresBundledManifest() throws {
        let bundled = try bundled()
        let headId = try XCTUnwrap(bundled.parts(in: .head).last?.id)
        let seed = try seed(avoidingHead: headId, in: bundled)
        let expected = HumationTraits(seed: seed).resolved(against: bundled)

        Humation.setDefaultManifest(try singleHeadManifest(headId: headId))
        defer { Humation.setDefaultManifest(nil) }
        XCTAssertEqual(Humation.manifest?.template.version, "override-test")

        Humation.setDefaultManifest(nil)
        XCTAssertEqual(Humation.manifest?.template.version, bundled.template.version)
        XCTAssertEqual(Humation.resolved(seed: seed), expected)
    }

    // MARK: Cache safety

    func testImageProviderKeyChangesWhenDefaultManifestChanges() throws {
        let resolved = try XCTUnwrap(Humation.resolved(seed: "key"))
        let before = HumationImageProvider.cacheKey(resolved, pixels: 64)

        Humation.setDefaultManifest(try bundled())
        defer { Humation.setDefaultManifest(nil) }

        XCTAssertNotEqual(HumationImageProvider.cacheKey(resolved, pixels: 64), before)
    }

    func testGeometryCacheDoesNotLeakAcrossManifestsWithSamePartIds() throws {
        let bundled = try bundled()
        let heads = bundled.parts(in: .head)
        let target = try XCTUnwrap(heads.first?.id)
        let donor = try XCTUnwrap(heads.last?.id)
        // Same part id, different SVG: `target` wears `donor`'s layers.
        let custom = try customManifest { json in
            var parts = try XCTUnwrap(json["parts"] as? [[String: Any]])
            let donorLayers = try XCTUnwrap(parts.first { $0["id"] as? String == donor }?["layers"])
            let index = try XCTUnwrap(parts.firstIndex { $0["id"] as? String == target })
            parts[index]["layers"] = donorLayers
            json["parts"] = parts
        }

        var traits = HumationTraits(seed: "geometry")
        traits.selections[.head] = target
        let resolved = traits.resolved(against: bundled)

        // Warm the cache with the bundled geometry first.
        let original = try XCTUnwrap(
            HumationRenderer.render(resolved: resolved, manifest: bundled, pixels: 64)
        )
        let swapped = try XCTUnwrap(
            HumationRenderer.render(resolved: resolved, manifest: custom, pixels: 64)
        )
        XCTAssertFalse(try rgba(swapped) == rgba(original), "stale geometry served for a reused part id")
    }
}
