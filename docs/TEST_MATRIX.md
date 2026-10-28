# FramedLocal Test Matrix

| Area | Scenario | Expected result | Status |
|---|---|---|---|
| Build | iOS 27.1 simulator | App builds without signing | Passed |
| Build | Generic iOS device destination | App builds without signing | Passed |
| Unit tests | iOS 27.1 simulator | Guidance debounce/confidence and preset/frame JPEG-copy checks pass | Passed (29 tests, 0 failures) |
| Launch | iOS 27.1 simulator | App installs and launches | Passed |
| Camera permission | First launch, allow | Live preview appears | Runtime device check pending |
| Camera permission | Deny/revoke | Clear explanation and Settings route | Implemented; runtime check pending |
| Camera selection | Rear and front | Correct camera preview and still | Explicit front mirroring configured for preview/analysis/still; physical-device check pending |
| Camera UI state | Permission, session, guidance, and capture transitions | SwiftUI refreshes from controller changes | Controller now publishes UI state; physical camera interaction pending |
| Camera readiness | Capture/switch during startup or after startup failure | Controls stay disabled until the session runs; retry available after failure | Implemented; physical-device check pending |
| Camera recovery | Configuration fails after adding part of a session | Partial inputs/outputs are removed so a retry can configure cleanly | Rollback implemented; needs runtime failure injection/device check |
| Camera lifecycle | Stop/background during queued startup, then restart | Stale start completion cannot publish running state after stop/restart | Session generation unit test passed; physical lifecycle check pending |
| Camera analysis lifecycle | Start/recovery/lens switch while Vision work is in flight | Clear prior frame/selection state, pause analysis while reconfiguring, and discard results from the prior camera generation | Analysis generation gate unit test passed; physical lens-switch check pending |
| Camera interruption | System interrupts camera, then interruption ends | Show temporary unavailable state and resume only while camera is still desired | Recovery policy tests passed; physical interruption check pending |
| Camera runtime error | Media services reset or other runtime error | Attempt automatic restart only for media reset; show Retry for other errors | Recovery policy tests passed; physical runtime-error injection pending |
| Capture and live analysis | Portrait and landscape | Camera JPEG pixels/EXIF and Vision detections use current device orientation | Rotation angle/mirroring configured; Vision orientation updated on device rotation; physical-device check pending; renderer output separately verified upright |
| Capture completion | Processing error, capture-level error, or missing photo data | Delegate completes once and clears capture busy state | Result resolution passed in simulator unit tests; physical AVFoundation callback check pending |
| Photos export | Add-only allowed | First asset and Framed album are created together; later assets join when the album can be resolved | Code updated; physical-device runtime check pending |
| Photos export | Existing album unavailable to add-only fetch | Save still succeeds to Photos Recents and UI reports destination accurately | Recents status message unit test passed; runtime check pending |
| Photos export integrity | Asset placeholder unavailable / album mutation fails | Never report success without an asset; fallback only after failed album mutation | Transaction-state logic passed in simulator unit tests; PhotoKit runtime check pending |
| Presets | Five local looks | Preview and export use selected look | Implemented; visual/device check pending |
| Frames | Three layouts, date on/off | Preview and export match | Implemented; visual/device check pending |
| Renderer | Portrait and landscape input, date on/off | Output pixel dimensions preserve orientation; date adds canvas space; output has no rotation tag | Passed in simulator unit tests |
| Renderer memory bound | 2,800-pixel source | Film output is reduced to at most 2,400 pixels on the long edge before frame rendering | Passed in simulator unit tests |
| Preview decode | Bounded rendered JPEG | ImageIO decodes to CGImage off the main actor and preserves pixel dimensions | Passed in simulator unit tests; physical responsiveness pending |
| Imported EXIF orientation | Landscape pixel data tagged with portrait orientation | Film render bakes orientation into upright pixels and removes rotation tag | Passed in simulator unit tests |
| Editor pipeline | All five presets × three frame layouts on EXIF-rotated input | Every export is JPEG and remains upright; original source bytes remain unchanged | Passed in simulator unit tests |
| Editor crop | Original, square, 4:3, and 16:9 crop selections | Crop is centered, output pixel dimensions match selected ratio, original source bytes remain unchanged | Passed in simulator unit tests; physical UI review pending |
| Editor crop positioning | Reposition square/landscape crops and reset; import with EXIF rotation | Position moves only along the available crop axis, stays in bounds, and changes rendered pixels without changing source bytes | Passed in simulator geometry/render/EXIF unit tests; physical UI review pending |
| Editor date stamp | Re-render same image after control changes; render with another selected date | Stamp remains fixed for the selected editor source and output is deterministic | Passed in simulator unit tests; visual review pending |
| Photos export | Denied | Explain permission; capture remains available | Implemented; runtime check pending |
| Photos-picker import | Select an existing image | Transfer only selected image; original bytes remain unchanged through editing/export | Implemented; physical UI/runtime check pending |
| Import cancellation | Leave editor while transfer is active | Transfer is invalidated and editor can choose again on reappearance | State reset implemented; UI lifecycle runtime test pending |
| Scene | Bright outdoor portrait | Preview/capture remains responsive | Pending |
| Scene | Indoor, backlit, low light | Preview/capture remains responsive | Pending |
| Scene | Horizon and landscape | Orientation and framing remain stable | Pending |
| Horizon sensor mapping | Level/tilted phone in portrait and landscape; invalid gravity projection | Use the active device orientation to select the gravity axis and avoid a false level hint | Mapping and 0.45-second stability/reset unit tests passed; physical sensor calibration pending |
| Performance | Repeated capture | No freeze or memory warning | Pending |
| Composition analysis | Face/saliency and sampled image signals | One stable advisory message; capture remains available | Preview-sized buffers, dedicated serial queue, explicit 7 Hz rate limiter, AVFoundation late-frame dropping, unrotated buffers with Vision orientation mapping; throttle unit test passed; physical-scene tuning pending |
| Subject selection | Tap visible subject in rotated/aspect-filled preview | Preview-layer conversion maps tap into capture-device coordinates; report found/missing subject, ignore stale tap feedback, and clear tracking on stop/lens switch | Mapping/resolution/feedback unit tests passed; physical-device selection check pending |
| Guidance recovery | Selected subject disappears / confidence remains low | Detection and manual tracking use distinct confidence thresholds and recovery messages | Passed in simulator GuidanceEngine tests; live tracking-loss check pending |
| Exposure cues | Bright clipping and low-light shadow clipping | Offer explainable lower-exposure or add-light suggestions after focus/framing checks | Passed in simulator unit tests; physical scene tuning pending |
| Guidance haptics | Haptics enabled/disabled and stable guidance | Haptic fires only on entry to “Hold steady” when enabled; visual advice remains visible when disabled | Decision logic passed in simulator unit tests; physical haptic pending |
| Preset determinism | Render same source twice with Night Grain | Identical input produces identical JPEG output | Passed in simulator unit tests |
