# FramedLocal Project Status

This is the living status record for the private/local FramedLocal iOS app.

## Current State

- Date: 2026-10-28
- Phase: 7 — simulator/generic-device builds and unit checks pass; physical-device verification remains
- Branch: `main`, tracking `origin/main` (private GitHub `MithunDB/FramedLocal`)
- Xcode version: 27.1 (Build 27A9275)
- Swift version: 6.4 (swift-driver 1.168.6)
- iOS SDK: 27.1; installed simulator runtimes: iOS 26.2, 27.0, 27.1
- iOS deployment target: 17.0
- macOS: 27.0.1 (Build 26A434)
- Development Mac/device details: user target is base M5 MacBook Pro, 16 GB; host hardware not independently verified
- Signing identity: one valid Apple Development identity is installed; team selection/provisioning not configured
- Physical iPhone connected: no (no physical device listed; iPhone 12 not available)
- Last known-good builds: `build/DerivedData/Build/Products/Debug-iphonesimulator/FramedLocal.app` (iOS 27.1 simulator, unsigned); `build/DeviceDerivedData/Build/Products/Debug-iphoneos/FramedLocal.app` (generic iOS device, unsigned)
- Status: in-progress

## Current Objective

Continue the private/local FramedLocal implementation through physical iPhone validation of camera capture, orientation, guidance, editing, and Photos export. Keep this file current so work can resume after context or usage limits.

## Last Completed Step

- Created this workspace documentation by copying the FramedLocal init specification and status template from the supplied document directory.
- Created `FramedLocal.xcodeproj` and a native SwiftUI app (`FramedLocal/FramedLocalApp.swift`, `FramedLocal/ContentView.swift`, asset catalog).
- Implemented camera authorization states, rear/front switching, serial-queue session configuration, live preview, JPEG still capture, and a denied-permission screen in `FramedLocal/ContentView.swift`.
- Added `FramedLocal/PhotoLibraryService.swift` with add-only permission, JPEG file export, creation/reuse of the `Framed` album, and clear save errors. The camera screen now offers Save to Photos after capture. Added `NSPhotoLibraryAddUsageDescription`; no full-library read permission is requested.
- Added initial `docs/DECISIONS.md` and `docs/TEST_MATRIX.md`.
- Added `FramedLocal/FilmRenderer.swift` with five original local looks: Natural, Warm Print, Soft Mono, Faded Color, and Night Grain. Rendering runs in an actor with a reusable `CIContext`.
- Added `FramedLocal/FrameRenderer.swift` with Full Bleed, White Border, and Paper Print layouts plus optional date stamping. Rendering is performed off the main actor and capped to a 2,400-pixel long edge for predictable memory use.
- Capture UI supports preset/frame/date choices, preview, retake, and saving the rendered JPEG as a new Photos asset.
- Added `FramedLocal/PhotoImportService.swift` using `PhotosPicker` and `Transferable` file import. The picker grants access only to the selected item; imported source bytes remain separate from the rendered output.
- Updated camera/editor flow to allow choosing an existing image, applying the same local presets and frames, previewing the result, and exporting a new asset without changing the selected original.
- Added `FramedLocal/CompositionAnalysis.swift`: throttled Vision face/saliency detection, brightness and clipping sampling, Laplacian sharpness estimate, subject edge spacing, selected-object tracking, and a single debounced guidance message.
- Added a low-resolution `AVCaptureVideoDataOutput` path that drops late frames, analyzes on a dedicated serial queue, and shows guidance as a minimal overlay. Tapping the live preview selects a face/object for tracking.
- Added device-motion orientation updates, explicit AVFoundation rotation-angle updates, Vision orientation mapping, horizon-level guidance, and optional warning haptics in `FramedLocal/ContentView.swift` and `FramedLocal/CompositionAnalysis.swift`.
- Added latest-render-wins cancellation and stale-result protection to the preset/frame preview pipeline; capture export now waits for the final render.
- Extracted the stable guidance state into `GuidanceEngine` and added tests for guidance debounce/confidence and JPEG preset/frame output in `FramedLocalTests/`.
- Added a shared Xcode scheme and a `FramedLocalTests` hosted unit-test target in `FramedLocal.xcodeproj`.
- Reworked Photos export in `FramedLocal/PhotoLibraryService.swift` to create the `Framed` album and first asset in one PhotoKit transaction, reuse the saved local album identifier if add-only access can resolve it, and fall back to Photos Recents with accurate UI messaging when album access is unavailable. No full-library permission was added.
- Hardened camera capture lifetime by retaining each in-flight `AVCapturePhotoCaptureDelegate` until its callback completes; startup failures no longer masquerade as permission denial and now offer Retry.
- Made subject selection run on the Vision analysis queue, managed the device-orientation observer lifecycle, and applied device rotation changes to the preview connection. Hold-steady haptics now trigger only when entering that guidance state.
- Kept preset/frame/date controls available for existing-photo edits, guarded save while rendering, and added stale-import cancellation protection plus permission/session refresh when the app returns to the foreground.
- Updated `docs/TEST_MATRIX.md` with the generic-device build, 4 passing simulator unit tests, and pending physical Photos album cases.
- Audited `/Users/mithundb/Desktop/Code/Framed`: it was empty, had no `.git`, Xcode project, workspace, or Swift package.
- Environment queried: Xcode 27.1, Swift 6.4, macOS 27.0.1, iOS SDK 27.1, simulators iOS 26.2/27.0/27.1, one valid Apple Development signing identity.
- Initial `xcodebuild -list` failed because no project existed. After creating the untouched SwiftUI template, `xcodebuild -project FramedLocal.xcodeproj -scheme FramedLocal -destination 'platform=iOS Simulator,id=36813EBB-CF84-450F-8365-7A46ACEEB733' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded. Product: `build/DerivedData/Build/Products/Debug-iphonesimulator/FramedLocal.app`.
- `xcrun devicectl list devices` showed simulator devices only; no physical iPhone is connected.
- Phase 1 build succeeded for the iOS 27.1 iPhone Duo simulator destination with signing disabled. Swift 6 actor-isolation warnings were eliminated by isolating UI state to MainActor and assigning AVFoundation session ownership to the serial queue.
- Phase 2 PhotoKit implementation builds successfully on the same simulator destination. Installed and launched the updated app (`local.mithundb.framed: 74993`); verified `NSPhotoLibraryAddUsageDescription` in the built Info.plist.
- Phase 3 build passed for the iOS 27.1 iPhone Duo simulator. Updated app installed and launched (`local.mithundb.framed: 75611`); captured a simulator screenshot at `/tmp/framedlocal-phase3.png`.
- Phase 4 Photos picker/import integration built successfully. Updated app installed and launched (`local.mithundb.framed: 76170`).
- Phase 6 Vision/composition implementation built successfully for iOS 27.1 simulator. Updated app installed and launched (`local.mithundb.framed: 77438`). The simulator cannot validate live camera Vision results.
- The first iOS 27.1 simulator boot printed `Data Migration Failed`, but the simulator subsequently reached Booted; app installation and launch then succeeded (`local.mithundb.framed: 74139`).

## Current Problem

No physical iPhone is connected. Camera hardware, physical orientation behavior, and PhotoKit writes cannot be verified on the simulator. The local folder is connected to the private GitHub repository and tracks `main`. Simulator app build, generic-device build, and hosted tests pass.

## Next Smallest Step

Connect iPhone 12, select the installed Apple Development identity/team in Xcode, then install and run. Verify front/rear capture orientation and add-only Photos export/album behavior first; no physical iPhone currently appears in `xcrun devicectl list devices`.

## Verification

| Check | Result | Notes |
|---|---|---|
| Workspace audit | Complete | Empty workspace before docs were added; no Git metadata or Xcode project |
| Untouched project build | Passed after project creation | Standard minimal SwiftUI app template builds cleanly; no camera features added yet |
| Simulator build | Passed | Unsigned Debug build for iOS 27.1 iPhone Duo simulator destination after camera implementation |
| Latest simulator build | Passed | iOS 27.1 simulator; includes orientation, render cancellation, and add-only Photos export changes |
| Generic iOS device build | Passed | Unsigned `generic/platform=iOS` build; signing/install on iPhone remains pending |
| Hosted unit tests | Passed | iOS 27.1 iPhone Duo simulator; 4 tests, 0 failures |
| Latest hosted test run | Passed | 4 tests, 0 failures after Photos export refactor; no Swift concurrency warnings |
| Simulator install/launch | Passed | Installed and launched `local.mithundb.framed` on iPhone Duo simulator |
| Physical-device build/run | Not run | No iPhone 12 connected |
| Camera permission flow | Implemented; runtime check pending | Camera request, denied screen, and Settings link are present |
| Capture orientation | Partial; device verification pending | JPEG capture implemented; explicit orientation metadata behavior not yet verified |
| Vision performance | Implemented; device measurement pending | Low-resolution capture stream, ~7 Hz throttle, stale frames dropped, worker queue |
| Film preset rendering | Implemented; visual/device check pending | Five original presets rendered with Core Image off main actor; used for camera and imported images |
| Frame rendering | Implemented; visual/device check pending | Three deterministic layouts with optional date stamp |
| Photos export | Implemented; runtime check pending | Add-only authorization, new JPEG asset, and Framed album create/reuse |
| Photos picker import | Implemented; runtime check pending | System picker transfers selected images only; source remains unchanged |
| Permission denial handling | Implemented; runtime check pending | Camera and Photos denial messaging available |
| Composition guidance | Implemented; runtime tuning pending | One debounced message based on explainable metrics |
| Subject tracking | Implemented; device check pending | Tap-to-select uses face/saliency box and Vision tracking request |

## Decisions

- Native SwiftUI/Xcode app using AVFoundation, Vision, Core Image, and PhotoKit.
- Local processing only for the initial release.
- Bundle identifier: `local.mithundb.framed`; temporary display name: `Framed`.
- Preserve original captures and export new assets.
- Use add-only Photos permission for capture/export; use the system picker for imported photos.
- Composition advice is a recommendation, not objective truth.
- No cloud AI, analytics, photo uploads, or network dependency in the initial release.

## Known Issues

- Physical device run is still unavailable because no iPhone 12 is connected.
- Local Git is connected to `origin` at `https://github.com/MithunDB/FramedLocal.git`; current branch tracks `origin/main`.
- No physical iPhone is connected.

## Remaining Implementation And Verification

Implemented in this workspace, with device/runtime verification still pending:

- Camera permission flow, front/rear switching, AVCapture preview, JPEG capture, rotation handling, and denial UI.
- PhotoKit add-only export, temporary JPEG handling, and best-effort `Framed` album creation/reuse.
- Five original Core Image presets; three frame layouts and optional date stamp.
- Photos picker import and copy-only editing/export; the original photo is not modified.
- Throttled Vision face/saliency analysis, exposure/sharpness/edge metrics, stable guidance, device-motion horizon cue, warning haptics, and tap-to-track.
- Latest-render-wins cancellation and protection from saving before the current render completes.

Still needed before the requested end state is proven:

1. Run the app on a physical iPhone 12; verify rear/front preview and capture, portrait/landscape output orientation and metadata, and camera denial/recovery.
2. Verify add-only authorization, asset export, and creation/reuse/population of the dedicated `Framed` album. The first asset is now added to an album created in the same PhotoKit transaction; later saves reuse its stored local identifier if add-only access permits fetching it, otherwise the app saves to Photos Recents and reports that destination. Test both paths on device without adding full-library access.
3. Exercise all presets/frames visually on captures and imported images; verify the source remains unchanged and export creates a new asset.
4. Test live Vision detection, tap selection, tracking loss/reacquisition, confidence/debounce behavior, and horizon cue in representative scenes.
5. Complete interruption, low-storage/write-failure, permission, cancellation, memory, repeated-capture, performance, and no-network checks; record actual device results in `docs/TEST_MATRIX.md`.
6. Configure signing for iPhone, install and launch the local build, and record the signing/team outcome.
7. Keep implementation and status changes committed to the connected private GitHub repository as work continues.

## Blockers And Failed Attempts

- Initial command: `xcodebuild -list` in the workspace. Exact result: `xcodebuild: error: The directory /Users/mithundb/Desktop/Code/Framed does not contain an Xcode project, workspace or package.` Resolved by creating the SwiftUI Xcode project.
- First camera build failed because Swift requires delegate conformers to inherit `NSObject`; changed `CameraController` to subclass `NSObject`.
- Attempted to remove Swift 6 actor-isolation warnings using `nonisolated` mutable fields; that failed because Observation macros do not permit mutable nonisolated storage. Removed `@Observable`, kept UI-facing state on `MainActor`, and serialized AVFoundation access on the camera queue; the final simulator build passed without camera-code warnings.
- Simulator boot emitted `Data Migration Failed`, then later completed as Booted. Install and launch succeeded.
- First PhotoKit build failed because `PHAssetCollectionChangeRequest` has no `placeholderForCreatedAsset`; removed the invalid access and re-fetch the created album by title after the transaction.
- Frame renderer initially needed explicit Core Text and Uniform Type Identifiers imports; corrected the imports and used `CTLineCreateWithAttributedString`. Final simulator build passed.
- Composition-analysis compile fixes: removed a stray dot-space syntax error; converted Vision Float confidence to Double. Moved frame handling onto the analyzer queue and tightened the asynchronous callback to `@Sendable`; final build passed without project-source concurrency warnings.
- Swift 6 strict concurrency initially flagged captured mutable actor state in the album callback; removed the mutable capture and made album lookup nonisolated/read-only. Final build passed.

## Files To Revisit

- `FramedLocal.xcodeproj/project.pbxproj`
- `FramedLocal.xcodeproj/xcshareddata/xcschemes/FramedLocal.xcscheme`
- `FramedLocal/ContentView.swift`
- `FramedLocal/PhotoLibraryService.swift`
- `FramedLocal/CompositionAnalysis.swift`
- `FramedLocalTests/`
- `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`
- `docs/PROJECT_STATUS.md`

## Current Turn Errors And Attempts

- Initial orientation build error: `captureOrientation` was out of scope. Replaced that use with the active session rotation angle; the simulator build passed.
- The initial test target had no test action; added a shared scheme.
- First test links reported undefined symbols for `FilmPreset.allCases`, `FrameLayout.allCases`, `FilmRenderer.shared`, `FrameRenderer.shared`, and `GuidanceEngine` APIs. Root cause found: `FramedLocalTests` referenced build-configuration-list ID `A10000000000000000000023`, but the corresponding `XCConfigurationList` was missing. Added the Debug/Release configuration list and restored `TEST_HOST`/`BUNDLE_LOADER`; `xcodebuild ... test` passed.
- Before locating that project-file defect, `test-without-building` remained active without results. Confirmed xcodebuild PID 80503 was still alive after over a minute, interrupted that stale runner, then ran a fresh test after correcting the project.
- Successful test run executed 4 tests (2 guidance stability/confidence tests and 2 renderer JPEG/copy tests), 0 failures.
- Non-fatal simulator test-link warnings: `CoreAudioTypes` and `UIUtilities` auto-linked frameworks not found; direct linking of `SwiftUICore` is not allowed. AppIntents metadata extraction was skipped because the target has no AppIntents dependency. The tests still passed.
- Generic device build passed with `-destination 'generic/platform=iOS'`; only warning was skipped AppIntents metadata extraction.
- Apple documentation review confirms add-only means the app may add items; `PHAssetCollectionChangeRequest` supports album creation and adding assets inside a Photos change block. The app's existing-album enumeration under add-only still needs a physical-device check.
- Photos export refactor initially compiled and passed 4 tests but produced Swift 6 warnings: actor-isolated `saveAssetOnly(from:completion:)` called from a nonisolated Photos completion, and a non-Sendable completion closure captured by a `@Sendable` callback. Marked the helper `nonisolated` and its callback `@Sendable`; rerun passed with neither warning.
- Latest `xcodebuild ... test` passed 4/4; the only remaining build warning is Xcode's AppIntents metadata extraction being skipped because the app has no AppIntents dependency.
- Initially, the workspace had no checkout. Confirmed account `MithunDB` access with `gh auth status` and `git ls-remote`; the GitHub connector committed the app to `main`, then the workspace initialized Git and checked out that exact commit. `git status` is clean and `build/` is ignored.
- Private repository commit `fc4c7337f20251c651d7f2b85dcd31d83dde59da` (`Build local Framed iOS camera app`) is at `origin/main` and contains app code, tests, `.gitignore`, and status/docs.
- No physical iPhone was connected. `xcrun devicectl list devices` lists simulators only.

## Latest Turn Update — 2026-10-28

- Changed `FramedLocal/ContentView.swift` to retain per-capture delegates, separate camera startup errors from access denial, serialize subject selection, clean up orientation observation, rotate preview connections with device orientation, reduce repeated haptics, preserve editor controls after capture/import, prevent saving stale renders, cancel stale photo imports, and recheck permissions when returning to the foreground.
- Generic iOS device build rerun after these changes: `xcodebuild -project FramedLocal.xcodeproj -scheme FramedLocal -destination 'generic/platform=iOS' -derivedDataPath build/DeviceDerivedData CODE_SIGNING_ALLOWED=NO build` — **BUILD SUCCEEDED**. Warning: Xcode skipped AppIntents metadata extraction because there is no AppIntents dependency.
- Latest simulator unit run remains 4 passed, 0 failed (guidance and renderer tests); those tests do not cover camera hardware or PhotoKit device behavior.
- `git diff --check` passed. `xcrun devicectl list devices` still shows simulators only.
- No physical-device test or signing setup was possible this turn. User has cable-connection guidance; when connected, confirm Finder trust/authorization and Xcode Device Hub visibility, then select a development team and run on iPhone 12.
- Remaining implementation/verification: physical front/rear camera capture and orientation; permission denial/recovery; PhotoKit add-only save and dedicated album behavior; visual preset/frame/date review; Vision detection/tracking and guidance; cancellation/interruption, storage failure, memory/performance, repeated capture, and offline behavior. Existing imported originals must remain unchanged and final renders must export as new assets.
- Exact next smallest step: connect and trust the iPhone 12 so it appears in `xcrun devicectl list devices`; then install/run and validate both camera positions. If it remains absent, troubleshoot cable data capability, direct Mac port, unlock/trust prompts, Finder Locations, and Xcode Device Hub before more device-only work.

## Follow-up Turn — 2026-10-28

- Current-state audit: worktree started clean at `b679eb8`; `docs/TEST_MATRIX.md` still listed launch/camera/Photos runtime checks as pending and only 4 unit tests existed.
- Changed `FramedLocal/ContentView.swift`: camera switch and capture are now disabled until the capture session is running. The controller reports readiness on the main actor and resets it on stop/start failure; both actions also guard against a non-running session.
- Changed `docs/TEST_MATRIX.md` with a startup/readiness case. Physical-device behavior still needs confirmation.
- Simulator test command (`xcodebuild ... test`, iOS 27.1 iPhone Duo) passed 4 tests, 0 failures. Core Image emitted simulator-only `CVPixelBufferCreate returned err -6680` log messages during renderer tests; the renderer tests passed. Xcode also emitted non-fatal `IDESchemeActionDeviceRecord ... invalidDigitCount` diagnostics for simulator OS build metadata.
- Generic iOS device build passed; only warning was skipped AppIntents metadata extraction (no AppIntents dependency).
- `docs/PROJECT_STATUS.md` and this log need commit/push after diff review. No physical phone appears in `devicectl`; signing, camera hardware, and Photos library behavior remain unverified.
- Exact next smallest step: inspect final diff and `git diff --check`, commit/push the readiness fix, then connect and trust the iPhone 12 for camera and export verification.

## Follow-up Turn — 2026-10-28 (Vision frame scheduling)

- Current-state audit confirmed the analysis output explicitly requests full-range bi-planar YCbCr, so sampling plane 0 as luma is correct for the configured format. (An initial suspicion that this plane assumption was wrong was disproved by the explicit videoSettings; no sampler code was changed.)
- Found actual latency issue: analyzer entry called `queue.sync` and ran Vision + pixel sampling from the AVCapture sample-buffer delegate queue. Moved delegate delivery to the dedicated serial `analysisQueue`; the analyzer executes inline on that queue. A lock-protected one-frame pending gate drops incoming frames while analysis is busy, bounding queued work. The `CVPixelBuffer` remains owned/used within the delegate callback queue; no non-Sendable frame crosses queues.
- Also prevented duplicate session-start configuration with a main-actor `isConfiguring` state, reset on stop and start failure.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Generic device build passed. Simulator hosted tests passed (4/4, 0 failures). Only AppIntents metadata extraction warning; earlier Core Image simulator pixel-buffer diagnostic may recur in renderer tests. `git diff --check` passed.
- The analysis pending gate and session startup guard have build/test verification but no hardware runtime verification; Vision throughput and capture responsiveness remain to be measured on the iPhone 12.
- Exact next smallest step: review and commit/push the queueing and session-start changes, then test live Vision responsiveness on a connected iPhone 12.

## Follow-up Turn — 2026-10-28 (render orientation tests)

- Inspected the frame renderer and expanded `FramedLocalTests/RendererTests.swift` with portrait/landscape dimension preservation, date-stamp canvas sizing, and upright rendered-JPEG orientation metadata checks. These tests apply to renderer output only; they do not validate AVFoundation camera-file metadata.
- A first attempt to add tests targeted the nonexistent `FramedLocal/FramedLocalTests/` directory; `apply_patch` reported file not found and made no change. Retargeted to the actual root `FramedLocalTests/` directory.
- Seven simulator tests now pass, 0 failures (2 guidance, 5 renderer). Renderer tests establish source bytes remain unchanged while output is a new JPEG; they still do not validate Photos writes or actual camera frames.
- Changed files: `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Xcode warning: skipped AppIntents metadata extraction because the project has no AppIntents dependency. No test failures.
- Exact next smallest step: run a generic-device build and `git diff --check`, review the test additions, then commit/push. Continue device checks once iPhone 12 is connected and trusted.

## Follow-up Turn — 2026-10-28 (camera orientation and mirroring)

- Current audit confirmed a four-camera rotation mapping already exists, but mirroring was implicit and camera discovery selected a rear-capable fallback type for front discovery.
- Changed `FramedLocal/ContentView.swift`: front discovery now prefers TrueDepth and falls back to front wide-angle; rear discovery uses rear wide-angle. Front preview and analysis connections explicitly mirror, rear connections do not, and photo output mirroring follows selected position at capture time. Rotation angle remains explicitly updated across preview, analysis, and photo connections.
- Changed `docs/TEST_MATRIX.md` to reflect configured (not yet device-verified) front mirroring/orientation.
- Generic iOS device build succeeded; simulator unit suite passed 7/7. Only non-fatal AppIntents metadata extraction warning.
- One combined patch attempt failed to match source context and made no change; split into exact hunks and applied successfully. `git diff --check` remains to run before commit.
- Runtime front/rear orientation and selfie mirroring remain unverified until physical iPhone 12 is visible; simulator has no camera hardware.
- Exact next smallest step: run final diff check/review, update status with commit result, then validate front-camera mirroring and portrait/landscape stills on the iPhone.

## Follow-up Turn — 2026-10-28 (camera configuration rollback)

- Code review found `configureSession` only removed outputs when a prior full setup set `isConfigured`. A failure after adding one output on initial setup could leave partial state and make Retry fail on duplicate output.
- Changed `FramedLocal/ContentView.swift`: session reconfiguration now removes existing outputs based on actual session membership. If any setup step throws, it removes the newly attached active input and either output that was added, clears `isConfigured`, then rethrows the original error so the UI can offer retry.
- Added `Camera recovery` row to `docs/TEST_MATRIX.md`. Simulator cannot induce a camera configuration failure; failure rollback remains unverified at runtime.
- Generic iOS build succeeded. Simulator hosted tests passed 7/7. `git diff --check` passed before docs changes; rerun before commit. Non-fatal warning: AppIntents metadata extraction skipped due no AppIntents dependency.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: inspect final diff, run `git diff --check`, then commit/push. Next physical-device checks include configuration retry, front-camera mirroring, and camera orientation.

## Follow-up Turn — 2026-10-28 (camera state observation and preview mirroring)

- Audit found `CameraController` was stored in SwiftUI `@State` but did not conform to `ObservableObject` or `@Observable`; mutations from capture/permission callbacks therefore had no reliable view invalidation contract. Also, setting mirroring on session output connections did not explicitly configure the `AVCaptureVideoPreviewLayer` connection.
- Changed `FramedLocal/ContentView.swift`: controller now conforms to `ObservableObject`, user-visible state is `@Published` and main-actor isolated, and the view owns it via `@StateObject`. Front/rear selection is published and passed to `CameraPreview`, which explicitly applies supported rotation and mirroring to the preview-layer connection on create/update.
- The same audit found queue closures reading main-actor camera state. Facing and orientation are now snapshotted before session-queue work and supplied to configuration/capture calls; failed camera switch restores the selected-facing state and exposes stopped state for retry.
- One initial generic build after actor-isolating orientation state failed with exact error `main actor-isolated property 'deviceOrientation' can not be referenced from a nonisolated context` at the `visionOrientation` computed property. Marked that getter `@MainActor`; generic build then succeeded.
- Generic iOS device build succeeded. Simulator suite passed 7/7. `git diff --check` passed before doc updates; rerun before commit. Only non-fatal warning: AppIntents metadata extraction skipped because the app has no AppIntents dependency.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- No camera is available in the simulator. Published updates compile and tests pass, but preview mirroring, permission prompts, session restart, and capture remain physical-device checks.
- Exact next smallest step: inspect diff and run final whitespace check, then commit/push; next device check is front/rear switch after foreground/background and verify the displayed preview and still agree.

## Follow-up Turn — 2026-10-28 (bound film-render input size)

- Audited image pipeline and found `FilmRenderer` emitted JPEG at the original full resolution, after which `FrameRenderer` decoded it and reduced output to 2,400 px. This incurred an avoidable full-resolution encode/decode and memory cost.
- Added `FrameRenderer.maximumPixelDimension` and made `FilmRenderer` scale the orientation-correct Core Image extent down to that bound before preset processing/encoding. The frame stage uses the same shared limit.
- Added `testFilmRendererCapsLargeSourceBeforeFrameStage` using a 2,800 x 1,200 fixture. It confirms film output is 2,400 px wide and the long edge never exceeds the shared limit.
- Simulator tests now pass 8/8 (2 guidance, 6 renderer), including the new size bound. Generic-device build and `git diff --check` remain to run before commit. No failures so far.
- Changed files: `FramedLocal/FilmRenderer.swift`, `FramedLocal/FrameRenderer.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- This bounds intermediate/output dimensions; peak memory and latency on an actual iPhone still need measurement.
- Exact next smallest step: run generic iOS build, `git diff --check`, inspect current diff, then commit/push. Continue physical device tests when iPhone 12 connects.

## Follow-up Turn — 2026-10-28 (imported EXIF orientation)

- Audited imported image orientation handling: Core Image applies orientation metadata before scaling, but no test covered a source whose pixels and EXIF orientation differ.
- Added `testFilmRendererAppliesImportedEXIFOrientationToPixels`, generating JPEG with landscape pixels and EXIF orientation 6, then verifying output pixels are portrait and the output has no rotation tag. This proves the film render normalizes that fixture; it does not exercise PhotosPicker transfer/runtime or all HEIC variants.
- First test build failed with exact error `cannot find 'UTType' in scope` in the test helper; imported `UniformTypeIdentifiers`, then reran successfully.
- Simulator suite now passes 9/9 (2 guidance, 7 renderer). Generic iOS device build succeeded. `git diff --check` passed. `devicectl` still lists only simulators; physical iPhone 12, signing/install, camera, and PhotoKit behavior remain pending.
- Changed files: `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: review diff and commit/push. For device test, connect/trust iPhone 12, then import a rotated portrait and landscape asset, export a copy, and compare the original remains unchanged.

## Follow-up Turn — 2026-10-28 (full editor pipeline coverage)

- Added `testEveryPresetAndFrameCombinationPreservesImportedPortrait` to exercise all 5 presets × all 3 frame layouts on an EXIF-rotated source. It checks every result is JPEG and portrait-oriented and confirms the original input bytes are unchanged.
- The first patch used an incorrect nested test path and made no change; reapplied to root `FramedLocalTests/RendererTests.swift`.
- Simulator suite now passes 10/10 (2 guidance, 8 renderer/integration). This verifies deterministic render stages and does not prove PhotosPicker or PhotoKit runtime behavior.
- Changed files: `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: run generic build and `git diff --check`, then commit/push. Physical iPhone import/export and camera checks remain on the device checklist.

## Follow-up Turn — 2026-10-28 (import view lifecycle)

- Current audit found `.onDisappear` canceled the PhotosPicker transfer task but did not reset `isImporting` or its request identity. Returning to a retained view could leave selection disabled, and a late completion could still match the stale identity.
- Changed `FramedLocal/ContentView.swift`: on disappearance, invalidate the import task ID, nil the task, reset import progress, cancel/nil pending render, and stop camera. This prevents stale transfer completion from updating the view and clears a stuck loading state.
- Added import and import-cancellation cases to `docs/TEST_MATRIX.md`; lifecycle behavior compiles but needs UI/device runtime confirmation.
- Generic iOS build succeeded. Simulator test suite passed 10/10. `git diff --check` passed before doc edits; rerun before commit. Only non-fatal AppIntents metadata extraction warning.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: inspect and run final diff check, then commit/push. Physical PhotosPicker transfer and add-only export remain pending on the iPhone.

## Follow-up Turn — 2026-10-28 (tracking loss and analysis orientation)

- Guidance audit found low-confidence observations were ignored forever, leaving the previous confident instruction on screen after a selected subject was lost. `GuidanceEngine` now waits 0.35 seconds, then replaces stale guidance with “Move slowly so I can find the subject”; confident guidance candidates are cleared during loss.
- Added tests for initial low-confidence debounce and for clearing a prior “Hold steady” message after confidence loss.
- Apple AVFoundation documentation confirms `AVCaptureVideoDataOutput` physically rotates each delivered frame when its connection has a nonzero `videoRotationAngle`. The code also supplied a device orientation to Vision, risking a second rotation. Changed analysis connection to 0° and kept its pixels in sensor orientation; Vision receives the existing orientation mapping. Still-photo and preview orientation remain explicit.
- Simulator suite passed 11/11; generic iOS device build succeeded. Only non-fatal AppIntents metadata extraction warning. Device Vision/tracking loss, tap mapping, and actual image orientation remain unverified on camera hardware.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: run `git diff --check`, inspect and commit/push these changes. Then physical-device test landscape/portrait Vision boxes and selected-subject tracking-loss recovery.

## Exact Next Smallest Step

Connect iPhone 12, select the Apple Development team in Xcode, install and launch, then verify front/rear capture and portrait/landscape output followed by add-only Photos permission and album creation/reuse. No physical iPhone currently appears in `xcrun devicectl list devices`.

## Recovery Instruction

Read this file first after context compression. Then inspect `git status`, the latest diff, and only the relevant sections of `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`.
