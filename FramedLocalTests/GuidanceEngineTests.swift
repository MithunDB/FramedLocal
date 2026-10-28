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

    func testExposureGuidanceUsesHighlightAndShadowClipping() {
        XCTAssertEqual(ExposureGuidance.message(brightness: 0.5, clippedHighlightRatio: 0.13,
                                                clippedShadowRatio: 0.1), "Lower exposure slightly")
        XCTAssertEqual(ExposureGuidance.message(brightness: 0.25, clippedHighlightRatio: 0.01,
                                                clippedShadowRatio: 0.4), "Add a little light")
        XCTAssertNil(ExposureGuidance.message(brightness: 0.5, clippedHighlightRatio: 0.01,
                                              clippedShadowRatio: 0.1))
    }

    func testGuidanceHapticsAreOptionalAndOnlyTriggerOnEntry() {
        XCTAssertTrue(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Suggested framing", enabled: true))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Hold steady", enabled: true))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Suggested framing", enabled: false))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Move a little closer", previousMessage: "Suggested framing", enabled: true))
    }

    func testSessionGenerationInvalidatesCallbacksAfterStopOrRestart() {
        var generation = SessionGeneration()
        let firstStart = generation.advance()
        XCTAssertTrue(generation.isCurrent(firstStart))

        _ = generation.advance() // stop invalidates an in-flight startup callback
        XCTAssertFalse(generation.isCurrent(firstStart))

        let restarted = generation.advance()
        XCTAssertTrue(generation.isCurrent(restarted))
        XCTAssertFalse(generation.isCurrent(firstStart))
    }

    func testSessionRecoveryPolicyResumesOnlyWhenCameraWasRequested() {
        XCTAssertEqual(SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: true), .resumeAutomatically)
        XCTAssertEqual(SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: false), .ignore)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: true, mediaServicesWereReset: true), .resumeAutomatically)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: true, mediaServicesWereReset: false), .showRetry)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: false, mediaServicesWereReset: true), .ignore)
    }

    func testPhotoCaptureResolverPrefersTerminalCaptureError() {
        let data = Data([0xFF, 0xD8])
        let processingError = NSError(domain: "PhotoProcessing", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "processing failed"])
        let captureError = NSError(domain: "PhotoCapture", code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "capture failed"])
        let resolved = PhotoCaptureResultResolver.resolve(processedResult: .success(data),
                                                          captureError: captureError,
                                                          missingDataError: processingError)
        if case .failure(let error) = resolved {
            XCTAssertEqual(error.localizedDescription, "capture failed")
        } else {
            XCTFail("A terminal capture error must fail the capture result")
        }
    }

    func testPhotoCaptureResolverReportsMissingPhotoResult() {
        let missingDataError = NSError(domain: "PhotoCapture", code: 3,
                                       userInfo: [NSLocalizedDescriptionKey: "missing data"])
        let resolved = PhotoCaptureResultResolver.resolve(processedResult: nil,
                                                          captureError: nil,
                                                          missingDataError: missingDataError)
        if case .failure(let error) = resolved {
            XCTAssertEqual(error.localizedDescription, "missing data")
        } else {
            XCTFail("A capture without processed photo data must fail")
        }
    }

    func testPhotoCaptureResolverReturnsProcessedJPEGOnSuccess() {
        let data = Data([0xFF, 0xD8, 0xFF])
        let missingDataError = NSError(domain: "PhotoCapture", code: 3)
        let resolved = PhotoCaptureResultResolver.resolve(processedResult: .success(data),
                                                          captureError: nil,
                                                          missingDataError: missingDataError)
        if case .success(let result) = resolved {
            XCTAssertEqual(result, data)
        } else {
            XCTFail("A processed photo without a terminal error should succeed")
        }
    }

    func testPhotoSaveTransactionStateDistinguishesAssetAndAlbumWrites() {
        let state = PhotoSaveTransactionState()
        XCTAssertEqual(state.snapshot(), PhotoSaveTransactionSnapshot(assetCreated: false,
                                                                       albumMutationAttempted: false))
        state.markAssetCreated()
        XCTAssertEqual(state.snapshot(), PhotoSaveTransactionSnapshot(assetCreated: true,
                                                                       albumMutationAttempted: false))
        state.markAlbumMutationAttempted()
        XCTAssertEqual(state.snapshot(), PhotoSaveTransactionSnapshot(assetCreated: true,
                                                                       albumMutationAttempted: true))
    }

    func testPhotoSaveStatusNamesTheActualDestination() {
        XCTAssertEqual(PhotoSaveDestination.statusMessage(savedInAlbum: true), "Saved to Photos · Framed album")
        XCTAssertEqual(PhotoSaveDestination.statusMessage(savedInAlbum: false), "Saved to Photos Recents")
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

    func testSubjectSelectionFeedbackCoversFoundAndMissingSubjects() {
        XCTAssertEqual(SubjectSelectionFeedback.message(didSelectSubject: true), "Tracking selected subject")
        XCTAssertEqual(SubjectSelectionFeedback.message(didSelectSubject: false), "No subject found — try tapping closer")
    }
}
