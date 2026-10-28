# FramedLocal Test Matrix

| Area | Scenario | Expected result | Status |
|---|---|---|---|
| Build | iOS 27.1 simulator | App builds without signing | Passed |
| Build | Generic iOS device destination | App builds without signing | Passed |
| Unit tests | iOS 27.1 simulator | Guidance debounce/confidence and preset/frame JPEG-copy checks pass | Passed (4 tests, 0 failures) |
| Launch | iOS 27.1 simulator | App installs and launches | Passed |
| Camera permission | First launch, allow | Live preview appears | Runtime device check pending |
| Camera permission | Deny/revoke | Clear explanation and Settings route | Implemented; runtime check pending |
| Camera selection | Rear and front | Correct camera preview and still | Physical-device check pending |
| Camera readiness | Capture/switch during startup or after startup failure | Controls stay disabled until the session runs; retry available after failure | Implemented; physical-device check pending |
| Capture | Portrait and landscape | JPEG has matching orientation | Physical-device check pending |
| Photos export | Add-only allowed | First asset and Framed album are created together; later assets join when the album can be resolved | Code updated; physical-device runtime check pending |
| Photos export | Existing album unavailable to add-only fetch | Save still succeeds to Photos Recents and UI reports destination accurately | Implemented; runtime check pending |
| Presets | Five local looks | Preview and export use selected look | Implemented; visual/device check pending |
| Frames | Three layouts, date on/off | Preview and export match | Implemented; visual/device check pending |
| Photos export | Denied | Explain permission; capture remains available | Implemented; runtime check pending |
| Scene | Bright outdoor portrait | Preview/capture remains responsive | Pending |
| Scene | Indoor, backlit, low light | Preview/capture remains responsive | Pending |
| Scene | Horizon and landscape | Orientation and framing remain stable | Pending |
| Performance | Repeated capture | No freeze or memory warning | Pending |
| Composition analysis | Face/saliency and sampled image signals | One stable advisory message; capture remains available | Implemented on a dedicated serial analysis queue with a one-frame pending gate; physical-scene tuning pending |
| Subject selection | Tap visible subject | Track selected face/object and recover to searching on loss | Implemented; physical-device check pending |
