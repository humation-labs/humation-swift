import CoreGraphics
import SwiftUI
import XCTest

import Humation
@testable import HumationEditor

final class HumationEditorTests: XCTestCase {
    func testDefaultConfiguration() {
        let configuration = HumationEditorConfiguration()

        XCTAssertEqual(configuration.tabs.count, 3)
        XCTAssertEqual(configuration.tabs[0].title, "Hair")
        XCTAssertEqual(configuration.tabs[0].slots, [.head])
        XCTAssertEqual(configuration.tabs[1].title, "Wear")
        XCTAssertEqual(configuration.tabs[1].slots, [.body, .bottom])
        XCTAssertEqual(configuration.tabs[2].title, "Gear")
        XCTAssertEqual(configuration.tabs[2].slots, [.item, .glasses])
        XCTAssertNil(configuration.cellBackground)
        XCTAssertEqual(configuration.cornerRadius, 20)
        XCTAssertTrue(configuration.showsBackgroundColors)

        XCTAssertFalse(configuration.colorPalettes.isEmpty)
        for slot in HumationColorSlot.allCases {
            XCTAssertFalse(
                configuration.colorPalettes[slot, default: []].isEmpty,
                "\(slot.rawValue) palette should not be empty"
            )
        }
    }

    func testPartCropForEachSlot() throws {
        let manifest = try XCTUnwrap(Humation.manifest)

        let head = try XCTUnwrap(manifest.parts(in: .head).first)
        XCTAssertEqual(
            HumationEditorPartCrop.crop(for: head, slot: .head, in: manifest),
            manifest.avatarCrop
        )

        let body = try XCTUnwrap(manifest.parts(in: .body).first)
        XCTAssertEqual(
            HumationEditorPartCrop.crop(for: body, slot: .body, in: manifest),
            HumationManifest.ViewBox(x: -18, y: 35, width: 116, height: 116)
        )

        let bottom = try XCTUnwrap(manifest.parts(in: .bottom).first)
        XCTAssertEqual(
            HumationEditorPartCrop.crop(for: bottom, slot: .bottom, in: manifest),
            HumationManifest.ViewBox(x: -18, y: 69, width: 116, height: 116)
        )

        let item = try XCTUnwrap(
            manifest.parts(in: .item).first {
                HumationRenderer.contentBounds(of: $0, in: manifest) != nil
            }
        )
        let itemBounds = try XCTUnwrap(HumationRenderer.contentBounds(of: item, in: manifest))
        assertViewBox(
            HumationEditorPartCrop.crop(for: item, slot: .item, in: manifest),
            equalsScaledCrop: scaledCrop(bounds: itemBounds, minimumSide: 108, scale: 1.42)
        )

        let glasses = try XCTUnwrap(
            manifest.parts(in: .glasses).first {
                HumationRenderer.contentBounds(of: $0, in: manifest) != nil
            }
        )
        let glassesBounds = try XCTUnwrap(HumationRenderer.contentBounds(of: glasses, in: manifest))
        assertViewBox(
            HumationEditorPartCrop.crop(for: glasses, slot: .glasses, in: manifest),
            equalsScaledCrop: scaledCrop(bounds: glassesBounds, minimumSide: 126, scale: 1.82)
        )
    }

    @MainActor
    func testHumationEditorViewCanInitialize() {
        _ = HumationEditorView(
            profile: .constant(HumationProfile()),
            seed: "editor-test",
            configuration: .init()
        )
    }

    private func assertViewBox(
        _ actual: HumationManifest.ViewBox?,
        equalsScaledCrop expected: HumationManifest.ViewBox,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected crop", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 0.0001, file: file, line: line)
    }

    private func scaledCrop(
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
