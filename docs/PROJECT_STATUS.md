# FramedLocal Project Status

This is the living status record for the local-first FramedLocal iOS app.

## Current State

- Date: 2026-10-29
- Phase: 9 — camera essentials, hold-activated radial zoom wheel, digital auto-framing, Original border cleanup, and camera launch intent implemented; simulator suite passes; latest signed iPhone 12 build installed/launched; physical feature acceptance remains
- Branch: `main`, tracking `origin/main` (GitHub `MithunDB/FramedLocal`; repository made public at the user's request on 2026-10-28)
- Xcode version: 27.1 (Build 27A9275)
- Swift version: 6.4 (swift-driver 1.168.6)
- iOS SDK: 27.1; installed simulator runtimes: iOS 26.2, 27.0, 27.1
- iOS deployment target: 17.0
- macOS: 27.0.1 (Build 26A434)
- Development Mac/device details: user target is base M5 MacBook Pro, 16 GB; host hardware not independently verified
- Signing identity: Xcode automatic signing successfully provisioned and signed `local.mithundb.framed` for the user's Personal Team (`BK7H8FHGLF`)
- Physical iPhone connected: iPhone 12 `00008101-001C15880128001E`, iOS 27.0; latest signed build installed and launched, process remained running
- Last known-good builds: simulator test product at `build/DerivedData/Build/Products/Debug-iphonesimulator/FramedLocal.app`; signed device product at `build/DeviceDerivedData/Build/Products/Debug-iphoneos/FramedLocal.app` (installed/launched 2026-10-29)
- Status: in-progress

## Active Follow-up — 2026-10-29 (automatic photo improvements and composition guide cleanup)

- User observed that only exposure seemed to adjust automatically and that the center composition frame felt static/disconnected. Confirmed the camera input did not explicitly restore continuous focus/exposure/white-balance after lens changes, and `LiveRecommendedFrameGuide` was a fixed center overlay that did not describe crop bounds or a tracked subject.
- Camera inputs now explicitly enable continuous autofocus, auto-exposure, and auto-white-balance when each mode is supported. Capture requests retain `.quality` prioritization and now request supported auto red-eye reduction and content-aware distortion correction. Camera-tools sheet explains these auto camera behaviors.
- Added an on-device Core Image auto-enhancement option, on by default, for the editable/rendered copy after capture/import. It applies Apple's selected tone/contrast/face-aware corrections before the chosen film look; red-eye is left to AVFoundation's capture correction. User can toggle it in the controls sheet, and originals remain unchanged. This is a post-capture render, not a live filter, to avoid adding work to the camera preview path.
- Removed the fixed centered decorative target frame. The only composition outline is now the Vision subject brackets, which follow the tracked subject and the live crop transform; explicit crop/frame treatments remain separate.
- Verification: signed generic iOS build passed; iOS 26.2 iPhone 17 Pro simulator suite passed 69/69 (0 failed); latest build installed and launched on the connected iPhone 12; `git diff --check` passed. Xcode emits the known non-fatal simulator metadata `invalidDigitCount(94232)` diagnostic.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocal/FilmRenderer.swift`, and this status file. No new tests were added; the existing simulator suite was rerun.
- Remaining check: the auto-enhance rendering and composition-guide behavior have not been visually evaluated on the physical phone. Auto correction cannot recover clipped detail or remove reflected glare that is absent from the captured data.
- Exact next smallest step: inspect one capture with Auto improve on/off and verify the subject brackets feel correctly placed while changing zoom/crop on iPhone 12; adjust only from that observed feedback.

## Active Follow-up — 2026-10-29 (rotary zoom dial and clean GitHub project page)

- The first pass replaced the three fixed 0.5×/1×/2× zoom chips with an always-visible camera-style zoom ruler. User clarified that the dial should open only after holding one of the fixed zoom stops; see the corrected interaction in the following entry.
- Updated the interactive GitHub Pages sample and README as a clean project landing page with the site link, concise feature list, local/privacy notes, build instructions, and current-status link.
- Verification: signed generic iOS build passed; simulator suite passed 69/69; website JavaScript syntax check and `git diff --check` passed. The build was installed and FramedLocal relaunched on the connected iPhone 12.
- Changed files include `FramedLocal/ContentView.swift`, `README.md`, `site/index.html`, `site/styles.css`, `site/app.js`, and this status file, alongside the previously recorded in-progress camera and extension changes.
- Completed in the following follow-up: published the README/site refresh, set the repository description and homepage, and confirmed the Pages deployment. The user then clarified the desired zoom gesture; see below.

## Active Follow-up — 2026-10-29 (hold-to-open camera zoom wheel correction)

- User clarified that the previous always-visible linear ruler was not the desired interaction. Replaced it with discrete 0.5×, 1×, and 2× controls; a 0.38-second hold on a control opens a temporary semi-circular, tick-marked wheel above the shutter. The same held gesture can continue onto the arc; releasing leaves the wheel open for a separate drag as well. Moving around the arc adjusts magnification, including switching between ultra-wide and wide at 1×. Pinch remains available, and the wheel has VoiceOver adjustment and an explicit close control.
- Rebuilt the GitHub Pages sample to use the same quick-stop / hold-to-open wheel flow. The wheel is hidden initially; tapping a stop selects it, holding opens the radial demo, and the sample preview responds to zoom. README now documents the intended interaction.
- The prior `cdc1530` dial was already pushed at the user's direction; this follow-up corrects that public update rather than rewriting remote history.
- Verification: signed generic iOS build passed; iOS 26.2 simulator suite passed 69/69; `node --check site/app.js` and `git diff --check` passed. Corrected app installed and launched on iPhone 12. This interaction was then tuned in the follow-up below.
- Changed files: `FramedLocal/ContentView.swift`, `README.md`, `site/index.html`, `site/styles.css`, `site/app.js`, and this status file.
- Superseded by the follow-up immediately below, which adds key-stop alignment, snapping, and release dismissal.

## Active Follow-up — 2026-10-29 (zoom marker alignment, key-stop snapping, and release dismissal)

- User observed the key values did not line up with the radial tick marks, requested soft snapping to 0.5×/1×/2×/5×, and asked the wheel to close on release. Root cause: marks used evenly spaced angles while labels used logarithmic magnification positions. Tick marks now use the same logarithmic scale as the labels, with exact key-stop marks inserted into that scale.
- Added a small magnetic zone around 0.5×, 1×, 2×, and 5× plus selection haptics and unit coverage. Reduced hold delay from 0.38s to 0.24s, then to the user's requested 0.15s. The wheel now disappears as soon as the touch/drag ends; no close button is needed. Website demo follows the same snap-and-release behavior.
- Verification: signed generic iOS build passed; simulator suite passed 70/70; `node --check site/app.js` and `git diff --check` passed. Updated build installed and launched on iPhone 12. Pages deployment for commit `35f24a2` completed successfully and the published site contains the release-to-dismiss instructions. Physical feel and touch behavior still need the user's on-device confirmation.
- Changed files: `FramedLocal/CameraControls.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `README.md`, `site/app.js`, `site/index.html`, `site/styles.css`, and this status file.
- Exact next smallest step: user checks the 0.15s hold, marker alignment/key-stop snapping, continuous lens transition, and dismissal on release on the iPhone; adjust from that feedback if needed.

## Current Objective

Continue the local-first FramedLocal implementation with physical iPhone acceptance of camera capture, zoom/lens/focus/exposure/flash/timer, auto-framing, Lock Screen handoff, orientation, live look/crop/frame preview, guidance, editing, and Photos export. Latest signed app launch survived on iPhone 12; detailed camera behavior has not yet been manually exercised. Keep this file current so work can resume after context or usage limits.

## Active Follow-up — 2026-10-29 (photo essentials, automatic digital framing, and clean Original)

- User approved photo essentials with automatic framing/exposure and manual override. Implemented rear wide/ultra-wide switching where supported, bounded pinch and step zoom with AVFoundation ramps, tap focus/exposure points, bounded exposure compensation, flash off/auto/on, and off/3s/10s capture timer.
- Added Vision-driven, smoothed digital subject framing. Drag/pinch and step zoom pause automatic framing; an explicit resume control restores it. The saved JPEG gets the same crop transform as the live preview. On iPhone 12 this is a digital crop, not optical panning.
- Added bounded highlight/shadow exposure compensation while native autofocus, autoexposure and white balance remain enabled by default. Existing Vision analysis suggests a reposition when glare is likely; a single capture cannot guarantee reflected-glare removal.
- Original crop now defaults to full bleed, no date stamp, and no decorative white border. A subtle temporary composition outline remains a live viewfinder guide and is not baked into exports unless an explicit frame treatment is selected.
- Repaired `CameraCaptureIntent` to request immediate foreground presentation on iOS 26+ and return a result, retaining the Lock Screen capture extension’s independent viewfinder and file handoff. A temporary URL-based deep-link experiment prompted an extra system confirmation on simulator; that route and its temporary plist/project edits were removed. Control placement and iOS routing still need physical confirmation.
- Physical launch found a concrete startup crash: `NSInvalidArgumentException: -[AVCaptureDevice setAutoVideoFrameRateEnabled:] Not supported by this device - use -[AVCaptureDeviceFormat isAutoVideoFrameRateSupported]`. Removed the unsupported setter and now select a format-supported 30–60 fps range (or 60-only when available). Latest signed rebuild installed and launched on iPhone 12; app process remained running.
- Verification: iOS 27.0 simulator suite passed 69/69 (0 failures); signed generic-device build passed; installed and launched on iPhone 12; `git diff --check` passed. Xcode continues to emit non-fatal simulator metadata `invalidDigitCount(94232)` diagnostics.
- Changed files: `FramedLocal/CameraControls.swift` (new), `FramedLocal/ContentView.swift`, `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/FilmRenderer.swift`, `FramedLocal/FrameRenderer.swift`, three `FramedLocalCameraCaptureIntent.swift` files (app/capture/control targets), `FramedLocalTests/GuidanceEngineTests.swift`, `FramedLocalTests/RendererTests.swift`, and this status file. Existing project/Xcode configuration changes and camera/widget targets were preserved.
- Remaining blockers: detailed physical checks are still needed for both cameras/lenses, zoom smoothness and limits, focus/exposure, flash/timer, tracking/manual override, saved crop/frame output, Lock Screen control routing/handoff, and Photos export. The connected-device launch check confirms no immediate crash but is not a substitute for those tests.
- Exact next smallest step: on the iPhone 12, verify the live preview opens and test wide/ultra-wide switching plus zoom and tap focus; then check timer/flash, auto-frame override/resume, and an Original capture has no border. If the camera shortcut does not open FramedLocal, collect the control location and iOS response for its intent-routing adjustment.

## Active Follow-up — 2026-10-28 (60 fps subject lock, minimal camera UI, Lock Screen access)

- User approved implementing the 60 fps preview goal, stable subject outline, compact live UI, and iOS 18+ Lock Screen camera control. Manual iPhone testing remains deferred at the user's request.
- Implemented: processed `MTKView` targets 60 fps and skips repeat draws without a new camera frame; camera setup chooses a preview format that supports 60 fps at up to 1080p, uses adaptive AVFoundation cadence on iOS 18+, and uses a 30–60 fps range on earlier systems. Live view now shows only the subject brackets (no thirds grid), eases between Vision observations, and holds through a 0.22-second tracking dropout before clearing. Live settings are grouped into a compact “Looks & frame” sheet. Zoom remains an explicit camera adjustment.
- Lock Screen implementation: added the iOS 18+ `CameraCaptureIntent`, ExtensionKit locked-camera target, and WidgetKit Control Center/Lock Screen control. The capture viewfinder supports front/rear switching and hardware capture events, writes JPEGs into LockedCameraCapture session content, and routes users into FramedLocal to import and edit a new copy. Xcode embeds the capture extension under `.app/Extensions` and the control under `.app/PlugIns`. The app consumes the newest JPEG from session content.
- Verification: clean iOS Simulator build passed; generic unsigned iOS device build passed; final iOS 27.0 simulator suite passed 64/64 (0 failed, 0 skipped; result at `build/DerivedData/Logs/Test/Test-FramedLocal-2026.10.28_23-24-17--0700.xcresult`); project plist validation and `git diff --check` passed. Xcode emitted non-fatal simulator metadata `invalidDigitCount(94232)` diagnostics. The latest build was installed and launched in the iOS 27.0 simulator; its camera permission prompt is awaiting a response. The Simulator GUI app is absent from this Xcode installation, but `simctl` can install, launch, and capture a simulator screenshot.
- Errors and fixes during this follow-up: corrected the AVFoundation adaptive-frame-rate property spelling to `isAutoVideoFrameRateEnabled`; decomposed `ContentView.body` after SwiftUI type-check timeouts; excluded explicit extension `Info.plist` files from synchronized resource membership after duplicate-output errors; moved camera session work and JPEG writes into a serial capture pipeline after Swift 6 reported an actor-isolated photo delegate; used `$(EXTENSIONS_FOLDER_PATH)` for ExtensionKit embedding after Xcode warned about the wrong bundle directory. Initial smoother tests failed on exact floating-point rectangle equality and an incorrect short-loss expectation; assertions now use tolerance and model the intended 0.22-second dropout grace, and the full suite passes.
- CodeRabbit CLI reviewed the uncommitted diff and raised two minor issues: the processed Metal preview was still set to 30 fps, and the camera-switch icon lacked a VoiceOver label. Both were fixed; the simulator suite and generic iOS build passed again.
- Changed files for this follow-up: `FramedLocal/ContentView.swift`, `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `FramedLocal.xcodeproj/project.pbxproj`, new files under `FramedLocalCapture/` and `FramedLocalCaptureWidget/`, and this status file. The pre-existing local signing/team edits in the project file were preserved.
- Physical-device camera cadence, latency, front/rear capture, Lock Screen control discovery, and capture handoff remain unverified because the iPhone is unavailable for manual testing.
- Exact next smallest step: when available, respond to the camera permission prompt and confirm the latest app starts on device; then exercise both cameras and the Lock Screen capture-to-editor handoff on the iPhone 12.

## Latest Update — 2026-10-28

- Reworked the slow live preview after the user said it felt like a slideshow. Natural/original mode now displays only `AVCaptureVideoPreviewLayer` and skips live image rendering. When a film look or crop is selected, a single-buffer `MTKView` renders Core Image directly to a Metal texture at a 30 fps target and 1.5× display scale; there are no per-frame `CGImage` allocations or `@Published UIImage` updates. The view pauses when the camera session is inactive. Night Grain uses one reusable tiled preview texture; the final capture/export still uses its full-resolution deterministic grain path.
- Removed Vision from the capture-output callback: frames pass to an asynchronous analyzer through a one-in-flight gate. Face detection begins at about 3.6 Hz, saliency runs at most once per second only when no face is found, and an active tracked subject uses the lightweight tracker at up to 12 Hz. Detection seeds an automatic tracker so the outline can follow the subject between detections. The camera data-output delegate is detached when both composition guidance and processed preview are off; disabling guidance also stops device-motion updates. SwiftUI animates the subject outline between tracker updates.
- Custom crop ratios retain the black surround and fitted preview/frame/date/guide bounds. This follows Apple's preview guidance: use the native preview layer for direct low-latency display and use Video Data Output for actual per-frame processing. The new processed route uses Apple's Core Image-to-Metal texture rendering API and one reusable CIContext per preview view. References: [Apple WWDC26 camera preview guidance](https://developer.apple.com/videos/play/wwdc2026/303/), [CIContext GPU rendering](https://developer.apple.com/documentation/coreimage/cicontext).
- Verification: iOS 27.0 simulator suite passed 61/61, 0 failures, 0 skipped; generic unsigned iOS device build passed; `git diff --check` passed. New tests cover adaptive Vision cadence and detaching the video-output delegate when guidance and processed preview are both inactive. The iPhone 12 is currently unavailable in `devicectl`, so this revision is not yet installed on it. The previous signed build launched and remained running, but it predates these changes. Simulator tests do not verify Metal camera rendering or physical performance.
- Build attempts this turn: first simulator build failed with `main actor-isolated property 'compositionGuidanceEnabled' can not be referenced from a nonisolated context`; removed that invalid read during nonisolated session configuration. Swift also warned that `CVPixelBuffer` was captured directly in an `@Sendable` Vision-queue closure; added the retained `AnalysisPixelBuffer` sendability wrapper. The next simulator/generic-device builds passed. Xcode continues to print its known non-fatal simulator metadata diagnostic `invalidDigitCount(94232)`.
- The user cannot test manually now and will try later. No matching recent FramedLocal mobile crash report was found in the Mac's local MobileDevice crash-log folder; exact cause of the earlier crash remains unknown.
- Changed files in this turn: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocal/FilmRenderer.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/PROJECT_STATUS.md`, and `docs/TEST_MATRIX.md`. The pre-existing `FramedLocal.xcodeproj/project.pbxproj` user/Xcode change remains untouched.
- Exact next smallest step: install this current build on the iPhone when it reconnects; confirm smooth preview, selected-look/crop latency, and subject-outline tracking. If it crashes or stutters, collect the newest FramedLocal `.ips`; then continue the front/rear, capture, frame/preset, and Photos matrix.

## Companion Website — 2026-10-28

- Created a sky-blue, project-specific FramedLocal site in `site/`, following the visual clarity and interactive-preview structure of the user's ZeroClick site without reusing its palette or assets. The interactive sample supports five looks, three frames, date stamp, capture/print-preview modes, front/rear preview, orientation, grid, guidance, and reset. All illustration assets are local; the page does not access a visitor camera or make network requests.
- Added `.github/workflows/pages.yml` to deploy only `site/` to GitHub Pages at `https://mithundb.github.io/FramedLocal/`. The user then explicitly requested that the existing app repository be made public; GitHub now reports it public. Initial deployment from the private repo failed with `Your current plan does not support GitHub Pages for this repository.` After making the repo public and enabling Pages, deployment run `40804412818` succeeded.
- During the private-repo Pages diagnosis, a site-only repo `MithunDB/FramedLocalSite` was briefly created and its deployment succeeded. After the user redirected the plan to make `MithunDB/FramedLocal` public, the temporary site Pages site was deleted, its repo made private, and the repo archived. The canonical public site is `https://mithundb.github.io/FramedLocal/`.
- Changed files: `.github/workflows/pages.yml`, `README.md`, `site/index.html`, `site/styles.css`, `site/app.js`, `site/assets/mark.svg`, `site/assets/sample-coast.svg`, `docs/PROJECT_STATUS.md`.
- Verification: local browser preview at desktop and mobile widths; preset, print-preview, lens-switch, sample-capture, and reset interactions worked; browser console showed no warnings/errors. `node --check site/app.js`, local HTTP checks for HTML/CSS/SVG assets (all 200), and `git diff --check` passed. No Xcode build or app test run in this website-only step.
- Exact next smallest step: commit and push the README/status correction, verify the final GitHub state, then resume physical iPhone installation and acceptance when the device is available.

## Last Completed Step

- Rechecked the remaining source-only acceptance surface after the lens-switch recovery change. Capture, local editing/import, presets/frames, Vision guidance/tracking, and save paths are implemented; no new code gap was confirmed. PhotoKit's add-only path deliberately falls back to Photos Recents when an album cannot be fetched, preserving the no-full-library-access rule. Whether the created `Framed` album can be reused under the iPhone's add-only authorization must be confirmed on-device.
- No tests/builds were run in this audit-only step. Apple PhotoKit documentation reviewed; no code changed. Current known verification remains 54/54 simulator tests on iOS 27.1 and iOS 26.2 plus a successful generic unsigned iOS build. Physical signing, installation, capture, album reuse, and export remain pending.
- Changed files: `docs/PROJECT_STATUS.md`.
- Exact next smallest step: once the iPhone 12 is available, pair it, select the development team, provision/install the app, then run the physical-device matrix. No further source-only implementation gap is currently identified.

- Hardened the front/rear lens-switch failure paths to stop Core Motion and remove the current orientation observer before presenting Retry. The next successful `startIfAuthorized()` can now install a fresh observer generation instead of leaving a stale callback alive after the failed switch.
- Verification: iOS 27.1 simulator suite passed (54 tests, 0 failures, 0 skipped); iOS 26.2 simulator suite passed (54 tests, 0 failures, 0 skipped); generic unsigned iOS device build passed; `git diff --check` passed. Recurring Xcode simulator metadata `invalidDigitCount` diagnostics only. Lens-switch failure/retry still requires physical camera validation.
- Review: local read-only diff review found no actionable defect; CodeRabbit CLI review raised 0 issues. The repo is not installed in the connected CodeRabbit organization, so the CLI used its free review allowance.
- Changed files: `FramedLocal/ContentView.swift`, `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Code committed and pushed as `d0fb0b6` (`Stop motion observers after lens switch failure`).
- Source-only acceptance audit found no remaining planned app feature missing from implementation. Remaining work is physical-device signing/install and runtime acceptance; the iPhone 12 is not connected and no provisioning profile exists. Exact next smallest step: connect/pair the iPhone, select the Apple development team, let Xcode provision `local.mithundb.framed`, then work through `docs/TEST_MATRIX.md` on device.

- Fixed sensor cleanup on AVFoundation media-services reset. Automatic camera recovery now stops the old Core Motion stream and removes the orientation observer before restarting; this prevents an observer tied to an invalid generation from silently ignoring all later device rotations. Added a sensor-generation replacement regression check.
- Verification: iOS 27.1 simulator suite passed (54 tests, 0 failures, 0 skipped); iOS 26.2 simulator suite passed (54 tests, 0 failures, 0 skipped); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Actual media-reset and orientation behavior remains physical-device-only.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: commit and push the sensor recovery fix; exercise media-services reset and post-recovery rotation on the iPhone when available.

- Hardened the Night Grain allocation boundary: validate that the Core Image extent is finite, positive, and within the renderer's 2,400-pixel bound (allowing one pixel for rounding) before converting to `Int`; then retain checked pixel/byte multiplication. Added a 3,200×1,800 source regression test proving the Night Grain render path remains capped.
- Verification: iOS 27.1 simulator suite passed (53 tests, 0 failures, 0 skipped); iOS 26.2 simulator suite passed (53 tests, 0 failures, 0 skipped); generic unsigned iOS device build passed; `git diff --check` passed. Recurring Xcode simulator metadata `invalidDigitCount` diagnostics only. Physical memory behavior remains unmeasured.
- Changed files: `FramedLocal/FilmRenderer.swift`, `FramedLocalTests/RendererTests.swift`, `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: commit and push this renderer-boundary fix; later profile peak memory and Night Grain latency on iPhone 12.

- Switched guidance debounce, horizon-hint stability, and the analysis rate limiter to monotonic process uptime instead of wall-clock time. System date/time adjustments can no longer stall or prematurely advance these elapsed-time intervals. Added a finite/nondecreasing clock unit check.
- Verification: iOS 27.1 simulator suite passed (52 tests, 0 failures, 0 skipped); iOS 26.2 simulator suite passed (52 tests, 0 failures, 0 skipped); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Physical cadence and sensor behavior remain unmeasured.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: commit and push this verified timing-source fix; continue local reliability review while physical-device signing and acceptance await the iPhone.

- Ran the full hosted simulator suite on the available iOS 26.2 iPhone 17 Pro simulator as an additional runtime-compatibility check. Result: 51 passed, 0 failed, 0 skipped. Xcode emitted its recurring simulator metadata `invalidDigitCount` diagnostic only.
- Changed files: `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: continue source-level reliability review; install and run on iPhone 12 once device pairing and provisioning are available.

- Reduced peak Night Grain bitmap memory by generating the seeded noise pixels directly into one `Data` allocation instead of building a full Swift byte array and copying it into `Data`. Preserved the per-65,536-pixel cancellation checks and added checked multiplication before allocating the RGBA buffer.
- Verification: iOS 27.1 simulator suite passed (51 tests, 0 failures, 0 skipped), including byte-for-byte deterministic Night Grain output; generic unsigned iOS device build passed; `git diff --check` passed. No new errors; recurring Xcode simulator metadata `invalidDigitCount` diagnostics only. Physical-device memory/latency remains unmeasured.
- Changed files: `FramedLocal/FilmRenderer.swift`, `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: continue source-level reliability review; later measure Night Grain memory/latency on iPhone 12 during device acceptance.

- Rechecked local signing/install readiness while continuing the code audit. A valid Apple Development certificate is present, but no provisioning profile exists for `local.mithundb.framed`; the iPhone is still absent from `devicectl`. A generic signed build with a command-line team override failed with Xcode's exact error: `No profiles for 'local.mithundb.framed' were found ... Automatic signing is disabled and unable to generate a profile. To enable automatic signing, pass -allowProvisioningUpdates to xcodebuild.` Did not request portal provisioning without a connected/registered device. Unsigned generic iOS build and simulator suite remain green.
- Changed files: `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: when the iPhone is available, connect/pair it and allow Xcode automatic provisioning, then build/install and work through the physical acceptance matrix.

- Closed a camera-analysis/UI race: Vision results now carry their analysis generation into the MainActor callback, which rechecks that the camera stream is still current before updating guidance. A result accepted just before pause can no longer overwrite the reset guidance afterward.
- Verification: iOS 27.1 simulator suite passed (51 tests, 0 failures, 0 skipped); generic unsigned iOS device build passed; `git diff --check` passed. CodeRabbit reviewed the changed files and raised 0 issues; read-only review found no actionable defects. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. This remains code-level evidence; camera lifecycle behavior needs the iPhone.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: commit and push this verified code slice; then the remaining acceptance step is signed installation and physical iPhone validation when the user is available.

- Reset guidance haptic de-duplication when the camera analysis stream pauses. Re-entering “Hold steady” after a stop, lens switch, or recovery can now trigger its entry haptic again; added nil-previous-message policy coverage.
- Verification: iOS 27.1 simulator suite passed (50 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Physical haptic behavior is still pending.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: commit and push the haptic lifecycle reset; continue local audit afterward.

- Reset live guidance and analyzer state whenever analysis pauses for stop, interruption, recovery, startup, or lens change. The visible prompt returns to “Searching for a subject”; analyzer selection, tracking request, guidance debounce, and rate-limit state reset before the next stream.
- Verification: iOS 27.1 simulator suite passed (50 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Actual camera restart/scene transitions still need physical validation.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocal/CompositionAnalysis.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `f9431b2` (`Reset guidance when camera analysis pauses`).
- Exact next smallest step: continue the local code audit and physical-device acceptance when available.

- Made Vision inference failures clear any stale `VNDetectedObjectObservation` and `VNTrackObjectRequest` before returning the debounced low-confidence fallback. The next frame can re-detect rather than repeatedly retrying a tracking request that itself failed.
- Verification: iOS 27.1 simulator suite passed (50 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Injected Vision runtime failure remains a device/runtime validation item.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `132e3b4` (`Reset Vision tracking after analysis errors`).
- Exact next smallest step: continue local audit; live Vision behavior still needs the iPhone.

- Bounded tap-to-select fallback: taps inside a detected face/saliency box select it; taps just outside can select the nearest box only within a 0.12 normalized distance; distant taps now report no subject instead of silently tracking an unrelated candidate.
- Verification: iOS 27.1 simulator suite passed (50 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Tap tolerance and tracking feel require physical-device tuning.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `be2792a` (`Bound subject selection fallback distance`).
- Exact next smallest step: continue source audit; user device tuning remains outstanding.

- Corrected composition edge metrics to account for Vision's bottom-left normalized coordinates (`top = 1 - maxY`). Previously a subject near the top could be mistaken for one near the bottom, reversing vertical guidance. Added top/bottom edge regression assertions.
- Verification: iOS 27.1 simulator suite passed (50 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Live camera guidance still requires iPhone validation.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `c3959d3` (`Fix Vision vertical edge guidance`).
- Exact next smallest step: continue auditing guidance geometry and then await physical scene validation.

- Hardened `FrameRenderer` to use an orientation-aware ImageIO thumbnail capped at 2,400 px before drawing its canvas. This avoids decoding oversized sources at full resolution before reducing them and bakes EXIF orientation into output pixels. Added a large EXIF-rotated-source regression test.
- Verification: iOS 27.1 simulator suite passed (49 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Recurring Xcode `invalidDigitCount` simulator metadata diagnostics remain non-fatal.
- Changed files: `FramedLocal/FrameRenderer.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `7fc335b` (`Bound frame renderer source decoding`).
- Exact next smallest step: continue the local memory/performance audit; next external dependency remains selecting the development team and connecting the physical iPhone for signed install/runtime checks.

- Completed a release/privacy configuration audit. Simulator and device-built Info.plists contain `local.mithundb.framed`, display name `Framed`, camera usage text, and add-only Photos usage text; no full-library read usage key exists. Source scan found no app network client, analytics, or cloud SDK references. `assetutil` confirms the 1024×1024 AppIcon rendition is compiled. Automatic signing is enabled but no development team is selected, so signed physical installation still requires account/team setup.
- Changed files: `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md`.
- Exact next smallest step: select the user's Apple development team in Xcode and pair the iPhone; then produce a signed device build and work through the physical acceptance matrix. No other planned feature is currently identified as missing from source; runtime proof remains outstanding.

- Added original app-icon artwork and connected it in the universal iOS asset catalog (`AppIcon.png`, 1024×1024). Simulator and generic iOS device asset-catalog builds pass. The previous icon set contained no image entries.
- Changed files: `FramedLocal/Assets.xcassets/AppIcon.appiconset/Contents.json`, `FramedLocal/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `319c57f` (`Add original FramedLocal app icon`).
- Exact next smallest step: run the release/privacy configuration audit and resolve signing setup needed for installing on the physical iPhone; runtime camera/Photos/guidance checks still require the device.

- Corrected the top-level test-matrix count from 29 to the latest verified 48 tests and updated the coverage description. Source run evidence is the latest iOS 27.1 simulator `.xcresult` from the generation-guard change; no app code changed in this documentation correction.
- Exact next smallest step: continue source audit for the next concrete reliability gap.

- Added generation checks before and after queued lens-switch reconfiguration. A switch invalidated by stop/background or a newer session request now exits before mutating the camera or resuming analysis.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Queue timing on physical camera remains unverified.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `6b4b1c7` (`Guard stale lens switch work`).
- Exact next smallest step: continue camera queue recovery review; physical timing checks still need the iPhone.

- Clarified camera session intent vs readiness by renaming the private desired-run flag to `shouldRunSession`. `capture()` now checks the published actual-session-ready state (and the capture-in-progress state) instead of the intent flag, preventing direct/programmatic capture attempts during a lens switch or recovery. Added policy assertions for stopped and busy capture states.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Physical capture timing remains pending.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `86c9cbf` (`Require ready camera before capture`).
- Exact next smallest step: continue local audit; physical capture tests remain pending.

- PhotoKit album-placeholder audit proposed a guard that the SDK rejects because `placeholderForCreatedAssetCollection` is non-optional (`initializer for conditional binding must have Optional type, not PHObjectPlaceholder`). Reverted that speculative change; no app code remains from the attempt. Re-ran simulator suite (48/48), generic unsigned iOS build, and `git diff --check`; all passed. The compiler error was the only new error this turn.
- Exact next smallest step: continue source audit for a verified improvement; do not add an impossible nil check to the album placeholder.

- Added explicit AVFoundation session-observer cleanup to `CameraController.stop()`. Authorized restart re-registers observers as needed, so repeated editor/background camera stops do not leave stale notification callbacks in NotificationCenter.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Repeated physical camera/editor lifecycle still needs iPhone verification.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `96b9623` (`Remove camera observers when stopping`).
- Exact next smallest step: continue local review; physical camera lifecycle remains unverified.

- Routed Vision analysis failures through the existing low-confidence `GuidanceEngine` state instead of immediately replacing guidance with an unsmoothed recovery message. Brief inference errors preserve the current advice; sustained low confidence reaches the established recovery wording.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Live Vision failure behavior/scenes remain a physical-device validation item.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `9912566` (`Stabilize guidance after Vision errors`).
- Exact next smallest step: continue code review and use the iPhone for final live-scene tuning when available.

- Moved PhotoKit-picker image downsampling/orientation baking and JPEG encoding onto a dedicated `PhotoImportWorker` actor so large image conversion does not run on the UI actor. Updated the large data-backed and file-backed import tests to exercise the actor worker path.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Photos provider transfer/runtime responsiveness remains a physical-device check.
- Changed files: `FramedLocal/PhotoImportService.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `96a02a1` (`Move photo import conversion off UI actor`).
- Exact next smallest step: continue source-level performance and recovery review; physical picker/device tests remain pending.

- Fixed the lens-switch configuration-error retry path. A thrown reconfiguration now stops the damaged AVFoundation session and clears the desired-running flag before exposing Retry, allowing `startIfAuthorized()` to configure the prior lens again instead of returning early.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Physical reconfiguration failure/retry remains pending.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `ec62405` (`Recover camera after lens switch failure`).
- Exact next smallest step: continue the local code audit; physical-device runtime checks remain with the user.

- Fixed Photos-picker retry state: clear the selected item after import success/failure, explicit cancel, and view dismissal. This allows a failed or canceled image to be selected again and keeps stale selections from blocking a same-image retry.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only; no build/test failure.
- Changed files: `FramedLocal/ContentView.swift`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `9583897` (`Reset photo picker after import`).
- Exact next smallest step: continue reviewing camera/export edge cases; physical Photos picker behavior remains unverified until iPhone testing.

- Verified that the camera session is actually running before publishing readiness after initial startup and lens reconfiguration. If AVFoundation returns with the session stopped, the camera UI now exposes Retry instead of enabling capture. Added a unit test for the readiness outcome policy.
- Verification: iOS 27.1 simulator hosted suite passed (48 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Physical startup/lens failure injection is still pending.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: commit and push this verified camera-readiness slice, then continue reviewing capture/export recovery without claiming physical-device validation.

- Hardened the PhotoKit asset-only fallback. It now records whether `PHAssetCreationRequest` produced an asset placeholder and resolves the fallback through the same transaction outcome policy as the album save. A success callback without an actually-created asset is treated as failure, so the UI cannot report a false Photos save.
- Verification: iOS 27.1 simulator hosted suite passed (47 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Actual PhotoKit transaction/fallback behavior remains a physical-device runtime check.
- Changed files: `FramedLocal/PhotoLibraryService.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `c0a1db7` (`Verify Photos fallback asset creation`).
- Exact next smallest step: continue end-to-end PhotoKit and camera device readiness.

- Reduced camera-interruption sensor work and rejected stale sensor callbacks. Camera interruption, unrecoverable runtime error, and explicit stop now stop Core Motion and device-orientation notifications, clear horizon state, and reset its stability timer. Motion/orientation callbacks carry a generation token so queued samples from a prior session cannot repopulate stale tilt or reconfigure camera connections after stop. Normal startup/recovery restarts updates.
- Verification: iOS 27.1 simulator hosted suite passed (47 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Actual interruption/motion sensor behavior needs physical-device validation.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `b600fff` (`Stop camera motion work during interruptions`).
- Exact next smallest step: continue final code review and await iPhone for hardware validation.

- Added renderer-level coverage for crop positioning on a portrait-displayed EXIF-rotated source. The test uses split-color content to prove the vertical position values select different image regions while preserving square output dimensions and the original encoded bytes.
- Verification: iOS 27.1 simulator hosted suite passed (47 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. UI slider direction/feel still needs physical-device review.
- Changed files: `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `c9d2bf3` (`Test crop movement on EXIF rotated image`).
- Exact next smallest step: continue camera/editor device-readiness work.

- Made Photos import naming accurately describe its input and completed coverage for both provider paths. Renamed `PhotoImportService.loadJPEG` to `loadImageData` because small source files may remain HEIC/original bytes until Core Image renders them to JPEG. Added tests proving file-backed small imports preserve bytes and file-backed oversized EXIF-rotated images become upright, bounded JPEGs without modifying source files.
- Verification: iOS 27.1 simulator hosted suite passed (46 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Actual Photos provider format behavior remains device/runtime validation.
- Changed files: `FramedLocal/PhotoImportService.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `646db6f` (`Verify photo import path parity`).
- Exact next smallest step: continue reliability work and device validation when the phone is available.

- Tightened render cancellation at the UI publication boundary. After `PreviewImageDecoder` completes its synchronous ImageIO thumbnail work, the render task now checks cancellation again before moving the resulting image into SwiftUI state. This prevents a render cancelled during thumbnail decoding (such as editor disappearance or a newer render) from publishing stale preview data.
- Verification: iOS 27.1 simulator hosted suite passed (45 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Cancellation during actual ImageIO decode still needs device/runtime timing validation.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `38f1531` (`Check render cancellation after preview decode`).
- Exact next smallest step: continue checking editor source lifetimes and camera/export behavior.

- Hardened Photos-picker temporary-file cleanup. The `FileRepresentation` adapter now checks task cancellation immediately after copying the provider’s file and removes the destination on any copy/cancellation error before rethrowing. The caller’s existing `defer` still removes successfully returned temporary files after decode/downsample completes.
- Verification: iOS 27.1 simulator hosted suite passed (45 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Provider cancellation/temporary-file cleanup has no direct UI/provider integration test and still needs runtime validation.
- Changed files: `FramedLocal/PhotoImportService.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `03ee188` (`Clean canceled photo transfer files`).
- Exact next smallest step: continue reviewing capture/editor source lifetimes.

- Extended memory-warning handling to release the in-memory editor preview image. On warning, the view drops its `UIImage`, clears Core Image caches, and recreates the display preview at 1,000 px from the already-rendered JPEG. Export bytes and imported/captured source data remain available; a generation check prevents a delayed low-memory decode from restoring a preview after the user discards or changes the render. Added a decoder test for the smaller preview bound.
- Verification: iOS 27.1 simulator hosted suite passed (45 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Actual memory-warning delivery/reclamation and on-device preview appearance remain to be checked on iPhone.
- Changed files: `FramedLocal/FrameRenderer.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `4a95333` (`Release editor preview on memory warning`).
- Exact next smallest step: continue remaining camera and export reliability review.

- Closed a camera analysis frame-retention edge. `VideoAnalysisDelegate` now checks its generation gate before retaining the latest pixel buffer; callbacks arriving while paused clear/ignore the buffer. Pausing also queues buffer release and subject-selection cleanup on the serial analysis queue, avoiding cross-queue access and releasing the last preview frame after stop/interruption/lens reconfiguration.
- Verification: iOS 27.1 simulator hosted suite passed (44 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. Physical camera interruption and memory behavior remain unverified.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `42558df` (`Release paused camera analysis frames`).
- Exact next smallest step: continue camera pipeline review and validate on iPhone when connected.

- Audited the built app’s privacy surface and local-only constraint. The generated simulator Info.plist contains the intended `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`, display name `Framed`, and bundle ID `local.mithundb.framed`; it has no full-library `NSPhotoLibraryUsageDescription` or extra location, microphone, tracking, or local-network usage prompt. App source/project scan found no network client, analytics SDK, or package dependency. Photos import uses the system `PhotosPicker`, while export requests `.addOnly` authorization.
- Verification: static inspection of the current built simulator Info.plist, app sources, and project files. No source changes or new build/test run in this audit; prior verified state remains 44/44 simulator tests and a passing generic unsigned iOS build. Physical permission behavior still needs the iPhone.
- Changed files: `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md` only.
- Audit record committed and pushed as `403f6b2` (`Record local privacy audit`).
- Exact next smallest step: continue camera/editor reliability work and complete physical permission/capture checks when the iPhone is available.

- Performed a current simulator install/launch smoke check. The built app installed and launched as `local.mithundb.framed`; iOS displayed the camera permission prompt with the expected “preview and capture photos” explanation. The simulator then reported “No suitable camera is available,” as expected because it has no camera hardware. This does not validate or contradict physical iPhone camera behavior.
- Verification: latest iOS 27.1 simulator hosted suite passed (44 tests, 0 failures); generic unsigned iOS device build passed; simulator install/launch succeeded; `git diff --check` passed at the last source change. One `simctl terminate` attempt returned `found nothing to terminate` because the app process had already exited after the initial permission UI; relaunch succeeded. A simulator camera permission grant could not exercise camera capture because no camera device is available.
- Changed files: `docs/PROJECT_STATUS.md`, `docs/TEST_MATRIX.md` only.
- Status record committed and pushed as `3fc8c97` (`Record simulator install launch check`).
- Exact next smallest step: continue reviewing camera/editor lifecycle edges, then validate front/rear capture and permissions on the iPhone when available.

- Closed a stale-output risk in the editor. Starting any new preset/crop/frame/date render now clears both the prior export JPEG and preview before work begins. If the new render fails, the Save button cannot become enabled with bytes from the previous editor settings.
- Verification: iOS 27.1 simulator hosted suite passed (44 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics only. The new render-failure UI transition still needs runtime interaction coverage.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `e50c026` (`Clear stale output before editor rerenders`).
- Exact next smallest step: continue reviewing camera/editor lifecycle edges.

- Added low-memory recovery for the shared Core Image renderer. The app now observes UIKit memory warnings and asks `FilmRenderer` to clear its `CIContext` intermediate caches. Added a regression test that clears the cache and confirms a subsequent preset render still produces JPEG output.
- Verification: iOS 27.1 simulator hosted suite passed (44 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged the recurring simulator metadata `invalidDigitCount` diagnostics only. Memory-warning delivery and cache-reclamation effect require device/runtime measurement.
- Changed files: `FramedLocal/FilmRenderer.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `d3773be` (`Clear render caches on memory warning`).
- Exact next smallest step: continue reviewing unverified camera and editor lifecycle edges for code-level improvements.

- Reduced decoded preview memory independently of export quality. `PreviewImageDecoder` now creates an orientation-aware ImageIO thumbnail capped at 1,800 pixels on the long edge, while `renderedCapture` still retains the full bounded JPEG (up to 2,400 px) for export. Added coverage for small-image dimension preservation and bounding a large preview decode.
- Verification: iOS 27.1 simulator hosted suite passed (43 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted recurring simulator metadata `invalidDigitCount` diagnostics only. Physical rendering latency and perceived preview sharpness need device review.
- Changed files: `FramedLocal/FrameRenderer.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `0adf534` (`Bound decoded editor preview size`).
- Exact next smallest step: continue reviewing performance and runtime failure behavior before iPhone validation.

- Reduced peak memory for large Photos-picker imports. The importer now tries a file-backed transfer first, inspects dimensions through ImageIO, and generates an orientation-correct JPEG working copy directly from the temporary file when the source exceeds the 2,400-pixel long-edge bound. It reads source bytes into memory only for already-bounded images; if file transfer is unavailable it falls back to the existing Data transfer path. The temporary copy is removed with `defer`, and the Photos source asset is untouched. Added a test that checks file-backed downsampling, output bounds, and source-file byte preservation.
- Verification: iOS 27.1 simulator hosted suite passed (42 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged the recurring simulator metadata `invalidDigitCount` diagnostics, which did not fail the build. Picker provider behavior, peak memory, and output appearance remain device/runtime checks.
- Changed files: `FramedLocal/PhotoImportService.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `1dfe5d7` (`Downsample file-backed photo imports`).
- Exact next smallest step: inspect asynchronous rendering for repeated preset changes and memory pressure behavior.

- Audited Photos-picker/editor memory use. `PhotoImportService` now converts imported images above the renderer limit (2,400 px long edge) into an orientation-correct JPEG working copy, with cancellation checks around thumbnail decode/encode. Imports already within bounds retain their original bytes. Temporary transferred files remain removed with `defer`; source Photos assets are never modified. Added coverage for preserving small source bytes and downsampling/baking EXIF orientation for oversized input.
- Verification: iOS 27.1 simulator hosted suite passed (41 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged recurring simulator metadata `invalidDigitCount` diagnostics; they did not fail the build. Physical memory use, picker transfer cancellation, and visual output remain device/runtime checks.
- Changed files: `FramedLocal/PhotoImportService.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Code committed and pushed as `e9acb5e` (`Bound oversized photo imports`).
- Exact next smallest step: continue auditing memory retention around decoded preview and save lifetimes before physical-device capture/export checks.

- Added cooperative cancellation checks to `FilmRenderer`, `FrameRenderer`, and `PreviewImageDecoder` so canceled jobs exit at entry/boundaries; Night Grain also checks cancellation every 65,536 generated noise pixels. Added a gated test that cancels a queued render before it reaches the renderer and verifies it throws `CancellationError`. Changed `FramedLocal/FilmRenderer.swift`, `FramedLocal/FrameRenderer.swift`, and `FramedLocalTests/RendererTests.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (39 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged only simulator metadata `invalidDigitCount` diagnostics. Physical memory/cancellation behavior on device remains unmeasured.
- Committed and pushed as `9a5f18b` (`Cooperate with canceled preview renders`).
- Exact next smallest step: continue auditing import/editor memory behavior, then resume physical camera/Photos checks when the iPhone is available.

- Prevented leaving/changing the editor while a Photos write is in flight: preset, crop, position, frame, and date controls are disabled during save; Retake/Cancel are also disabled. This prevents an asynchronous save completion message from appearing after the user has left the result screen. Changed `FramedLocal/ContentView.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (38 tests, 0 failures); generic unsigned iOS build passed; `git diff --check` passed. Only recurring simulator metadata `invalidDigitCount` diagnostics appeared. Physical Photos-save interaction remains device-only.
- Committed and pushed as `d950cce` (`Lock editor controls while Photos saves`).
- Exact next smallest step: continue auditing memory/cancellation and Photos-picker/editor lifecycle; physical camera, PhotoKit, and UI interaction checks await an iPhone connection.

- Extracted PhotoKit transaction recovery into `PhotoSaveTransactionOutcome`, now used by the production completion handler. It requires a created asset before reporting any success or retry, distinguishes album/Recents success, retries asset-only only after an album mutation failure, and reports other failures. Added branch tests in `FramedLocalTests/GuidanceEngineTests.swift`; changed `FramedLocal/PhotoLibraryService.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (38 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted only simulator build-number `invalidDigitCount` diagnostics. PhotoKit transactions themselves still require a physical-device run.
- Committed and pushed as `47a843b` (`Test Photos save recovery outcomes`).
- Status follow-up was pushed as `e1c2b1e` (`Record Photos save policy status`).

- Hardened asynchronous camera startup/recovery in `FramedLocal/ContentView.swift`: verify the session generation before calling `startRunning()` and again after it returns; if Stop/backgrounding/editor transition invalidated the request while start was in flight, stop the session immediately and do not resume Vision. This closes a hardware/privacy race where stale callbacks were ignored but the physical capture session could still start.
- Verification: iOS 27.1 simulator suite passed (37 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Existing session-generation unit coverage validates stale request invalidation; physical timing and camera power state still need device verification. Xcode logged only `invalidDigitCount` simulator metadata diagnostics.
- Committed and pushed as `39153ad` (`Guard stale camera session starts`).
- Exact next smallest step: inspect and add focused PhotoKit transaction/fallback policy coverage, then return to physical install/camera/Photos checks when the iPhone is connected.

- Stop the AVFoundation camera session and motion updates when a captured or imported image enters the editor, instead of leaving a hidden preview/analysis stream active. Reset the unavailable horizon sample on stop; Retake and editor Cancel explicitly re-request/start the camera session. Changed `FramedLocal/ContentView.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (37 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged simulator build-number `invalidDigitCount` diagnostics. Simulator tests cannot verify physical camera shutdown/restart.
- Committed and pushed as `a7d2519` (`Stop camera while editing photos`).
- Exact next smallest step: inspect PhotoKit and camera session failure/recovery behavior for testable edge cases; physical iPhone installation/capture/Photos verification remains required.

- Added adjustable crop positioning to the editor. The position control selects horizontal or vertical movement from the source's EXIF-aware aspect ratio, supports centering/reset, clamps movement to valid crop bounds, and rerenders after the slider gesture ends. `FilmRenderer` now accepts a `CropPosition`; changed `FramedLocal/ContentView.swift`, `FramedLocal/FilmRenderer.swift`, and `FramedLocalTests/RendererTests.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (37 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged simulator build-number `invalidDigitCount` diagnostics. No physical device test possible.
- Committed and pushed as `cc9dc5d` (`Add adjustable crop positioning`).
- Exact next smallest step: review the camera/export implementation for remaining code-verifiable edge cases; physical camera, sensor calibration, and PhotoKit behavior still need the iPhone.

- Corrected horizon guidance in `FramedLocal/CompositionAnalysis.swift` and `FramedLocal/ContentView.swift`: gravity is compared against the phone's long axis for the active portrait/landscape orientation; unavailable/face-up gravity produces no tilt reading; the “Level the phone” hint requires 0.45 seconds of continuous tilt above threshold and resets after the phone levels. Added orientation/math and stability unit tests in `FramedLocalTests/GuidanceEngineTests.swift`.
- Verification: iOS 27.1 simulator hosted suite passed (33 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted only simulator build-number `invalidDigitCount` diagnostics. Physical sensor calibration remains pending.
- Committed and pushed as `303fa85` (`Make horizon guidance orientation aware`).
- Exact next smallest step: add user-adjustable crop positioning after aspect selection, with pure geometry and renderer tests; physical sensor/camera/Photos validation still requires the iPhone.

- Made date stamps stable for an editor source: `FrameRenderer` accepts an explicit stamp date, and `ContentView` captures that date when a new capture/import is selected. Re-rendering after changing crop, preset, or frame now keeps the same date. Added deterministic stamp coverage in `FramedLocalTests/RendererTests.swift`; changed `FramedLocal/FrameRenderer.swift` and `FramedLocal/ContentView.swift`.
- Verification: latest iOS 27.1 simulator result bundle reports 31 tests passed, 0 failed; generic unsigned iOS device build passed; `git diff --check` passed. Xcode logged simulator build-number parsing diagnostics (`invalidDigitCount`) but exited successfully. No physical phone connected.
- Committed and pushed as `12052b4` (`Keep editor date stamps stable per image`); code and status are on `origin/main`.
- Exact next smallest step: add automated coverage for source-date metadata / editor date behavior if desired, then prioritize physical iPhone signing, installation, camera capture, and PhotoKit runtime checks as soon as the device is available.

- Added non-destructive center-crop/aspect choices (`Original`, `Square`, `4:3`, `16:9`) to the editor pipeline. `FilmRenderer` crops its decoded CIImage copy before applying a preset; original imported bytes are not changed. Added UI controls and geometry/source-integrity coverage in `FramedLocal/ContentView.swift`, `FramedLocal/FilmRenderer.swift`, and `FramedLocalTests/RendererTests.swift`.
- Verification for this turn: iOS 27.1 simulator hosted suite passed (30 tests, 0 failures); generic unsigned iOS build passed; `git diff --check` passed. Xcode logged only simulator build-number `invalidDigitCount` diagnostics. No physical-device test was possible.
- Committed and pushed as `27a0eb6` (`Add crop aspect options to local editor`); worktree is clean. Exact next step: add focused automated coverage for remaining renderer/editor behavior, then resume phone installation/camera/Photos validation when the iPhone becomes available.

- Fixed a camera-source race in `FramedLocal/ContentView.swift`: the live analysis path pauses during session start/recovery/lens changes, clears old frame/selection state before resuming, and tags Vision work with an analysis generation so late results from a previous camera are discarded. Made the session generation lock-protected and nonisolated for the Sendable queue callbacks.
- Corrected live Vision orientation propagation: analysis receives the current EXIF orientation on startup, recovery, lens switch, and subsequent device rotations, so landscape guidance follows the camera orientation.
- Added `testAnalysisGenerationGateDropsResultsFromPreviousCameraSource()` and removed the new Swift 6 actor-isolation warnings; updated the session-generation test to use an immutable local.
- Verification for this turn: iOS 27.1 simulator hosted tests passed (29 tests, 0 failures); generic unsigned iOS device build passed; `git diff --check` passed. Xcode emitted only simulator SDK/device build-number parsing diagnostics (`invalidDigitCount`), with both commands returning exit code 0. Physical iPhone testing remains unavailable.

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

- The first test compile emitted Swift warning `result of call to 'render(_:preset:cropAspect:cropPosition:)' is unused` in the new cancellation test. Assigned the result to `_`; rerun passed without that warning. No test failures.
- Simulator suite passed 39/39; generic iOS build and `git diff --check` passed. The only remaining Xcode diagnostics are the recurring simulator `invalidDigitCount` metadata messages.

- No code/test failures this turn. Simulator suite passed 38/38, generic device build passed, and `git diff --check` passed; Xcode emitted non-fatal simulator metadata `invalidDigitCount` diagnostics.

- An initial test-file patch targeted nonexistent `FramedLocal/FramedLocalTests/GuidanceEngineTests.swift`; `apply_patch` returned `No such file or directory` and made no changes. Retargeted the patch to repository-root `FramedLocalTests/GuidanceEngineTests.swift`; tests then passed.
- No build/test failures after correcting the path. Simulator suite passed 38/38, generic device build passed, and `git diff --check` passed. Xcode emitted recurring non-fatal simulator metadata `invalidDigitCount` diagnostics.

- No compile or test failures. Simulator suite passed 37/37; generic iOS build and `git diff --check` passed. Xcode emitted the recurring `IDESchemeActionSDKRecord` / `IDESchemeActionDeviceRecord` `invalidDigitCount` simulator metadata diagnostics.

- No code/test failures this turn. Simulator run passed 37/37; generic iOS build and `git diff --check` passed. Xcode emitted the recurring non-fatal simulator build-number `invalidDigitCount` diagnostics.

- First compile failed because public `FilmRenderer.render` accepted internal `CropPosition`, and its default argument referenced an internal `.center`. Made `CropPosition`, its fields/initializer, and `.center` public; the simulator test run then passed.
- No test failures after that fix. Latest simulator run passed 37 tests; generic device build and `git diff --check` passed. Xcode emitted only simulator metadata `invalidDigitCount` diagnostics.

- No code or test failures this turn. Xcode logged `IDESchemeActionSDKRecord` / `IDESchemeActionDeviceRecord` `invalidDigitCount` diagnostics for the installed simulator build metadata; 33 tests and the generic iOS build completed successfully.

- No test failures this turn. Xcode repeated the simulator SDK/device build-number `invalidDigitCount` diagnostics; the 31-test simulator run and generic-device build both completed successfully.

- The first crop geometry test assumed `UIGraphicsImageRenderer` generated a 1x image and expected 320×240 pixels; on the simulator its source fixture is 3x (960×720). The crop output had correct corresponding proportions (960×720, 720×720, 960×720, 960×540). Changed test expectations to derive from actual source pixel dimensions; the full simulator suite then passed (30/30).
- Xcode 27.1 continued to log `IDESchemeActionSDKRecord` / `IDESchemeActionDeviceRecord` `invalidDigitCount` diagnostics for simulator build metadata; simulator tests and generic-device build exited successfully.

- The first test build reported Swift concurrency warnings because a `@Sendable` analysis-resume predicate accessed the MainActor-isolated `sessionGeneration` property. Made its backing reference `nonisolated` and kept synchronization inside the lock-protected `SessionGeneration`; the rerun passed without that warning.
- The existing session-generation unit test used `var` even though the object is now a reference type; changed it to `let` to remove the compiler warning.
- Xcode 27.1 logged `IDESchemeActionSDKRecord` / `IDESchemeActionDeviceRecord` `invalidDigitCount` diagnostics for simulator build numbers; simulator tests and generic-device build completed successfully despite those environment diagnostics.

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

## Follow-up Turn — 2026-10-28 (preview-to-Vision tap coordinates)

- Audit found the tap gesture divided actual preview coordinates by a fixed `640×480` size, even though the displayed preview is portrait and aspect-filled. This could normalize taps incorrectly or outside the expected range.
- `CameraPreview` now handles taps in UIKit and converts layer coordinates through `AVCaptureVideoPreviewLayer.captureDevicePointConverted(fromLayerPoint:)`, which accounts for the preview layer's display geometry. The returned device point is transformed for Vision's orientation and bottom-left normalized coordinate convention.
- Analysis output is explicitly unmirrored so its pixels stay in capture-device coordinates. The visible front preview can still mirror; session analysis remains unrotated and Vision applies the orientation mapping.
- Added `VisionTapPointMapper` tests for up, left, right orientation and clamping out-of-range input. Initial test run failed due exact floating-point equality (`0.19999999999999996` vs `0.2`); changed that assertion to a tolerance. Initial generic build also warned that UIKit tap access was main-actor isolated; marked the gesture callback `@MainActor`, and the rerun emitted no such warning.
- Simulator suite passed 12/12. Generic iOS build succeeded. Only AppIntents metadata extraction warning. `git diff --check` remains to run.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Physical preview conversion, front mirroring, and correct subject selection remain unverified without an iPhone camera.
- Exact next smallest step: run final diff check/review and commit/push, then verify taps on a visible subject in portrait/landscape on the iPhone 12.

## Follow-up Turn — 2026-10-28 (analysis throttle deadlock)

- Current code audit found `VideoAnalysisDelegate` set `analysisPending = true` before calling `CompositionAnalyzer.analyze`. The analyzer silently returned when the 0.14-second throttle rejected a frame and never called completion, leaving the pending flag true forever; later camera frames were then discarded by the app gate.
- Removed the redundant pending flag/lock. `AVCaptureVideoDataOutput.alwaysDiscardsLateVideoFrames` already bounds stale frames, and the dedicated delegate queue serializes frame processing. Analyzer completion now accepts an optional result and explicitly completes with `nil` for throttled frames.
- Extracted `AnalysisRateLimiter` and added a deterministic test verifying fast frames are rejected and analysis resumes once the 0.14-second interval has passed.
- Simulator suite passed 13/13. Generic iOS device build succeeded; only non-fatal AppIntents metadata extraction warning. No camera runtime test available because only simulators are connected.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: review the diff, run `git diff --check`, then commit/push. On physical iPhone, verify guidance continues updating after the first throttled frame.

## Follow-up Turn — 2026-10-28 (empty tap clears previous subject)

- Vision selection audit found `selectSubjectOnQueue` returned early when a tap produced no face/saliency boxes, leaving the previous selected observation and tracking request active. This contradicted the user's new selection intent and could preserve stale subject tracking.
- Added `SubjectSelectionResolver`: prefer a containing box, otherwise select the nearest available box, and return nil when there are no candidates. Empty selection now clears both `selectedObservation` and `trackingRequest` so ordinary auto-detection can resume.
- Added deterministic tests for containing-box preference, nearest-box fallback, and empty candidates.
- Simulator tests passed 14/14. Generic iOS build succeeded. Only non-fatal AppIntents metadata extraction warning. Runtime tracking remains unverified on camera hardware.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: run `git diff --check`, review, then commit/push. Verify tapping blank space clears tracking on iPhone 12.

## Follow-up Turn — 2026-10-28 (bound analysis buffer dimensions)

- Reviewed sharpness and luminance sampling cost. `AVCaptureVideoDataOutput` had a pixel format but no explicit dimension policy; Apple documents that it commonly delivers full active-format frames unless output buffer dimensions are configured automatically.
- Set `analysisOutput.automaticallyConfiguresOutputBufferDimensions = true` so the Vision/metrics stream uses preview-sized buffers while still-photo output remains high-resolution. `alwaysDiscardsLateVideoFrames` remains enabled and Vision remains throttled at ~7 Hz.
- Generic iOS device build succeeded; simulator suite passed 14/14. Only warning was skipped AppIntents metadata extraction. No physical-device buffer dimensions or performance measurements are available yet.
- Changed files: `FramedLocal/ContentView.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- `git diff --check` and current device inventory still need checking before commit. Exact next step: run those checks, commit/push, then inspect delivered pixel buffer dimensions and preview responsiveness on iPhone 12.

## Exact Next Smallest Step

Connect iPhone 12, select the Apple Development team in Xcode, install and launch, then verify front/rear capture and portrait/landscape output followed by add-only Photos permission and album creation/reuse. No physical iPhone currently appears in `xcrun devicectl list devices`.

## Recovery Instruction

Read this file first after context compression. Then inspect `git status`, the latest diff, and only the relevant sections of `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`.

## Follow-up Turn — 2026-10-28 (separate detection and tracking confidence)

- Current audit found `CompositionMetrics.confidence` was populated from the active selected tracker when tracking, otherwise from face/saliency detection. Guidance therefore interpreted the same scalar with different meanings and thresholds.
- Added `SubjectConfidenceSource` to metrics. Detection keeps its existing 0.3 threshold and “find the subject” message; selected tracking has its own 0.5 confidence threshold and “keep the subject in frame” recovery message. The public `GuidanceEngine.update` API remains detection-oriented; an internal overload accepts tracking source.
- Added deterministic tests for low-confidence tracking and detection recovery.
- First simulator test build failed with Swift access-control errors because a public method parameter/default argument exposed an internal enum. Fixed by retaining the public three-argument API and adding an internal source-aware overload.
- Simulator hosted suite passed 16/16. Generic iOS device build succeeded. Simulator logs included Core Image pixel-buffer diagnostics from renderer tests (`CVPixelBufferCreate returned err -6680`) while all renderer cases passed; Xcode also emitted simulator build-version digit warnings and the existing AppIntents metadata extraction warning. No source compile warnings remain.
- Physical tracking behavior and calibration of the 0.5 threshold remain unverified without an iPhone camera.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record the updated matrix result, run `git diff --check`, inspect the final diff, then commit and push. Connect and sign the iPhone 12 to continue physical verification.

## Follow-up Turn — 2026-10-28 (guidance exposure cues and deterministic grain)

- Continued implementation while physical-device testing is unavailable, per user request; current device inventory still lists simulator devices only.
- Added `ExposureGuidance` to use the already-sampled mean brightness, clipped highlights, and clipped shadows. Exposure advice is evaluated after subject confidence, sharpness, and framing checks; dark scenes with substantial clipped shadows can now suggest adding light, while highlight clipping can suggest lowering exposure.
- Replaced `CIFilter.randomGenerator()` in Night Grain with a fixed-seed local noise bitmap so the same input and preset produce stable output across preview/export. Added byte-for-byte repeat-render coverage.
- Added unit tests for exposure decisions and deterministic grain. Simulator suite passed 18/18. Generic iOS device build passed after the exposure change; rerun after deterministic-grain update is still required.
- First confidence-separation build earlier in this task failed because public API access control exposed an internal enum; fixed by preserving the public detection-only overload and using an internal source-aware overload. No other feature-build errors this turn.
- Simulator renderer output still logs `CVPixelBufferCreate returned err -6680` from Core Image; all renderer tests pass. Xcode emits simulator build-version digit warnings; AppIntents metadata extraction warning is non-fatal.
- Current blocker remains physical iPhone connectivity/signing/runtime validation, which user will handle later. No manual testing requested now.
- Changed files in this follow-up: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/FilmRenderer.swift`, `FramedLocal/PhotoLibraryService.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: update the matrix to 18 passing tests, run generic-device build and `git diff --check`, then continue code-level camera capture, authorization, cancellation, and rendering robustness review; physical-device checks remain for when the user can test.

- Additional export audit in the same follow-up found the combined PhotoKit transaction's fallback condition checked the temporary `savedInAlbum` flag after removing it, and also depended on a persistent “album creation attempted” value that could trigger an unnecessary retry on future saves. The failure handler now snapshots the per-save flag before clearing it and retries asset-only saving only if an album change was part of the failed transaction. If the app already knows the album cannot be fetched under add-only access, it saves once directly to Recents. This avoids duplicate asset creation on the unavailable-album path.
- Re-ran hosted simulator tests after the export correction: 18 passed, 0 failed. Generic iOS device build passed after deterministic grain and exposure guidance. `git diff --check` passed. Existing benign simulator/Core Image and Xcode build-version diagnostics remain.

## Follow-up Turn — 2026-10-28 (Night Grain blend verification)

- Re-audited the deterministic grain patch and found its first color-matrix version set noise alpha to zero, which could make the soft-light overlay transparent. Corrected the matrix to keep full alpha and map seeded grayscale noise around neutral gray; translated the generated bitmap to the input image extent before cropping.
- Extended the Night Grain test to prove both repeatability (same bytes for repeated renders) and a changed result relative to Natural.
- Also implemented this turn: confidence-source-aware tracking recovery (previous commit), exposure advice using shadow/highlight clipping, and the PhotoKit fallback retry fix (retry asset-only only if the failed transaction attempted an album mutation).
- Simulator suite passed 18/18 after the grain correction. Generic iOS device build passed. `git diff --check` passed. No feature build/test failures during this correction. Existing Xcode simulator-version diagnostics remain non-fatal.
- Physical iPhone 12 remains unavailable in the current device list; camera runtime, permission prompts, orientation, PhotoKit writes, and live guidance still require user device testing later.
- Changed files in this turn: `FramedLocal/FilmRenderer.swift`, `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/PhotoLibraryService.swift`, `FramedLocalTests/RendererTests.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: review/commit/push the verified local work; then continue source-level interruption, cancellation, and capture/export recovery review until physical device testing can resume.

## Follow-up Turn — 2026-10-28 (optional guidance haptics)

- Added a persisted camera-screen toggle for guidance haptics (`FramedLocal.guidanceHapticsEnabled`); haptics default on and can be silenced without hiding visual guidance. The toggle has an off-state slash indicator and accessible on/off value.
- Extracted `GuidanceHaptics.shouldTrigger` and added tests proving haptics only fire when entering “Hold steady,” do not repeat while the message stays stable, and respect the off setting.
- Simulator hosted tests passed 19/19. Generic iOS device build succeeded. `git diff --check` passed. Existing simulator Core Image pixel-buffer and Xcode build-version diagnostics remain non-fatal.
- No manual device validation was attempted, per user preference. The physical iPhone is still needed later for end-to-end camera, haptic, orientation, and Photos checks.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocal/CompositionAnalysis.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 19 passing tests and review/push this change; continue local review of session lifecycle and interrupted capture behavior while physical testing is deferred.

## Follow-up Turn — 2026-10-28 (camera lifecycle stale callback guard)

- Source audit found a startup/background race: `stop()` can enqueue session shutdown while configuration/startup is already queued, then an older MainActor completion could publish `isSessionRunning = true` after stop. A quick restart made callback ordering even harder to reason about.
- Added `SessionGeneration`. Starting the camera captures the current generation; stopping advances it. Startup success and failure callbacks now update UI state only if their generation is still current, so an old callback cannot overwrite a newer lifecycle state.
- Added a regression test proving stop/restart generations invalidate earlier startup callbacks.
- Simulator hosted tests passed 20/20. Generic iOS device build succeeded. `git diff --check` passed. Existing benign Xcode simulator build-version and renderer Core Image diagnostics remain.
- No physical-device checks were attempted. Interruption/runtime-error notifications and actual background/foreground camera behavior still need validation on the iPhone when available.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 20 passing tests, commit/push the lifecycle guard, then add AVFoundation interruption/runtime-error recovery handling with deterministic state tests before physical verification.

## Follow-up Turn — 2026-10-28 (AVFoundation interruption and runtime-error recovery)

- Added observers for `AVCaptureSession.wasInterruptedNotification`, `interruptionEndedNotification`, and `runtimeErrorNotification`.
- On interruption, the UI explains that the camera is temporarily unavailable while preserving the user's intent to run. On interruption end, the session queue attempts to resume and the UI clears the message only after checking `session.isRunning`.
- On `AVError.mediaServicesWereReset`, the app attempts one automatic restart. Other runtime errors stop the desired-running state, show the underlying error, and expose the existing Retry camera action.
- Recovery work uses the session serial queue and `SessionGeneration`, so stop/background actions invalidate stale recovery callbacks. Added pure policy tests for ignored events after stop, automatic resume after interruption/reset, and retry on other runtime errors.
- Simulator hosted tests passed 21/21. Generic iOS device build succeeded. `git diff --check` passed. Existing benign Xcode simulator-version and Core Image test diagnostics remain.
- Physical interruption behavior and media-services reset cannot be induced/verified on the current simulator reliably; test on iPhone remains pending.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 21 passing tests and push; next audit should cover still-photo capture cancellation/failure completion and ensure UI state recovers if AVFoundation never delivers photo data.

## Follow-up Turn — 2026-10-28 (terminal still-capture completion)

- Capture-path audit found `PhotoCaptureDelegate` completed UI state from `didFinishProcessingPhoto` only. It did not consume AVFoundation's terminal `didFinishCaptureFor` callback, so capture-level errors or a missing processing callback could leave capture completion ambiguous and delay clearing `isCapturing`.
- Added a lock-protected delegate result accumulator and made `didFinishCaptureFor` the single completion point. Terminal capture errors take precedence over a partial processing result; absent photo data becomes a clear failure. The existing completion clears `isCapturing` on the MainActor and releases the retained delegate from the session queue.
- Added resolver tests for capture-level error precedence, missing photo data, and successful JPEG completion.
- Simulator hosted suite passed 24/24. Generic iOS device build succeeded. `git diff --check` passed. Existing benign simulator Core Image and Xcode build-version diagnostics remain.
- Physical shutter/capture callback behavior still needs confirmation on an iPhone; no manual test was run this turn.
- Changed files: `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 24 passing tests and push; then review Photos export cancellation and capture-state retention while the user continues deferring hands-on device checks.

## Follow-up Turn — 2026-10-28 (PhotoKit transaction result integrity)

- Photos export audit found that a nil `placeholderForCreatedAsset` caused an early return from the PhotoKit changes block. If PhotoKit then completed the empty transaction successfully, the service could tell the UI the photo was saved even though no asset had been created.
- Replaced per-save temporary `UserDefaults` flags with `PhotoSaveTransactionState`, a lock-protected sendable result shared by the changes and completion handlers. It separately records asset creation and album mutation. A successful transaction must confirm an asset placeholder; failed album mutations trigger asset-only fallback, while failed asset-only writes do not retry and risk duplicates.
- Added a test for transaction-state snapshots that distinguish asset creation from album mutation.
- Simulator hosted tests passed 25/25. Generic iOS device build succeeded. `git diff --check` passed. Existing benign simulator Core Image and Xcode build-version diagnostics remain.
- Physical PhotoKit transaction and add-only album behavior still need on-device verification; no manual test was performed.
- Changed files: `FramedLocal/PhotoLibraryService.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 25 passing tests and push this export fix; continue inspecting import cancellation and local temp-file lifecycle, then verify PhotoKit behavior on the iPhone when the user is ready.

## Follow-up Turn — 2026-10-28 (decode rendered preview off the UI actor)

- Import/cancellation audit did not find a confirmed temporary-file leak: the copied picker file is removed by `defer` after reading. The adjacent preview pipeline did decode the rendered JPEG with `UIImage(data:)` after actor awaits inside a MainActor-inherited `Task`, which could decompress a ~2,400-pixel preview on the UI actor.
- Added `PreviewImageDecoder` actor using ImageIO to create the `CGImage` off the main actor; the UI now only wraps the decoded image in `UIImage` and updates state on MainActor. Added a decoded-pixel-dimensions test.
- First test run reported two assertions failing because `UIGraphicsImageRenderer(size: 240x160)` creates a 720x480 pixel JPEG on this 3x simulator. Changed the test to compare against actual source JPEG pixel dimensions. Full rerun passed 26/26 (verified from `.xcresult`).
- The first test process took 159 seconds to return because Xcode's post-test `simctl diagnose` hung; the test worker log showed it had finished. Stopped only the stalled diagnostics subprocess after the run had completed. Rerun with `xcodebuild -quiet test` exited 0 in 7 seconds; result summary: 26 passed, 0 failed, 0 skipped. Xcode emitted benign simulator build-version digit-count warnings.
- Generic iOS device build succeeded with the preview decoder implementation; `git diff --check` passed.
- Physical preview decode latency and picker cancellation remain device/runtime checks. No manual testing was performed.
- Changed files: `FramedLocal/FrameRenderer.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/RendererTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 26 passing tests and push; then continue lifecycle review for interruptions during Photos save and exercise the app on the iPhone when available.

## Follow-up Turn — 2026-10-28 (Photos save destination status)

- Audited save lifetime against scene/background and view disappearance. `saveLatestCapture()` launches an unstructured MainActor task owned by the camera controller; `onDisappear` and background handling stop the camera and cancel import/render work, but do not cancel the Photos save. The PhotoKit actor awaits transaction completion while retaining the JPEG temporary file until the callback/fallback finishes, then removes it with `defer`. Save state is published by the shared controller after completion.
- Found the fallback success message said only “Saved to Photos,” while the export contract and test matrix promise the destination. Added `PhotoSaveDestination.statusMessage`; album saves report “Saved to Photos · Framed album,” and fallback saves report “Saved to Photos Recents.” Added assertions for both messages.
- Simulator hosted suite passed 27/27 (verified with `.xcresult`, no failures/skips). Generic iOS device build succeeded. `git diff --check` passed. Xcode's benign simulator build-version digit-count warnings remain.
- No manual PhotoKit/background test was run; physical-device validation remains outstanding.
- Changed files: `FramedLocal/PhotoLibraryService.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: update matrix to 27 passing tests and push the destination copy; continue reviewing local rendering/save lifecycle, then complete real Photos transaction and background tests on iPhone when user is available.

## Follow-up Turn — 2026-10-28 (tap-to-track feedback and selection lifetime)

- Vision tap-selection audit found the UI set “Finding selected subject…” but never replaced it after analysis completed. A tap with no current pixel buffer or no matching face/saliency candidate could leave that message indefinitely.
- `CompositionAnalyzer.selectSubject` now returns whether it created a tracking request. `VideoAnalysisDelegate` returns that result on its analysis queue; the camera controller reports “Tracking selected subject” or “No subject found — try tapping closer.” Selection callbacks carry a generation token so delayed feedback from a previous tap or camera cannot overwrite newer state.
- Stopping the session or switching lenses invalidates pending selection feedback and clears tracking selection on the serial analysis path, preventing a rear-camera subject box from carrying into the front camera or a resumed session.
- First build failed with `ContentView.swift:972:1: error: Extraneous '}' at top level` from an extra brace in the delegate edit. Removed it and reran.
- Simulator hosted tests passed 28/28 (verified through `.xcresult`, no failures or skips). Generic iOS device build succeeded. `git diff --check` passed. Xcode emitted existing simulator build-version digit warnings.
- Real camera tap selection, no-subject feedback, and lens-switch clearing still require physical-device validation.
- Changed files: `FramedLocal/CompositionAnalysis.swift`, `FramedLocal/ContentView.swift`, `FramedLocalTests/GuidanceEngineTests.swift`, `docs/TEST_MATRIX.md`, `docs/PROJECT_STATUS.md`.
- Exact next smallest step: record 28 passing tests and push; then continue review for analysis frames arriving during lens reconfiguration and verify tap selection on the iPhone when available.

## Follow-up Turn — 2026-10-28 (attempted iPhone 12 installation)

- User asked to install FramedLocal on the connected iPhone 12. Device inventory recognizes it as `Hello`, UDID `00008101-001C15880128001E`, model iPhone 12 (`iPhone13,2`), wired and paired. Device details report iOS `27.0` build `24A5380h`, Developer Mode enabled, and pairing type `manualPairing`; the earlier missing “Trust This Computer” alert is consistent with it already being paired.
- First signed device build failed before compilation with Xcode error: `Timed out waiting for all destinations matching the provided destination specifier to become available`; destination detail: `Hello needs to be unlocked to enable development services Please unlock the device.` The same details reported that the developer disk image could not be mounted.
- A generic iOS build with signing disabled completed successfully (`CODE_SIGNING_ALLOWED=NO`), confirming source compilation but producing an app that cannot be installed on a device. Retrying automatic signing failed with the exact errors `No Account for Team "GKRCRY6AUK". Add a new account in Accounts settings or verify that your accounts have valid credentials.` and `No profiles for 'local.mithundb.framed' were found`.
- App was not installed or launched. Physical capture and Photos behavior remain unverified. Current blockers: iPhone must be unlocked and remain unlocked during Xcode development-service setup; Xcode needs a valid Apple developer account/team session for `GKRCRY6AUK` to provision `local.mithundb.framed`. Once the device is unlocked and Xcode account is available, rerun the signed device build, install with `devicectl`, then launch. If the DDI warning remains after unlock, inspect Xcode/device support and retry.
- Changed files: `docs/PROJECT_STATUS.md` only. Builds run: generic unsigned iOS build passed; signed device build blocked by locked device; auto-signing build blocked by missing Xcode account/profile. No tests run.
- Exact next smallest step: user unlocks the iPhone and leaves it connected/unlocked; ensure Xcode Settings → Accounts has the Apple ID/team used for development. Then retry the device-target build and installation. No phone trust prompt is needed unless macOS explicitly presents one later.

## Follow-up Turn — 2026-10-28 (Personal Team confirmed; signing retry)

- User confirmed Xcode → Settings → Apple Account shows their Personal Team. Retried the signed device build using team ID `GKRCRY6AUK`; device destination is now reachable, so the previous unlock/destination timeout no longer appears.
- Signing still fails before app build with: `No Account for Team "GKRCRY6AUK". Add a new account in Accounts settings or verify that your accounts have valid credentials.` and `No profiles for 'local.mithundb.framed' were found: Xcode couldn't find any iOS App Development provisioning profiles matching 'local.mithundb.framed'.`
- Verified `xcode-select` points to `/Applications/Xcode.app/Contents/Developer`, Xcode reports 27.1 (27A9275), and the login keychain contains one valid Apple Development identity for `mithun.deepak.baskaran@gmail.com` / `GKRCRY6AUK`. There are no local provisioning profiles. Thus the certificate exists and the Personal Team is visible in the GUI, but command-line automatic signing cannot obtain/use the account credentials to create the app profile. App remains uninstalled.
- Changed files: `docs/PROJECT_STATUS.md` only. Build attempt: signed physical-device build failed at provisioning; no tests run.
- Exact next smallest step: in the Xcode project, open target **FramedLocal → Signing & Capabilities**, make sure **Automatically manage signing** is checked and **Team** is the confirmed Personal Team; then trigger one build from Xcode so it can refresh/create the Personal Team provisioning profile. After that, retry `xcodebuild`/device install. If Xcode itself reports account authentication or agreement errors, resolve those in the Apple Account panel first.

## Follow-up Turn — 2026-10-28 (reproduced iPhone launch crash)

- User reported the installed app immediately crashes on launch. Confirmed the iPhone 12 is connected and paired; `devicectl` lists `Framed` (`local.mithundb.framed`, version 1.0, build 1) as installed. Reproduced launch with `xcrun devicectl device process launch --console --terminate-existing --device 00008101-001C15880128001E local.mithundb.framed`; the app terminates immediately with signal 5 (`SIGTRAP`). This confirms a process crash, but the CLI output does not expose the exception/backtrace.
- No matching `.ips` crash report was synced to the Mac crash-report folders. Source startup path requests camera access and starts the capture session; do not guess at the cause until the crash log identifies the exception and crashing thread.
- Git status shows `FramedLocal.xcodeproj/project.pbxproj` modified externally by Xcode/user signing setup; its current Personal Team setting is `BK7H8FHGLF`. Preserve that uncommitted change. `docs/PROJECT_STATUS.md` is also modified by these context-recovery updates.
- Build/test status for this diagnostic turn: confirmed the app is installed; reproduced launch termination (signal 5); no tests run; source was not changed.
- Exact next smallest step: retrieve and inspect the newest `FramedLocal`/`Framed` `.ips` crash report (iPhone Settings → Privacy & Security → Analytics & Improvements → Analytics Data, or Xcode → Window → Devices and Simulators → select iPhone → View Device Logs). The key fields are `Exception Type`, `Termination Reason`, `Triggered by Thread`, and `Last Exception Backtrace`; attach the `.ips` file or paste those fields. Then fix the specific startup crash, rebuild, reinstall, and relaunch.

## Follow-up Turn — 2026-10-28 (fixed Core Motion startup crash)

- Inspected `FramedLocal-2026-10-28-220201.ips`. The fatal exception is `EXC_BREAKPOINT` / `SIGTRAP`; the triggered thread is an `NSOperationQueue` used by Core Motion. Its backtrace is `_dispatch_assert_queue_fail` → `dispatch_assert_queue` → `_swift_task_checkIsolatedSwift` → `closure #2 in CameraController.startMotionUpdates()`. This identifies a Swift actor-isolation precondition: Core Motion invoked a callback on its operation queue, while the closure had inherited `MainActor` isolation from the method that created it. A separate Vision/CoreML stack was in flight but is not the report's triggered/faulting thread.
- Fixed the callback by creating it from a `nonisolated` helper and hopping to `MainActor` only for generation checking and UI state updates.
- Xcode's project file now has the user's configured Personal Team `BK7H8FHGLF`; earlier signing retries forced a different team ID from the existing local certificate. Preserved the Xcode-generated/user project-file edits and built using project settings without a team override.
- Signed physical-device build succeeded. Installed build `1.0 (1)` to iPhone 12 with `devicectl`; launch succeeded, and process `FramedLocal` (PID 23347) remained present in a subsequent device process snapshot. This verifies launch survival past the previous immediate crash; camera interaction and capture behavior still need user testing.
- Changed files this turn: `FramedLocal/ContentView.swift`, `docs/PROJECT_STATUS.md`. `FramedLocal.xcodeproj/project.pbxproj` remains an external Xcode/user change and is intentionally preserved. Device build passed; app installed and remained running; no tests run; no source compilation errors.
- Exact next smallest step: user confirms the app remains open/visible on the iPhone, then when convenient manually check first camera permission/preview and capture. If another crash occurs, collect its newer `.ips`; the previous SIGTRAP was fixed and no longer reproduces in the device launch check.

## Follow-up Turn — 2026-10-28 (remote camera visibility and Framed feature audit)

- User confirmed Device Hub suppresses the live camera view in its screen display. A remote screenshot of Framed and a remotely opened Apple Camera both showed black video with the camera-use indicator active, so those screenshots are not valid evidence of a broken physical preview. The earlier Framed crash report also shows live sample-buffer analysis reaching Vision. User reports composition features remain incomplete; physical viewfinder confirmation is still needed when device control reconnects.
- Public feature audit (App Store listing and shootframed.com): Framed advertises scene scan that recommends position/zoom/exposure/angle, user-defined framing, resizable/movable target frames, live subject tracking, and a shutter cue when aligned; then film looks/editor/frames after capture. Treat as feature reference only—implement original FramedLocal behavior and visuals, never copy code, branding, assets, or exact recipes.
- Repository audit confirms current app has face/saliency analysis, guidance messages, a tap-select Vision tracking path, preset/frame editing and Photos export. However, analysis metrics are only used to update text: subject rectangles are not exposed/drawn in the live preview; no composition target/overlay is provided; no zoom recommendation or camera zoom control exists; shutter availability is based on session/capture state, not framing readiness. These explain why “Hold steady” appears without an outline or active framing help.
- Ran simulator tests after the Core Motion crash fix. First command failed because destination `name=iPhone 17 Pro` implicitly requested `OS=latest`, while the available iPhone 17 Pro runtime is iOS 26.2: `Unable to find a device matching the provided destination specifier`. Retried using simulator ID `92428003-055D-4B31-8EBD-10C829E87D36`; result passed 54/54, 0 failures, 0 skipped. Signed iPhone build/install/launch had already succeeded before this test run.
- Device became unavailable to CoreDevice while returning from native Camera to Framed. Exact launch error: `The device is not able to fulfill the requested usage assertion requirements (com.apple.dt.CoreDeviceError error 4016)`; current `devicectl list devices` reports iPhone 12 unavailable. No new crash was observed after the Core Motion fix before disconnect.
- Attempt to create a separate Goal failed because this conversation already has an unfinished “Build FramedLocal” goal. Continue the user's expanded device-validation request under that existing goal.
- Changed files so far in this active diagnosis: `FramedLocal/ContentView.swift` (Core Motion crash fix), `docs/PROJECT_STATUS.md`; preserve the existing external Xcode change in `FramedLocal.xcodeproj/project.pbxproj`. Simulator tests passed 54/54; signed device build passed; app launch stayed alive; physical screenshot is privacy-masked/inconclusive.
- Exact next smallest step: implement a visible, original live composition overlay from the existing Vision subject bounds, along with a user-controlled zoom recommendation/apply path and a clear “aligned” shutter cue. Add unit tests for pure guidance/zoom calculations, build and run simulator tests, then reconnect the iPhone for frame/overlay positioning and camera-switch verification.
