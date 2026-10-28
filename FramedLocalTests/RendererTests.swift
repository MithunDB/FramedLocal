import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import FramedLocal

final class RendererTests: XCTestCase {
    func testEveryPresetProducesJPEGData() async throws {
        let source = try sampleJPEG()
        for preset in FilmPreset.allCases {
            let rendered = try await FilmRenderer.shared.render(source, preset: preset)
            XCTAssertTrue(rendered.starts(with: [0xFF, 0xD8]))
        }
    }

    func testNightGrainPresetProducesStableOutputForSameInput() async throws {
        let source = try sampleJPEG()
        let first = try await FilmRenderer.shared.render(source, preset: .nightGrain)
        let second = try await FilmRenderer.shared.render(source, preset: .nightGrain)
        XCTAssertEqual(first, second)

        let natural = try await FilmRenderer.shared.render(source, preset: .natural)
        XCTAssertNotEqual(first, natural)
    }

    func testCancelledRenderExitsBeforeDoingRendererWork() async throws {
        let source = try sampleJPEG()
        let gate = RendererTestGate()
        let task = Task {
            await gate.pause()
            _ = try await FilmRenderer.shared.render(source, preset: .nightGrain)
        }

        await gate.waitUntilPaused()
        task.cancel()
        await gate.release()

        do {
            _ = try await task.value
            XCTFail("A cancelled render must not produce an output")
        } catch is CancellationError {
            // The render actor observes cancellation before decoding or generating grain.
        }
    }

    func testPhotoImportPreservesSmallSourceBytes() throws {
        let source = try sampleJPEG(size: CGSize(width: 320, height: 240), scale: 1)
        XCTAssertEqual(try PhotoImportService.editingCopy(from: source), source)
    }

    func testPhotoImportDownsamplesAndBakesOrientationForLargeSource() throws {
        let largeLandscape = try sampleJPEG(size: CGSize(width: 3_200, height: 1_800), scale: 1)
        let rotatedSource = try jpegWithEXIFOrientation(largeLandscape, orientation: 6)
        let original = rotatedSource

        let workingCopy = try PhotoImportService.editingCopy(from: rotatedSource)
        let size = try imageSize(workingCopy)
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(workingCopy as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any])

        XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(FrameRenderer.maximumPixelDimension))
        XCTAssertGreaterThan(size.height, size.width)
        XCTAssertNil(properties[kCGImagePropertyOrientation])
        XCTAssertTrue(workingCopy.starts(with: [0xFF, 0xD8]))
        XCTAssertEqual(rotatedSource, original)
    }

    func testFileBackedPhotoImportDownsamplesWithoutLoadingOriginalData() throws {
        let source = try sampleJPEG(size: CGSize(width: 3_200, height: 1_800), scale: 1)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("FramedLocal-test-\(UUID().uuidString).jpg")
        defer { try? FileManager.default.removeItem(at: url) }
        try source.write(to: url)

        let workingCopy = try PhotoImportService.editingCopy(from: url)
        let size = try imageSize(workingCopy)

        XCTAssertLessThanOrEqual(max(size.width, size.height), CGFloat(FrameRenderer.maximumPixelDimension))
        XCTAssertLessThan(workingCopy.count, source.count)
        XCTAssertEqual(try Data(contentsOf: url), source)
    }

    func testPreviewImageDecoderCreatesCGImageFromRenderedJPEG() async throws {
        let source = try sampleJPEG(size: CGSize(width: 240, height: 160))
        let decoded = try await PreviewImageDecoder.shared.decode(source)
        let expected = try imageSize(source)
        XCTAssertEqual(decoded.width, Int(expected.width))
        XCTAssertEqual(decoded.height, Int(expected.height))
    }

    func testPreviewImageDecoderBoundsLargeDisplayImage() async throws {
        let source = try sampleJPEG(size: CGSize(width: 3_200, height: 1_800), scale: 1)
        let decoded = try await PreviewImageDecoder.shared.decode(source)

        XCTAssertLessThanOrEqual(max(decoded.width, decoded.height),
                                 PreviewImageDecoder.maximumPreviewPixelDimension)
        XCTAssertGreaterThan(decoded.width, decoded.height)
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

    func testFrameDateStampIsDeterministicForTheSelectedEditorDate() async throws {
        let source = try sampleJPEG(size: CGSize(width: 320, height: 240))
        let firstDate = Date(timeIntervalSince1970: 1_735_776_000)
        let nextDate = firstDate.addingTimeInterval(86_400)

        let first = try await FrameRenderer.shared.render(source, layout: .paperPrint,
                                                          dateStamp: true, stampDate: firstDate)
        let repeated = try await FrameRenderer.shared.render(source, layout: .paperPrint,
                                                             dateStamp: true, stampDate: firstDate)
        let nextDay = try await FrameRenderer.shared.render(source, layout: .paperPrint,
                                                            dateStamp: true, stampDate: nextDate)

        XCTAssertEqual(first, repeated)
        XCTAssertNotEqual(first, nextDay)
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

    func testFilmRendererAppliesImportedEXIFOrientationToPixels() async throws {
        let landscapePixels = try sampleJPEG(size: CGSize(width: 320, height: 180))
        let rotatedSource = try jpegWithEXIFOrientation(landscapePixels, orientation: 6)
        let output = try await FilmRenderer.shared.render(rotatedSource, preset: .natural)
        let size = try imageSize(output)

        XCTAssertGreaterThan(size.height, size.width)
        let imageSource = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any])
        XCTAssertNil(properties[kCGImagePropertyOrientation])
    }

    func testCropAspectOptionsProduceExpectedCenteredCropDimensions() async throws {
        let source = try sampleJPEG(size: CGSize(width: 320, height: 240))
        let original = source
        let sourceSize = try imageSize(source)
        let shortEdge = min(sourceSize.width, sourceSize.height)
        let expected: [CropAspect: CGSize] = [
            .original: sourceSize,
            .square: CGSize(width: shortEdge, height: shortEdge),
            .fourByThree: sourceSize,
            .sixteenByNine: CGSize(width: sourceSize.width, height: sourceSize.width * 9 / 16)
        ]

        for aspect in CropAspect.allCases {
            let output = try await FilmRenderer.shared.render(source, preset: .natural, cropAspect: aspect)
            XCTAssertEqual(try imageSize(output), expected[aspect], aspect.rawValue)
        }
        XCTAssertEqual(source, original)
    }

    func testCropPositionChangesVisibleAreaWithoutChangingOutputSizeOrSource() async throws {
        let source = try sampleJPEG(size: CGSize(width: 320, height: 240))
        let original = source
        let left = try await FilmRenderer.shared.render(
            source, preset: .natural, cropAspect: .square,
            cropPosition: CropPosition(horizontal: -1))
        let right = try await FilmRenderer.shared.render(
            source, preset: .natural, cropAspect: .square,
            cropPosition: CropPosition(horizontal: 1))

        XCTAssertEqual(try imageSize(left), try imageSize(right))
        XCTAssertNotEqual(left, right)
        XCTAssertEqual(source, original)
    }

    func testCropGeometryClampsPositionAndUsesAvailableAxis() {
        let landscape = CGRect(x: 0, y: 0, width: 960, height: 720)
        XCTAssertEqual(CropAspect.square.movementAxis(for: 4.0 / 3.0), .horizontal)
        XCTAssertEqual(CropAspect.sixteenByNine.movementAxis(for: 4.0 / 3.0), .vertical)
        XCTAssertNil(CropAspect.fourByThree.movementAxis(for: 4.0 / 3.0))

        let left = CropGeometry.cropRect(in: landscape, aspect: 1,
                                         position: CropPosition(horizontal: -4))
        let right = CropGeometry.cropRect(in: landscape, aspect: 1,
                                          position: CropPosition(horizontal: 4))
        XCTAssertEqual(left.minX, 0, accuracy: 0.000_001)
        XCTAssertEqual(right.maxX, landscape.maxX, accuracy: 0.000_001)
        XCTAssertEqual(left.width, right.width, accuracy: 0.000_001)

        let top = CropGeometry.cropRect(in: landscape, aspect: 16.0 / 9.0,
                                        position: CropPosition(vertical: -1))
        let bottom = CropGeometry.cropRect(in: landscape, aspect: 16.0 / 9.0,
                                           position: CropPosition(vertical: 1))
        XCTAssertEqual(top.minY, 0, accuracy: 0.000_001)
        XCTAssertEqual(bottom.maxY, landscape.maxY, accuracy: 0.000_001)
    }

    func testCropMovementAxisUsesImportedEXIFOrientation() throws {
        let landscapePixels = try sampleJPEG(size: CGSize(width: 320, height: 180))
        let rotatedSource = try jpegWithEXIFOrientation(landscapePixels, orientation: 6)
        let landscapeAspect = try XCTUnwrap(CropGeometry.sourceAspectRatio(from: landscapePixels))
        let portraitAspect = try XCTUnwrap(CropGeometry.sourceAspectRatio(from: rotatedSource))

        XCTAssertEqual(CropAspect.square.movementAxis(for: landscapeAspect), .horizontal)
        XCTAssertEqual(CropAspect.square.movementAxis(for: portraitAspect), .vertical)
    }

    func testCropSourceAspectRespectsImportedEXIFRotation() throws {
        let landscapePixels = try sampleJPEG(size: CGSize(width: 320, height: 180))
        let rotatedSource = try jpegWithEXIFOrientation(landscapePixels, orientation: 6)
        XCTAssertEqual(CropGeometry.sourceAspectRatio(from: landscapePixels) ?? 0, 16.0 / 9.0,
                       accuracy: 0.000_001)
        XCTAssertEqual(CropGeometry.sourceAspectRatio(from: rotatedSource) ?? 0, 9.0 / 16.0,
                       accuracy: 0.000_001)
    }

    func testEveryPresetAndFrameCombinationPreservesImportedPortrait() async throws {
        let landscapePixels = try sampleJPEG(size: CGSize(width: 320, height: 180))
        let source = try jpegWithEXIFOrientation(landscapePixels, orientation: 6)
        let original = source

        for preset in FilmPreset.allCases {
            let graded = try await FilmRenderer.shared.render(source, preset: preset)
            for layout in FrameLayout.allCases {
                let framed = try await FrameRenderer.shared.render(graded, layout: layout, dateStamp: true)
                XCTAssertTrue(framed.starts(with: [0xFF, 0xD8]), "\(preset.rawValue), \(layout.rawValue)")
                let size = try imageSize(framed)
                XCTAssertGreaterThan(size.height, size.width, "\(preset.rawValue), \(layout.rawValue)")
            }
        }

        XCTAssertEqual(source, original)
    }

    private func sampleJPEG(size: CGSize = CGSize(width: 320, height: 240), scale: CGFloat = 3) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
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

    private func jpegWithEXIFOrientation(_ data: Data, orientation: Int) throws -> Data {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [
            kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 0.9
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
}

private actor RendererTestGate {
    private var pauseContinuation: CheckedContinuation<Void, Never>?
    private var readyContinuation: CheckedContinuation<Void, Never>?

    func pause() async {
        await withCheckedContinuation { continuation in
            pauseContinuation = continuation
            readyContinuation?.resume()
            readyContinuation = nil
        }
    }

    func waitUntilPaused() async {
        if pauseContinuation != nil { return }
        await withCheckedContinuation { readyContinuation = $0 }
    }

    func release() {
        pauseContinuation?.resume()
        pauseContinuation = nil
    }
}
