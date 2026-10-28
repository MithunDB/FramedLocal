# Framed-Like Local iPhone Camera: Project Initialization

## Goal

Upstream project repository: [MithunDB/FramedLocal](https://github.com/MithunDB/FramedLocal). Keep this project private and use the repository as the source-controlled workspace for the local iOS app.

Build a private, local iPhone camera app in Xcode that recreates the general functionality of the Framed photo app without copying its source code, branding, assets, filter names, or private implementation.

The app should:

- show a live camera preview;
- guide composition in real time;
- detect and track a selected subject where possible;
- capture a high-quality still image;
- apply original film-inspired color presets;
- add original borders, paper-style layouts, and date stamps;
- let the user preview the result;
- save the final rendered image as a new asset in the iPhone Photos library;
- remain useful offline after the app is installed.

The first version should use deterministic computer vision and local image processing. Do not add a cloud AI service or external model until the non-AI camera workflow is reliable.

## Important Scope Boundary

“Best frame” is a recommendation, not an objective truth. The app must use language such as “Try moving left” or “Suggested framing,” never claim that a composition is universally best, and always let the user capture anyway.

This project is a personal side project. It is not intended for sale or public distribution at this stage. The final local deliverable is an Xcode-built app that can be installed on the developer’s iPhone from the Mac.

## Current Development Target

Use these as the initial project assumptions:

- Test device: iPhone 12
- Test OS: iOS 27
- Development Mac: MacBook Pro with base M5 and 16 GB memory
- Development OS: macOS 27 Golden Gate 27.0.1
- Xcode: 27.1
- Temporary product name: `Framed`
- Product name must remain configurable so it can be changed later without rewriting the architecture.
- Camera support: front and rear cameras
- Output: JPEG first, with the capture pipeline designed so HEIF can be added later
- Orientation: portrait and landscape
- Initial visual direction: cinematic, with several additional original presets
- Guidance UI: minimal text/reticle/haptic feedback, shown only when useful
- Export: create a dedicated `Framed` album when possible
- Initial Photos scope: save newly captured results only

The bundle identifier is the app’s unique technical identity, separate from the display name. Use a private reverse-DNS identifier such as `local.mithundb.framed` for development. Keep it in one project setting so the display name can later change without changing storage architecture.

## Source References

Use Apple’s current documentation as the implementation reference:

- [AVCam camera sample](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)
- [AVCapturePhotoOutput](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [Saving captured photos](https://developer.apple.com/documentation/avfoundation/saving-captured-photos)
- [Vision face tracking](https://developer.apple.com/documentation/vision/tracking-the-user-s-face-in-real-time)
- [PHPhotoLibrary](https://developer.apple.com/documentation/photos/phphotolibrary)
- [Core Image](https://developer.apple.com/documentation/coreimage)
- [Core Image filter processing](https://developer.apple.com/documentation/coreimage/processing-an-image-using-built-in-filters)

The Framed App Store listing describes composition scanning, subject tracking, film looks, and frames. Use it only as a feature reference; do not copy its visual identity or implementation. ([Framed App Store listing](https://apps.apple.com/us/app/framed-take-aesthetic-photos/id6761207600))

## Technology Decision

Use a native iOS application:

- Swift 6-compatible Swift code, following the installed Xcode version.
- SwiftUI for screens and controls.
- AVFoundation for camera sessions, preview frames, and still capture.
- Vision for face, rectangle, saliency, horizon-related, and tracking signals.
- Core Image for color effects, compositing, scaling, grain, and vignette.
- Metal only if a custom GPU shader is needed after Core Image is insufficient.
- Photos/PhotoKit for creating new assets and an optional app album.
- Core Motion only if device attitude data improves the horizon hint.
- No network dependency in the initial release.

Do not implement the core camera in a JavaScript web view. A React Native or Capacitor UI could call native modules, but it would add unnecessary bridge complexity for camera frames, Vision observations, and PhotoKit permissions. Native Swift is the lower-risk choice.

## Repository And Project Setup

Create a new Xcode iOS App project rather than modifying another app unless the user explicitly supplies an existing repository.

Suggested project settings:

- Product name: `FramedLocal`
- Bundle identifier: a private reverse-DNS identifier such as `local.mithundb.framedlocal`
- Interface: SwiftUI
- Language: Swift
- Minimum iOS version: choose the lowest version supported by the installed Xcode and required Vision APIs; document the choice in `PROJECT_STATUS.md`.
- Device family: iPhone initially
- Orientation: portrait and landscape if the UI supports both
- Deployment: run on a physical iPhone from Xcode using the developer’s Apple ID/team

Required Info.plist usage descriptions:

- `NSCameraUsageDescription`: explain that the app needs the camera to preview and capture photos.
- `NSPhotoLibraryAddUsageDescription`: explain that the app saves edited photos as new items in Photos.
- Do not request full photo-library read access unless importing existing photos is implemented.

## Required Project Memory Files

Create and maintain these files from the first commit:

- `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`: stable architecture, feature plan, guardrails, and acceptance criteria.
- `docs/PROJECT_STATUS.md`: short living state for context recovery.
- `docs/DECISIONS.md`: brief record of decisions that should not be reconsidered casually.
- `docs/TEST_MATRIX.md`: device, lighting, scene, and operation test cases.

The Codex project must read `PROJECT_STATUS.md` first after context compression. It should then inspect `git status`, the latest diff, and only the relevant sections of this document.

## Suggested Directory Layout

Adapt this to the generated Xcode project; do not duplicate existing modules.

```text
FramedLocal/
  App/
    FramedLocalApp.swift
    AppState.swift
  Camera/
    CameraSession.swift
    CameraPreview.swift
    PhotoCaptureService.swift
    CameraAuthorization.swift
    CameraOrientation.swift
  Vision/
    VisionPipeline.swift
    DetectionResult.swift
    SubjectDetector.swift
    SubjectTracker.swift
    CompositionAnalyzer.swift
    GuidanceEngine.swift
  Editing/
    FilmPreset.swift
    FilmRenderer.swift
    FrameRenderer.swift
    ImageExportService.swift
  Photos/
    PhotoLibraryService.swift
    AlbumService.swift
  UI/
    CameraView.swift
    GuidanceOverlay.swift
    CaptureButton.swift
    PresetPicker.swift
    ResultPreviewView.swift
    PermissionView.swift
    SettingsView.swift
  Support/
    AppLogger.swift
    AppError.swift
    PerformanceMonitor.swift
Tests/
  CameraSessionTests.swift
  CompositionAnalyzerTests.swift
  GuidanceEngineTests.swift
  FilmRendererTests.swift
  FrameRendererTests.swift
  PhotoLibraryServiceTests.swift
docs/
  FRAMED_LOCAL_IOS_PROJECT_INIT.md
  PROJECT_STATUS.md
  DECISIONS.md
  TEST_MATRIX.md
```

## Architecture

Keep the camera, analysis, rendering, storage, and UI separate:

```text
AVCaptureSession
  -> preview stream
  -> low-resolution analysis stream
  -> AVCapturePhotoOutput still capture

analysis stream
  -> Vision requests
  -> DetectionResult
  -> CompositionAnalyzer
  -> GuidanceEngine
  -> GuidanceOverlay

still photo
  -> FilmRenderer
  -> FrameRenderer
  -> ResultPreviewView
  -> PhotoLibraryService
```

Never run Vision analysis or full-resolution rendering synchronously on the main thread. The camera preview must remain responsive.

## Feature Plan

### Phase 0: Audit and baseline

1. Create the Xcode project.
2. Build the untouched template for a simulator.
3. Connect a physical iPhone and run the template.
4. Create all project memory files.
5. Record Xcode version, Swift version, iOS version, device model, and signing team.
6. Confirm the app launches without camera or Photos permissions yet.

Acceptance criteria:

- The template builds for simulator and physical iPhone.
- `PROJECT_STATUS.md` identifies the exact next task.
- No feature work begins before the deployment baseline is recorded.

### Phase 1: Camera preview and still capture

Implement `CameraSession` as an actor or dedicated serial-queue owner. Configure:

1. Request camera permission before starting the session.
2. Select the rear wide-angle camera when available.
3. Create an `AVCaptureDeviceInput`.
4. Add an `AVCapturePhotoOutput`.
5. Add an `AVCaptureVideoDataOutput` for analysis frames.
6. Use an `AVCaptureVideoPreviewLayer` through a SwiftUI wrapper or a carefully controlled preview view.
7. Set the session preset appropriate for photo capture.
8. Configure orientation and mirroring explicitly.
9. Capture with `AVCapturePhotoSettings`.
10. Receive the result through `AVCapturePhotoCaptureDelegate`.
11. Store the captured JPEG/HEIF data in a temporary local URL.

Pseudocode:

```text
startCamera():
    authorize camera
    configure session on camera queue
    add rear camera input
    add photo output
    add video data output with limited analysis format
    start session

capture():
    settings = photo settings for high-quality still
    photoOutput.capturePhoto(with: settings, delegate: captureDelegate)

onPhotoFinished(photo):
    data = photo.fileDataRepresentation()
    write data to temporary file
    publish captured image to UI
```

Acceptance criteria:

- Preview appears within a reasonable time.
- Capture works in portrait and landscape.
- The captured output has the expected orientation and resolution.
- Camera denial produces a useful permission screen instead of a crash.

### Phase 2: Local PhotoKit export

Implement `PhotoLibraryService` with add-only permission. Prefer saving a new rendered file rather than modifying an existing asset.

```text
requestAddOnlyPermission()
render final image to temporary JPEG or HEIF URL
PHPhotoLibrary.performChanges:
    PHAssetCreationRequest.creationRequestForAssetFromImage(atFileURL: url)
optionally create/find FramedLocal album
optionally add placeholder to album
show success/failure state
```

Use the file URL path when preserving metadata matters. Keep the original captured file and final framed file separate until the user confirms saving.

Acceptance criteria:

- User can save a result into Photos.
- The app requests only add permission for the initial release.
- Save failures are surfaced clearly.
- The original camera capture remains available if rendering fails.

### Phase 2B: Optional existing-photo editor

This is feasible, but it is separate from capture-only mode. Add it after new capture and export are stable.

Implement a Photos-library picker first rather than requesting full-library access. The user can select existing photos, open them in the same editor, apply the same film presets and frame layouts, preview the result, and export a new copy.

The editor should support:

- import from the system Photos picker;
- crop and aspect-ratio selection;
- cinematic and other local presets;
- border, paper, and date-stamp rendering;
- before/after preview;
- export as a new Photos asset;
- optional non-destructive edit metadata if the project later supports reopening edits.

Do not modify the original asset in the first implementation. A future edit mode could use `PHContentEditingOutput`, but a new rendered asset is safer for the initial release.

Acceptance criteria:

- User can select an existing photo without granting unrestricted library access.
- The same renderer used for newly captured photos produces the edited result.
- Original Photos assets remain unchanged.
- Export works to the dedicated `Framed` album.

### Phase 3: Film presets and frames

Create an original preset model:

```swift
struct FilmPreset: Identifiable, Sendable {
    let id: String
    let displayName: String
    let exposure: Float
    let contrast: Float
    let saturation: Float
    let temperature: Float
    let tint: Float
    let grain: Float
    let vignette: Float
}
```

Render each preset using a reusable `CIContext` and a filter chain. Start with:

- exposure adjustment
- temperature/tint
- contrast and saturation
- color curve or color matrix
- subtle grain
- subtle vignette

Do not call presets “Kodak,” “Fuji,” or other trademarked film stock names. Use original names such as `Warm Print`, `Soft Mono`, `Faded Color`, and `Night Grain`.

Frame rendering should be deterministic:

```text
canvas size = selected aspect ratio
draw background color or paper texture
draw photo using chosen fit mode
draw border and optional shadow
draw date stamp if enabled
export flattened image
```

Acceptance criteria:

- Preset preview updates without blocking the camera UI.
- Rendered output matches the preview closely.
- All effects are applied to a copy.
- Frame layout handles portrait and landscape images.

### Phase 4: Basic composition analysis

Do not start with a black-box “best photo” score. Start with explainable signals.

Analysis signals:

- dominant subject bounding box
- face bounding boxes and landmarks when available
- horizon or strong horizontal-line estimate
- brightness and highlight/shadow clipping
- blur/sharpness estimate
- subject headroom and edge collisions
- camera roll/pitch estimate where reliable
- optional saliency map

Use lower-resolution frames for analysis, for example 640 px on the long side. Throttle analysis to a controlled rate, such as 5-10 frames per second, and discard stale frames.

Example `CompositionMetrics`:

```swift
struct CompositionMetrics: Sendable {
    var subjectRect: CGRect?
    var faceRects: [CGRect]
    var horizonAngle: Double?
    var brightness: Double
    var clippedHighlightRatio: Double
    var clippedShadowRatio: Double
    var sharpness: Double
    var subjectEdgeDistance: EdgeDistances?
    var confidence: Double
}
```

### Phase 5: Guidance engine

Turn metrics into one short, stable suggestion. Do not display five competing instructions.

```text
if confidence is low:
    guidance = “Move slowly so I can find the subject”
else if sharpness is low:
    guidance = “Hold steady”
else if horizonAngle exceeds tolerance:
    guidance = “Level the phone”
else if subject is too close to an edge:
    guidance = “Move slightly toward the center”
else if subject is too small:
    guidance = “Move a little closer”
else if highlights are clipped:
    guidance = “Lower exposure slightly”
else:
    guidance = “Looks balanced”
```

Add hysteresis and debouncing so the message does not flicker:

- require a condition to remain true for a short interval;
- keep the current instruction until the replacement is materially better;
- do not change more often than a defined cooldown;
- ignore low-confidence observations.

Acceptance criteria:

- Guidance is understandable without a manual.
- Guidance does not flicker while the phone is held still.
- A low-confidence scene never produces overconfident advice.
- The shutter remains usable regardless of guidance.

### Phase 6: Subject detection and tracking

Implement in stages:

1. Face detection for portraits.
2. Rectangle or salient-object detection for general scenes.
3. User tap-to-select subject.
4. Track the selected observation with `VNSequenceRequestHandler` and `VNTrackObjectRequest`.
5. Re-detect when tracking confidence falls below a threshold.
6. Stop tracking after a timeout or when the subject leaves the frame.

Run Vision on a background queue. Publish only the newest result to the main actor.

Pseudocode:

```text
onAnalysisFrame(pixelBuffer):
    if selectedSubject exists and tracking is healthy:
        perform tracking request
    else if detection cooldown elapsed:
        perform face/object/saliency detection

    observation = best confident result
    metrics = analyzer.metrics(for: observation, frame: pixelBuffer)
    guidance = guidanceEngine.message(for: metrics)
    publish latest guidance
```

Acceptance criteria:

- Face tracking works in ordinary indoor lighting.
- Tracking visibly degrades to “Searching” rather than jumping unpredictably.
- Tracking does not consume so much CPU that preview becomes choppy.
- A tap-to-select subject is optional and recoverable.

### Phase 7: Optional aesthetic scoring

Only after the explainable guidance works should the app add a “composition suggestion” score.

The initial score can be transparent:

```text
score =
    0.25 * subjectVisibility
  + 0.20 * edgeSpacing
  + 0.15 * horizonAlignment
  + 0.15 * exposureQuality
  + 0.15 * sharpness
  + 0.10 * balanceHeuristic
```

Normalize each component to 0...1 and return a confidence value separately. Do not call this machine-learning AI yet. It is a rule-based recommendation system.

Later, a Core ML aesthetic model could rank candidate crops, but it must be evaluated against a curated test set and must not silently replace the explainable rules.

## Performance Rules

- Keep all camera session mutations on one serial queue.
- Keep SwiftUI state on the main actor.
- Analyze downsampled frames, not full-resolution images.
- Throttle Vision requests.
- Reuse `CIContext`.
- Avoid allocating large images every preview frame.
- Cancel stale analysis work.
- Measure frame time, dropped frames, memory, and battery impact.
- Never block the main thread on PhotoKit, Vision, Core Image, or file writing.

## Testing Plan

Test on a simulator for UI and on a physical iPhone for camera behavior.

Scene matrix:

- bright outdoor portrait
- indoor portrait
- backlit person
- low light
- landscape with horizon
- object close to an edge
- multiple people
- no obvious subject
- moving subject
- cluttered background
- portrait and landscape orientation

Functional tests:

- camera permission granted
- camera permission denied
- Photos add permission granted
- Photos add permission denied
- capture while guidance is active
- save original capture
- save filtered/framed result
- create or reuse app album
- interrupted capture
- insufficient storage
- app backgrounded during processing

Performance targets for the first release:

- preview remains visually responsive;
- guidance updates do not visibly freeze the UI;
- no memory warning during repeated captures;
- rendering a single final image completes without the app being killed;
- no unexpected network requests.

## Security And Privacy Guardrails

- No network permissions for the initial release.
- No analytics or photo uploads.
- Request camera permission only for camera use.
- Request add-only Photos permission for export.
- Do not request full library access unless import is added.
- Do not retain captured images after the user discards them, except for temporary processing files that are cleaned up.
- Never overwrite an original photo.
- Do not use a remote “AI image enhancer” without explicit future user consent.

## Local iPhone Deployment

1. Open the project in Xcode.
2. Select the iPhone as the run destination.
3. Choose the developer team under Signing & Capabilities.
4. Use a unique bundle identifier.
5. Connect the iPhone by cable or use wireless device pairing.
6. Trust the developer profile on the iPhone if prompted.
7. Build and run with `Cmd+R`.
8. Test camera and Photos permissions on the physical device.
9. Do not assume simulator camera behavior represents the physical device.

The app does not need to be published to the App Store for local development. Keep signing and provisioning steps documented in `PROJECT_STATUS.md` if Xcode reports a device-specific issue.

## Definition Of Done

The first complete local release must:

- build from Xcode;
- install and launch on the user’s iPhone;
- show a live rear-camera preview;
- capture an image with correct orientation;
- show at least four original local film presets;
- add at least two original frame layouts;
- provide basic explainable composition guidance;
- save a final image to Photos with add-only permission;
- handle denied permissions and failures without crashing;
- keep the AI/aesthetic-model layer optional and replaceable;
- include updated `PROJECT_STATUS.md` and test results.

## Prompt For The Dedicated Codex Project

Paste this as the first message in the new project chat:

```text
You are the lead iOS engineer for the private/local FramedLocal project. Read docs/PROJECT_STATUS.md first, then read docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md. The goal is a native SwiftUI/Xcode iPhone app with local camera capture, composition guidance, original film presets, frames, and PhotoKit export.

Do not copy Framed's or any other app's source code, branding, assets, private implementation, or exact filter recipes. Build original behavior using Apple's AVFoundation, Vision, Core Image, SwiftUI, and Photos frameworks.

Work in small verified phases. Begin by auditing the repository/project and building the untouched app. Report the Xcode version, Swift version, iOS deployment target, signing state, physical-device availability, current architecture, and the smallest safe next step before editing.

Do not attempt all features at once. Implement in this order: baseline, camera preview, still capture, PhotoKit add-only export, film presets and frames, basic explainable composition metrics, stable guidance messages, subject detection/tracking, then optional aesthetic scoring.

Keep camera/session work off the main thread, keep SwiftUI state on the main actor, throttle Vision analysis, reuse CIContext, and preserve the original capture. Never upload photos, request unrelated permissions, overwrite originals, or add a cloud AI backend unless explicitly requested later.

Create and maintain docs/PROJECT_STATUS.md, docs/DECISIONS.md, and docs/TEST_MATRIX.md. After every meaningful turn, update PROJECT_STATUS.md with the current objective, completed step, files changed, tests/build checks, errors, blockers, and exact next step.

If context becomes large, read PROJECT_STATUS.md first, inspect git status and the latest diff, and only reread relevant sections of the initialization document. Do not repeat completed work. Before declaring a feature complete, test it on a physical iPhone where camera, Vision performance, orientation, and Photos permissions are involved.
```

## Context-Recovery Prompt

```text
Resume the FramedLocal iOS project. First read docs/PROJECT_STATUS.md, then inspect git status and the latest diff. Read only the relevant sections of docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md. Identify the last completed acceptance criterion, reproduce the current issue if one is recorded, and continue with the exact next smallest step. Do not redo completed work. Update PROJECT_STATUS.md before ending the turn.
```
