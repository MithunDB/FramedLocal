import XCTest
@testable import FramedLocal

final class GuidanceEngineTests: XCTestCase {
    func testGuidanceWaitsForStableConditionAndCooldown() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.5, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.7, confidence: 0.8), "Hold steady")
    }

    func testLowConfidenceReplacesStaleGuidanceAfterBriefLoss() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Hold steady", time: 2.7, confidence: 0.8), "Hold steady")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.0, confidence: 0.1), "Hold steady")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.4, confidence: 0.1), "Move slowly so I can find the subject")
        XCTAssertEqual(engine.update(message: "Move closer", time: 3.7, confidence: 0.1), "Move slowly so I can find the subject")
    }

    func testInitialLowConfidenceWaitsBeforeShowingRecoveryGuidance() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.0, confidence: 0.1), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.2, confidence: 0.1), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.4, confidence: 0.1), "Move slowly so I can find the subject")
    }

    func testTapPointMapsFromCaptureCoordinatesIntoVisionOrientation() {
        let point = CGPoint(x: 0.2, y: 0.3)
        XCTAssertEqual(VisionTapPointMapper.visionPoint(fromCaptureDevicePoint: point, orientation: .up),
                       CGPoint(x: 0.2, y: 0.7))
        XCTAssertEqual(VisionTapPointMapper.visionPoint(fromCaptureDevicePoint: point, orientation: .right),
                       CGPoint(x: 0.7, y: 0.8))
        let leftOriented = VisionTapPointMapper.visionPoint(fromCaptureDevicePoint: point, orientation: .left)
        XCTAssertEqual(leftOriented.x, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(leftOriented.y, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(VisionTapPointMapper.visionPoint(fromCaptureDevicePoint: CGPoint(x: -1, y: 2), orientation: .up),
                       CGPoint(x: 0, y: 0))
    }

    func testAnalysisRateLimiterRejectsFastFramesThenRecovers() {
        var limiter = AnalysisRateLimiter(minimumInterval: 0.14)
        XCTAssertTrue(limiter.shouldAnalyze(at: 1.0))
        XCTAssertFalse(limiter.shouldAnalyze(at: 1.1))
        XCTAssertTrue(limiter.shouldAnalyze(at: 1.141))
        XCTAssertFalse(limiter.shouldAnalyze(at: 1.20))
        XCTAssertTrue(limiter.shouldAnalyze(at: 1.282))
    }
}
