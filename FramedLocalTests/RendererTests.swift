import XCTest
import UIKit
import ImageIO
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

    func testFrameOutputKeepsPortraitAndLandscapeOrientation() async throws {
        let portrait = try sampleJPEG(size: CGSize(width: 180, height: 320))
        let landscape = try sampleJPEG(size: CGSize(width: 320, height: 180))

        for source in [portrait, landscape] {
            let output = try await FrameRenderer.shared.render(source, layout: .fullBleed, dateStamp: false)
            let sourceSize = try imageSize(source)
            let outputSize = try imageSize(output)
            XCTAssertEqual(sourceSize.width > sourceSize.height, outputSize.width > outputSize.height)
        }
    }

    func testDateStampAddsCanvasSpaceWithoutChangingOrientation() async throws {
        let source = try sampleJPEG(size: CGSize(width: 320, height: 240))
        let withoutDate = try await FrameRenderer.shared.render(source, layout: .fullBleed, dateStamp: false)
        let withDate = try await FrameRenderer.shared.render(source, layout: .fullBleed, dateStamp: true)
        let plainSize = try imageSize(withoutDate)
        let datedSize = try imageSize(withDate)

        XCTAssertEqual(plainSize.width, datedSize.width)
        XCTAssertGreaterThan(datedSize.height, plainSize.height)
    }

    func testRenderedJPEGHasUprightPixelDimensionsAndNoRotationTag() async throws {
        let portrait = try sampleJPEG(size: CGSize(width: 180, height: 320))
        let output = try await FrameRenderer.shared.render(portrait, layout: .fullBleed, dateStamp: false)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

        XCTAssertNil(properties[kCGImagePropertyOrientation])
        let size = try imageSize(output)
        XCTAssertGreaterThan(size.height, size.width)
    }

    func testFilmRendererCapsLargeSourceBeforeFrameStage() async throws {
        let source = try sampleJPEG(size: CGSize(width: 2_800, height: 1_200))
        let output = try await FilmRenderer.shared.render(source, preset: .natural)
        let size = try imageSize(output)

        XCTAssertEqual(size.width, CGFloat(FrameRenderer.maximumPixelDimension))
        XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(FrameRenderer.maximumPixelDimension))
    }

    private func sampleJPEG(size: CGSize = CGSize(width: 320, height: 240)) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        return try XCTUnwrap(renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.orange.setFill()
            context.fill(CGRect(x: size.width * 0.22, y: size.height * 0.2,
                                width: size.width * 0.31, height: size.height * 0.5))
        }.jpegData(compressionQuality: 0.9))
    }

    private func imageSize(_ data: Data) throws -> CGSize {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? NSNumber).doubleValue
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? NSNumber).doubleValue
        return CGSize(width: width, height: height)
    }
}
