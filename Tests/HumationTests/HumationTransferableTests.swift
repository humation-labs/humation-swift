import XCTest

@testable import Humation

#if canImport(CoreTransferable)
import CoreTransferable
#endif

final class HumationTransferableTests: XCTestCase {

    private func sampleResolved() throws -> ResolvedHumation {
        let manifest = try XCTUnwrap(HumationManifestStore.shared)
        return HumationTraits(seed: "transfer-test").resolved(against: manifest)
    }

    func testPNGDataProducesValidPNG() throws {
        let data = try XCTUnwrap(sampleResolved().pngData(pixels: 64))
        // PNG magic number: 89 50 4E 47 ("\x89PNG").
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        XCTAssertGreaterThan(data.count, 8)
    }

    func testPNGDataCircleShapeAlsoRenders() throws {
        let data = try XCTUnwrap(sampleResolved().pngData(pixels: 64, shape: .circle))
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }

    #if canImport(CoreTransferable)
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, visionOS 1.0, *)
    func testResolvedHumationIsTransferable() {
        // Compile-time proof that the conformance exists (so ShareLink(item:) works).
        func requireTransferable<T: Transferable>(_: T.Type) {}
        requireTransferable(ResolvedHumation.self)
    }
    #endif
}
