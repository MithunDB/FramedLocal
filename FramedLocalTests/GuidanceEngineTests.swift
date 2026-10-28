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

    func testTrackingUsesItsOwnConfidenceThresholdAndRecoveryMessage() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Suggested framing", time: 1.0, confidence: 0.8), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Suggested framing", time: 1.7, confidence: 0.8), "Suggested framing")
        XCTAssertEqual(engine.update(message: "Move a little closer", time: 2.0, confidence: 0.4, source: .tracking), "Suggested framing")
        XCTAssertEqual(engine.update(message: "Move a little closer", time: 2.4, confidence: 0.4, source: .tracking), "Move slowly to keep the subject in frame")
        XCTAssertEqual(engine.update(message: "Suggested framing", time: 2.7, confidence: 0.8, source: .tracking), "Move slowly to keep the subject in frame")
    }

    func testLowConfidenceDetectionKeepsSearchMessage() {
        var engine = GuidanceEngine()
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.0, confidence: 0.25, source: .detection), "Searching for a subject")
        XCTAssertEqual(engine.update(message: "Move slowly so I can find the subject", time: 1.4, confidence: 0.25, source: .detection), "Move slowly so I can find the subject")
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

    func testSubjectSelectionPrefersContainingBoxAndFallsBackToNearest() {
        let point = CGPoint(x: 0.5, y: 0.5)
        let far = CGRect(x: 0.05, y: 0.05, width: 0.1, height: 0.1)
        let containing = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        XCTAssertEqual(SubjectSelectionResolver.resolve(point: point, candidates: [far, containing]), containing)
        XCTAssertEqual(SubjectSelectionResolver.resolve(point: CGPoint(x: 0.8, y: 0.8), candidates: [far, containing]), containing)
        XCTAssertNil(SubjectSelectionResolver.resolve(point: point, candidates: []))
    }
}
