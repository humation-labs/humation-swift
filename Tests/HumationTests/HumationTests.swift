import CoreGraphics
import XCTest

@testable import Humation

final class HumationTests: XCTestCase {

    // MARK: FNV-1a parity (byte-identical to the reference TypeScript engine)

    func testFNV1aKnownVectors() {
        // Computed with the reference algorithm (UTF-16 code units, 32-bit wrap).
        XCTAssertEqual(HumationEngine.fnv1a(""), 2_166_136_261)
        XCTAssertEqual(HumationEngine.fnv1a("a"), 3_826_002_220)
        XCTAssertEqual(HumationEngine.fnv1a("test"), 2_949_673_445)
        XCTAssertEqual(HumationEngine.fnv1a("humation"), 2_721_276_410)
        XCTAssertEqual(HumationEngine.fnv1a("用户"), 3_303_804_768) // CJK → UTF-16 path
        XCTAssertEqual(HumationEngine.fnv1a("hm1"), 1_204_328_429)
    }

    func testNormalizeHex() {
        XCTAssertEqual(HumationEngine.normalizeHex("#aabbcc"), "AABBCC")
        XCTAssertEqual(HumationEngine.normalizeHex("aabbcc"), "AABBCC")
        XCTAssertEqual(HumationEngine.normalizeHex("transparent"), "transparent")
        XCTAssertEqual(HumationEngine.normalizeHex("TRANSPARENT"), "transparent")
    }

    // MARK: Manifest

    func testBundledManifestLoads() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared, "bundled humation-1.json missing")
        XCTAssertEqual(manifest.parts.count, 86)
        XCTAssertEqual(manifest.parts(in: .head).count, 24)
        XCTAssertEqual(manifest.parts(in: .body).count, 8)
        XCTAssertEqual(manifest.parts(in: .item).count, 43) // 32 items + 11 cats
        XCTAssertEqual(manifest.parts(in: .glasses).count, 3)
        XCTAssertNotNil(manifest.part(id: manifest.defaults.selections["head"]!))
    }

    // MARK: Determinism

    func testResolveIsDeterministic() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let a = HumationTraits(seed: "user-123").resolved(against: manifest)
        let b = HumationTraits(seed: "user-123").resolved(against: manifest)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.cacheToken, b.cacheToken)
        // Different seeds should (almost always) differ.
        let c = HumationTraits(seed: "user-456").resolved(against: manifest)
        XCTAssertNotEqual(a.selections, c.selections)
    }

    func testExplicitSelectionOverridesSeed() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let head = manifest.parts(in: .head).last!.id
        var traits = HumationTraits(seed: "x")
        traits.selections[.head] = head
        XCTAssertEqual(traits.resolved(against: manifest).selections[.head], head)
    }

    // MARK: Render smoke

    func testRenderProducesImage() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let resolved = HumationTraits(seed: "render").resolved(against: manifest)
        let image = try XCTUnwrap(
            HumationRenderer.render(resolved: resolved, manifest: manifest, pixels: 128)
        )
        XCTAssertEqual(image.width, 128)
        XCTAssertEqual(image.height, 128)
    }

    func testCircleRenderClipsCornersToTransparent() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let resolved = opaqueResolved(against: manifest)
        let image = try XCTUnwrap(
            HumationRenderer.render(
                resolved: resolved, manifest: manifest, pixels: 64, shape: .circle
            )
        )

        XCTAssertEqual(try alpha(in: image, x: 0, y: 0), 0)
        XCTAssertEqual(try alpha(in: image, x: 63, y: 0), 0)
        XCTAssertEqual(try alpha(in: image, x: 0, y: 63), 0)
        XCTAssertEqual(try alpha(in: image, x: 63, y: 63), 0)
        XCTAssertEqual(try alpha(in: image, x: 32, y: 32), 255)
    }

    func testSquareRenderKeepsCornersOpaque() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let resolved = opaqueResolved(against: manifest)
        let image = try XCTUnwrap(
            HumationRenderer.render(
                resolved: resolved, manifest: manifest, pixels: 64, shape: .square
            )
        )

        XCTAssertEqual(try alpha(in: image, x: 0, y: 0), 255)
        XCTAssertEqual(try alpha(in: image, x: 63, y: 0), 255)
        XCTAssertEqual(try alpha(in: image, x: 0, y: 63), 255)
        XCTAssertEqual(try alpha(in: image, x: 63, y: 63), 255)
    }

    func testPNGDataStartsWithPNGMagicBytes() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let resolved = opaqueResolved(against: manifest)
        let data = try XCTUnwrap(
            HumationRenderer.pngData(
                resolved: resolved, manifest: manifest, pixels: 64, shape: .circle
            )
        )

        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    func testImageProviderCacheKeyIncludesShape() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let resolved = opaqueResolved(against: manifest)

        let legacy = HumationImageProvider.cacheKey(resolved, pixels: 64)
        let square = HumationImageProvider.cacheKey(resolved, pixels: 64, shape: .square)
        let circle = HumationImageProvider.cacheKey(resolved, pixels: 64, shape: .circle)

        XCTAssertEqual(square, legacy)
        XCTAssertNotEqual(circle, square)
    }

    func testBundledManifestIsValid() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        let issues = HumationValidator.validate(manifest)
        XCTAssertTrue(issues.isEmpty, "bundled pack has issues: \(issues)")
    }

    func testFacadeProducesImage() {
        XCTAssertNotNil(Humation.cgImage(seed: "facade", pixels: 96))
        XCTAssertNotNil(Humation.resolved(seed: "facade"))
    }

    func testContentBoundsForItem() throws {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        // A real item (not the empty "none") should have non-zero content bounds.
        let item = try XCTUnwrap(manifest.parts(in: .item).first { $0.name != "none" })
        let bounds = try XCTUnwrap(HumationRenderer.contentBounds(of: item, in: manifest))
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)

        // The empty "none" item has no drawn content.
        if let none = manifest.parts(in: .item).first(where: { $0.name == "none" }) {
            XCTAssertNil(HumationRenderer.contentBounds(of: none, in: manifest))
        }
    }

    private func opaqueResolved(against manifest: HumationManifest) -> ResolvedHumation {
        HumationTraits(colors: [.background: "FF00AA"], seed: "render-shape")
            .resolved(against: manifest)
    }

    private func alpha(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let bytesPerPixel = 4
        let bytesPerRow = image.width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let ok = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let baseAddress = buffer.baseAddress,
                let ctx = CGContext(
                    data: baseAddress,
                    width: image.width,
                    height: image.height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }

            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            ctx.flush()
            return true
        }
        XCTAssertTrue(ok)

        let index = (y * bytesPerRow) + (x * bytesPerPixel) + 3
        return bytes[index]
    }
}
