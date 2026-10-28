import XCTest
import UIKit
@testable import FramedLocal

final class RendererTests: XCTestCase {
    func testEveryPresetProducesJPEGData() async throws {
        let source = try sampleJPEG()
        for preset in FilmPreset.allCases {
            let rendered = try await FilmRenderer.shared.render(source, preset: preset)
            XCTAssertTrue(rendered.starts(with: [0xFF, 0xD8]))
        }
    }

    func testFramesProduceNewCopyWithoutChangingSource() async throws {
        let source = try sampleJPEG()
        let original = source
        for layout in FrameLayout.allCases {
            let output = try await FrameRenderer.shared.render(source, layout: layout, dateStamp: true)
            XCTAssertTrue(output.starts(with: [0xFF, 0xD8]))
            XCTAssertNotEqual(output, source)
            XCTAssertEqual(source, original)
        }
    }

    private func sampleJPEG() throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240))
        return try XCTUnwrap(renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            UIColor.orange.setFill()
            context.fill(CGRect(x: 70, y: 50, width: 100, height: 120))
        }.jpegData(compressionQuality: 0.9))
    }
}
