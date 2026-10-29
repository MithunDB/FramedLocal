import XCTest
@testable import FramedLocal

final class GuidanceEngineTests: XCTestCase {
    func testCameraZoomClampHonorsTheActiveDeviceRange() {
        XCTAssertEqual(CameraControlPolicy.clampedZoom(2, maximum: 5), 2)
        XCTAssertEqual(CameraControlPolicy.clampedZoom(9, maximum: 4), 4)
        XCTAssertEqual(CameraControlPolicy.clampedZoom(0.5, maximum: 4), 1)
        XCTAssertEqual(CameraControlPolicy.clampedZoom(.infinity, maximum: 4), 1)
    }

    func testRadialZoomWheelSnapsNearSupportedCameraStops() {
        let range = 0.5...5.0
        XCTAssertEqual(CameraControlPolicy.snappedZoom(0.97, range: range), 1.0)
        XCTAssertEqual(CameraControlPolicy.snappedZoom(1.95, range: range), 2.0)
        XCTAssertEqual(CameraControlPolicy.snappedZoom(5.2, range: range), 5.0)
        XCTAssertNil(CameraControlPolicy.snappedZoom(1.14, range: range))
    }

    func testAutomaticFramingCentersAndLimitsTheTrackedSubject() {
        let subject = CGRect(x: 0.2, y: 0.35, width: 0.3, height: 0.2)
        let framing = CameraControlPolicy.framing(for: subject, isMirrored: false, enabled: true)
        XCTAssertEqual(framing.scale, 1.9, accuracy: 0.000_001)
        XCTAssertEqual(framing.center.x, 0.35, accuracy: 0.000_001)
        XCTAssertEqual(framing.center.y, 0.55, accuracy: 0.000_001)

        let mirrored = CameraControlPolicy.framing(for: subject, isMirrored: true, enabled: true)
        XCTAssertEqual(mirrored.center.x, 0.65, accuracy: 0.000_001)
        XCTAssertEqual(CameraControlPolicy.framing(for: subject, isMirrored: false, enabled: false), .identity)
    }

    func testAutomaticExposureProtectsHighlightsAndRecoversFromDeepShadows() {
        XCTAssertEqual(CameraControlPolicy.exposureBias(current: 0, brightness: 0.7,
                                                         clippedHighlights: 0.12, clippedShadows: 0,
                                                         minimum: -2, maximum: 2), -0.6)
        XCTAssertEqual(CameraControlPolicy.exposureBias(current: 0, brightness: 0.3,
                                                         clippedHighlights: 0, clippedShadows: 0.4,
                                                         minimum: -2, maximum: 2), 0.3)
        XCTAssertEqual(CameraControlPolicy.exposureBias(current: -0.6, brightness: 0.5,
                                                         clippedHighlights: 0.01, clippedShadows: 0.1,
                                                         minimum: -0.4, maximum: 1), 0)
    }

    func testCameraControlDefaultsFavorPhotoEssentialsAndNoTimer() {
        XCTAssertEqual(CaptureTimerSetting.off.rawValue, 0)
        XCTAssertEqual(CaptureTimerSetting.threeSeconds.rawValue, 3)
        XCTAssertEqual(CaptureTimerSetting.tenSeconds.rawValue, 10)
        XCTAssertEqual(CameraFlashSetting.automatic.captureMode, .auto)
        XCTAssertEqual(RearCameraLens.allCases, [.ultraWide, .wide])
    }

    func testMonotonicClockProvidesFiniteNondecreasingIntervals() {
        let first = MonotonicClock.now
        let second = MonotonicClock.now

        XCTAssertTrue(first.isFinite)
        XCTAssertGreaterThanOrEqual(first, 0)
        XCTAssertGreaterThanOrEqual(second, first)
    }

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

    func testVisionSubjectEdgeDistancesRespectBottomLeftCoordinates() {
        let nearTop = CompositionAnalyzer.edgeDistances(CGRect(x: 0.25, y: 0.78, width: 0.5, height: 0.18))
        XCTAssertEqual(nearTop.top, 0.04, accuracy: 0.000_001)
        XCTAssertEqual(nearTop.bottom, 0.78, accuracy: 0.000_001)

        let nearBottom = CompositionAnalyzer.edgeDistances(CGRect(x: 0.25, y: 0.04, width: 0.5, height: 0.18))
        XCTAssertEqual(nearBottom.top, 0.78, accuracy: 0.000_001)
        XCTAssertEqual(nearBottom.bottom, 0.04, accuracy: 0.000_001)
    }

    func testGuidanceHapticsAreOptionalAndOnlyTriggerOnEntry() {
        XCTAssertTrue(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: nil, enabled: true))
        XCTAssertTrue(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Suggested framing", enabled: true))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Hold steady", enabled: true))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Hold steady", previousMessage: "Suggested framing", enabled: false))
        XCTAssertFalse(GuidanceHaptics.shouldTrigger(message: "Move a little closer", previousMessage: "Suggested framing", enabled: true))
    }

    func testHorizonLevelingUsesTheCorrectGravityAxisInPortraitAndLandscape() {
        XCTAssertEqual(HorizonLeveling.angle(gravityX: 0, gravityY: -1, orientation: .portrait), 0)
        XCTAssertEqual(HorizonLeveling.angle(gravityX: 1, gravityY: 0, orientation: .landscapeLeft), 0)

        let portraitTilt = HorizonLeveling.angle(gravityX: 0.2, gravityY: -sqrt(0.96), orientation: .portrait)
        let landscapeTilt = HorizonLeveling.angle(gravityX: sqrt(0.96), gravityY: 0.2, orientation: .landscapeRight)
        XCTAssertEqual(portraitTilt ?? 0, atan2(0.2, sqrt(0.96)), accuracy: 0.000_001)
        XCTAssertEqual(landscapeTilt ?? 0, atan2(0.2, sqrt(0.96)), accuracy: 0.000_001)
        XCTAssertNil(HorizonLeveling.angle(gravityX: 0, gravityY: 0, orientation: .portrait))
    }

    func testHorizonHintWaitsForStableTiltAndResetsWhenLevel() {
        var state = HorizonGuidanceState(threshold: 0.12, stabilityDuration: 0.45)
        XCTAssertFalse(state.shouldShowLevelHint(angle: 0.2, at: 1.0))
        XCTAssertFalse(state.shouldShowLevelHint(angle: 0.2, at: 1.3))
        XCTAssertTrue(state.shouldShowLevelHint(angle: 0.2, at: 1.46))
        XCTAssertFalse(state.shouldShowLevelHint(angle: 0.05, at: 1.5))
        XCTAssertFalse(state.shouldShowLevelHint(angle: 0.2, at: 1.6))
    }

    func testSessionGenerationInvalidatesCallbacksAfterStopOrRestart() {
        let generation = SessionGeneration()
        let firstStart = generation.advance()
        XCTAssertTrue(generation.isCurrent(firstStart))

        _ = generation.advance() // stop invalidates an in-flight startup callback
        XCTAssertFalse(generation.isCurrent(firstStart))

        let restarted = generation.advance()
        XCTAssertTrue(generation.isCurrent(restarted))
        XCTAssertFalse(generation.isCurrent(firstStart))
    }

    func testSensorObserverGenerationIsReplacedAcrossRecovery() {
        let generation = SessionGeneration()
        let beforeRecovery = generation.advance()

        _ = generation.advance() // stopMotionUpdates invalidates queued sensor callbacks
        let afterRecovery = generation.advance()

        XCTAssertFalse(generation.isCurrent(beforeRecovery))
        XCTAssertTrue(generation.isCurrent(afterRecovery))
    }

    func testAnalysisGenerationGateDropsResultsFromPreviousCameraSource() {
        let gate = AnalysisGenerationGate()
        XCTAssertNil(gate.generationForFrame())

        let rearCameraGeneration = gate.resume()
        XCTAssertEqual(gate.generationForFrame(), rearCameraGeneration)
        XCTAssertTrue(gate.acceptsResult(for: rearCameraGeneration))

        gate.pause()
        XCTAssertNil(gate.generationForFrame())
        XCTAssertFalse(gate.acceptsResult(for: rearCameraGeneration))

        let frontCameraGeneration = gate.resume()
        XCTAssertNotEqual(frontCameraGeneration, rearCameraGeneration)
        XCTAssertTrue(gate.acceptsResult(for: frontCameraGeneration))
        XCTAssertFalse(gate.acceptsResult(for: rearCameraGeneration))
    }

    func testAnalysisGenerationGateRejectsResultQueuedToUIBeforePause() {
        let gate = AnalysisGenerationGate()
        let queuedResultGeneration = gate.resume()

        // The delegate may accept a result and enqueue its MainActor update just
        // before the session pauses. The UI-side check must reject it afterward.
        XCTAssertTrue(gate.acceptsResult(for: queuedResultGeneration))
        gate.pause()
        XCTAssertFalse(gate.acceptsResult(for: queuedResultGeneration))
    }

    func testSessionRecoveryPolicyResumesOnlyWhenCameraWasRequested() {
        XCTAssertEqual(SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: true), .resumeAutomatically)
        XCTAssertEqual(SessionRecoveryPolicy.interruptionEnded(shouldBeRunning: false), .ignore)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: true, mediaServicesWereReset: true), .resumeAutomatically)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: true, mediaServicesWereReset: false), .showRetry)
        XCTAssertEqual(SessionRecoveryPolicy.runtimeError(shouldBeRunning: false, mediaServicesWereReset: true), .ignore)
    }

    func testCameraReadinessRequiresRunningCaptureSession() {
        XCTAssertEqual(CaptureSessionStartOutcome.resolve(isRunning: true), .started)
        XCTAssertEqual(CaptureSessionStartOutcome.resolve(isRunning: false), .failed)
        XCTAssertTrue(CaptureAvailability.canCapture(sessionIsRunning: true, isCapturing: false))
        XCTAssertFalse(CaptureAvailability.canCapture(sessionIsRunning: false, isCapturing: false))
        XCTAssertFalse(CaptureAvailability.canCapture(sessionIsRunning: true, isCapturing: true))
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

    func testPhotoSaveOutcomeSeparatesAlbumRecentsFallbackAndFailure() {
        let albumTransaction = PhotoSaveTransactionSnapshot(assetCreated: true,
                                                            albumMutationAttempted: true)
        let assetOnlyTransaction = PhotoSaveTransactionSnapshot(assetCreated: true,
                                                                 albumMutationAttempted: false)
        let noAssetTransaction = PhotoSaveTransactionSnapshot(assetCreated: false,
                                                               albumMutationAttempted: false)
        let invalidAlbumWithoutAsset = PhotoSaveTransactionSnapshot(assetCreated: false,
                                                                      albumMutationAttempted: true)

        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: true,
                                                             transaction: albumTransaction), .savedInAlbum)
        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: true,
                                                             transaction: assetOnlyTransaction), .savedToRecents)
        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: false,
                                                             transaction: albumTransaction), .retryAssetOnly)
        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: false,
                                                             transaction: assetOnlyTransaction), .failed)
        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: true,
                                                             transaction: noAssetTransaction), .failed)
        XCTAssertEqual(PhotoSaveTransactionOutcome.resolve(photoLibrarySucceeded: false,
                                                             transaction: invalidAlbumWithoutAsset), .failed)
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

    func testLivePreviewFrameRatePolicyTargetsSixtyWhenFormatAllowsIt() {
        XCTAssertEqual(LivePreviewFrameRatePolicy.targetFramesPerSecond, 60)
        XCTAssertTrue(LivePreviewFrameRatePolicy.supportsTargetFrameRate([24...60]))
        XCTAssertFalse(LivePreviewFrameRatePolicy.supportsTargetFrameRate([24...30, 30...59.94]))
        XCTAssertEqual(LivePreviewFrameRatePolicy.fallbackFrameRateRange(for: [24...60]), 30...60)
        XCTAssertEqual(LivePreviewFrameRatePolicy.fallbackFrameRateRange(for: [60...60]), 60...60)
        XCTAssertNil(LivePreviewFrameRatePolicy.fallbackFrameRateRange(for: [24...30, 30...59.94]))
    }

    func testSubjectRectSmootherEasesBetweenTrackingObservations() throws {
        var smoother = SubjectRectSmoother(interpolation: 0.5, lossGracePeriod: 0.2)
        let initial = CGRect(x: 0.1, y: 0.2, width: 0.2, height: 0.3)
        let moved = CGRect(x: 0.3, y: 0.4, width: 0.4, height: 0.5)

        XCTAssertEqual(smoother.update(initial, at: 1), initial)
        let eased = try XCTUnwrap(smoother.update(moved, at: 1.1))
        XCTAssertEqual(eased.minX, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(eased.minY, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(eased.width, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(eased.height, 0.4, accuracy: 0.000_001)
    }

    func testSubjectRectSmootherHoldsBriefLossThenClearsAndReacquires() throws {
        var smoother = SubjectRectSmoother(interpolation: 0.5, lossGracePeriod: 0.2)
        let first = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)
        let reacquired = CGRect(x: 0.5, y: 0.5, width: 0.2, height: 0.2)

        XCTAssertEqual(smoother.update(first, at: 1), first)
        XCTAssertEqual(smoother.update(nil, at: 1.1), first)
        let easedReacquisition = try XCTUnwrap(smoother.update(reacquired, at: 1.2))
        XCTAssertEqual(easedReacquisition.minX, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(easedReacquisition.minY, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(smoother.update(nil, at: 1.3), easedReacquisition)
        XCTAssertNil(smoother.update(nil, at: 1.51))
        XCTAssertEqual(smoother.update(reacquired, at: 1.6), reacquired)
    }

    func testSubjectSelectionPrefersContainingBoxAndOnlyFallsBackWhenNearby() {
        let point = CGPoint(x: 0.5, y: 0.5)
        let far = CGRect(x: 0.05, y: 0.05, width: 0.1, height: 0.1)
        let containing = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        XCTAssertEqual(SubjectSelectionResolver.resolve(point: point, candidates: [far, containing]), containing)
        XCTAssertEqual(SubjectSelectionResolver.resolve(point: CGPoint(x: 0.65, y: 0.5), candidates: [far, containing]), containing)
        XCTAssertNil(SubjectSelectionResolver.resolve(point: CGPoint(x: 0.9, y: 0.9), candidates: [far, containing]))
        XCTAssertNil(SubjectSelectionResolver.resolve(point: point, candidates: []))
    }

    func testSubjectSelectionFeedbackCoversFoundAndMissingSubjects() {
        XCTAssertEqual(SubjectSelectionFeedback.message(didSelectSubject: true), "Tracking selected subject")
        XCTAssertEqual(SubjectSelectionFeedback.message(didSelectSubject: false), "No subject found — try tapping closer")
    }

    func testLiveCoachKeepsSearchGuidanceUntilThereIsAConfidentSubject() {
        let metrics = CompositionMetrics(subjectRect: nil, faceRects: [], brightness: 0.5,
                                         clippedHighlightRatio: 0, clippedShadowRatio: 0,
                                         sharpness: 0, subjectEdgeDistance: nil, confidence: 0.12)
        let advice = LiveCompositionCoach.advice(for: metrics, fallback: "Searching for a subject",
                                                 currentZoomFactor: 1, maximumZoomFactor: 3)

        XCTAssertNil(advice.subjectRect)
        XCTAssertNil(advice.targetThird)
        XCTAssertNil(advice.suggestedZoomFactor)
        XCTAssertEqual(advice.message, "Searching for a subject")
        XCTAssertFalse(advice.isAligned)
    }

    func testLiveCoachSuggestsAThirdAndZoomForSmallFace() {
        let face = CGRect(x: 0.2, y: 0.25, width: 0.08, height: 0.12)
        let metrics = CompositionMetrics(subjectRect: face, faceRects: [face], brightness: 0.5,
                                         clippedHighlightRatio: 0, clippedShadowRatio: 0,
                                         sharpness: 0.1, subjectEdgeDistance: nil, confidence: 0.82)
        let advice = LiveCompositionCoach.advice(for: metrics, fallback: "Searching",
                                                 currentZoomFactor: 1, maximumZoomFactor: 2.5)

        XCTAssertEqual(advice.subjectRect, face)
        XCTAssertEqual(advice.targetThird?.x ?? 0, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(advice.targetThird?.y ?? 0, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(advice.suggestedZoomFactor ?? 0, 2.5, accuracy: 0.000_001)
        XCTAssertEqual(advice.message, "Zoom in to bring the subject closer")
        XCTAssertFalse(advice.isAligned)
    }

    func testLiveCoachReportsAlignmentAtAThirdWithoutCallingItBest() {
        let face = CGRect(x: 0.55, y: 0.55, width: 0.24, height: 0.24)
        let metrics = CompositionMetrics(subjectRect: face, faceRects: [face], brightness: 0.5,
                                         clippedHighlightRatio: 0, clippedShadowRatio: 0,
                                         sharpness: 0.08, subjectEdgeDistance: nil, confidence: 0.82)
        let advice = LiveCompositionCoach.advice(for: metrics, fallback: "Searching",
                                                 currentZoomFactor: 1, maximumZoomFactor: 3)

        XCTAssertEqual(advice.message, "Framing is aligned")
        XCTAssertTrue(advice.isAligned)
        XCTAssertNil(advice.suggestedZoomFactor)
    }

    func testAnalysisWorkGateAvoidsQueueingOverlappingVisionWork() {
        let gate = AnalysisWorkGate(minimumInterval: 0.28)

        XCTAssertTrue(gate.begin(at: 1.0))
        XCTAssertFalse(gate.begin(at: 1.4)) // work never queues behind an in-flight Vision pass
        gate.finish()
        XCTAssertFalse(gate.begin(at: 1.27)) // minimum interval is measured from last start
        XCTAssertTrue(gate.begin(at: 1.281))
        gate.finish()
    }

    func testAnalysisWorkGateRaisesCadenceForTrackingThenLowersItForDetection() {
        let gate = AnalysisWorkGate(minimumInterval: 0.28)

        XCTAssertTrue(gate.begin(at: 1.0))
        gate.finish(nextMinimumInterval: 1.0 / 12.0)
        XCTAssertFalse(gate.begin(at: 1.05))
        XCTAssertTrue(gate.begin(at: 1.084))
        gate.finish(nextMinimumInterval: 0.28)
        XCTAssertFalse(gate.begin(at: 1.2))
        XCTAssertTrue(gate.begin(at: 1.365))
        gate.finish()
    }

    func testNaturalOriginalPreviewDoesNotEnablePerFrameRendering() {
        XCTAssertFalse(LivePreviewSettings().requiresProcessedPreview)
        XCTAssertTrue(LivePreviewSettings(preset: .softMono).requiresProcessedPreview)
        XCTAssertTrue(LivePreviewSettings(cropAspect: .square).requiresProcessedPreview)
    }

    func testVideoOutputDetachesWhenGuidanceAndProcessedPreviewAreInactive() {
        XCTAssertFalse(CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: true, guidanceEnabled: false, previewRequiresProcessing: false))
        XCTAssertTrue(CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: true, guidanceEnabled: true, previewRequiresProcessing: false))
        XCTAssertTrue(CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: true, guidanceEnabled: false, previewRequiresProcessing: true))
        XCTAssertFalse(CameraFrameDeliveryPolicy.shouldDeliverFrames(
            sessionIsRunning: false, guidanceEnabled: true, previewRequiresProcessing: true))
    }
}
