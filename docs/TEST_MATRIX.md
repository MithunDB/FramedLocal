# FramedLocal Test Matrix

| Area | Scenario | Expected result | Status |
|---|---|---|---|
| Build | iOS 27.1 simulator | App builds without signing | Passed |
| Build | Generic iOS device destination | App builds without signing | Passed |
| Unit tests | iOS 27.1 simulator | Guidance debounce/confidence and preset/frame JPEG-copy checks pass | Passed (4 tests, 0 failures) |
| Launch | iOS 27.1 simulator | App installs and launches | Passed |
| Camera permission | First launch, allow | Live preview appears | Runtime device check pending |
| Camera permission | Deny/revoke | Clear explanation and Settings route | Implemented; runtime check pending |
| Camera selection | Rear and front | Correct camera preview and still | Explicit front mirroring configured for preview/analysis/still; physical-device check pending |
| Camera UI state | Permission, session, guidance, and capture transitions | SwiftUI refreshes from controller changes | Controller now publishes UI state; physical camera interaction pending |
| Camera readiness | Capture/switch during startup or after startup failure | Controls stay disabled until the session runs; retry available after failure | Implemented; physical-device check pending |
| Camera recovery | Configuration fails after adding part of a session | Partial inputs/outputs are removed so a retry can configure cleanly | Rollback implemented; needs runtime failure injection/device check |
| Capture | Portrait and landscape | Camera JPEG pixels/EXIF match device orientation | Rotation angle and mirroring are explicitly configured; physical-device capture check pending; renderer output separately verified upright |
| Photos export | Add-only allowed | First asset and Framed album are created together; later assets join when the album can be resolved | Code updated; physical-device runtime check pending |
| Photos export | Existing album unavailable to add-only fetch | Save still succeeds to Photos Recents and UI reports destination accurately | Implemented; runtime check pending |
| Presets | Five local looks | Preview and export use selected look | Implemented; visual/device check pending |
| Frames | Three layouts, date on/off | Preview and export match | Implemented; visual/device check pending |
| Renderer | Portrait and landscape input, date on/off | Output pixel dimensions preserve orientation; date adds canvas space; output has no rotation tag | Passed in simulator unit tests |
| Renderer memory bound | 2,800-pixel source | Film output is reduced to at most 2,400 pixels on the long edge before frame rendering | Passed in simulator unit tests |
| Imported EXIF orientation | Landscape pixel data tagged with portrait orientation | Film render bakes orientation into upright pixels and removes rotation tag | Passed in simulator unit tests |
| Editor pipeline | All five presets × three frame layouts on EXIF-rotated input | Every export is JPEG and remains upright; original source bytes remain unchanged | Passed in simulator unit tests |
| Photos export | Denied | Explain permission; capture remains available | Implemented; runtime check pending |
| Photos-picker import | Select an existing image | Transfer only selected image; original bytes remain unchanged through editing/export | Implemented; physical UI/runtime check pending |
| Import cancellation | Leave editor while transfer is active | Transfer is invalidated and editor can choose again on reappearance | State reset implemented; UI lifecycle runtime test pending |
| Scene | Bright outdoor portrait | Preview/capture remains responsive | Pending |
| Scene | Indoor, backlit, low light | Preview/capture remains responsive | Pending |
| Scene | Horizon and landscape | Orientation and framing remain stable | Pending |
| Performance | Repeated capture | No freeze or memory warning | Pending |
| Composition analysis | Face/saliency and sampled image signals | One stable advisory message; capture remains available | Implemented on a dedicated serial analysis queue with a one-frame pending gate; physical-scene tuning pending |
| Subject selection | Tap visible subject | Track selected face/object and recover to searching on loss | Implemented; physical-device check pending |
