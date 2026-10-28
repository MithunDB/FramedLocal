# FramedLocal Test Matrix

| Area | Scenario | Expected result | Status |
|---|---|---|---|
| Build | iOS 27.1 simulator | App builds without signing | Passed |
| Launch | iOS 27.1 simulator | App installs and launches | Passed |
| Camera permission | First launch, allow | Live preview appears | Runtime device check pending |
| Camera permission | Deny/revoke | Clear explanation and Settings route | Implemented; runtime check pending |
| Camera selection | Rear and front | Correct camera preview and still | Physical-device check pending |
| Capture | Portrait and landscape | JPEG has matching orientation | Physical-device check pending |
| Photos export | Add-only allowed | New asset appears in Framed album | Implemented; runtime check pending |
| Presets | Five local looks | Preview and export use selected look | Implemented; visual/device check pending |
| Frames | Three layouts, date on/off | Preview and export match | Implemented; visual/device check pending |
| Photos export | Denied | Explain permission; capture remains available | Implemented; runtime check pending |
| Scene | Bright outdoor portrait | Preview/capture remains responsive | Pending |
| Scene | Indoor, backlit, low light | Preview/capture remains responsive | Pending |
| Scene | Horizon and landscape | Orientation and framing remain stable | Pending |
| Performance | Repeated capture | No freeze or memory warning | Pending |
| Composition analysis | Face/saliency and sampled image signals | One stable advisory message; capture remains available | Implemented; physical-scene tuning pending |
| Subject selection | Tap visible subject | Track selected face/object and recover to searching on loss | Implemented; physical-device check pending |
