# FramedLocal Decisions

- Build a native SwiftUI iPhone app using AVFoundation, Vision, Core Image, and PhotoKit.
- Keep camera/session mutations on a dedicated serial queue and UI state on the main actor.
- Use `local.mithundb.framed` as the bundle identifier and `Framed` as the configurable display name.
- Keep processing local. Do not add analytics, photo uploads, cloud AI, or a network dependency in the initial release.
- Preserve source captures and Photos assets; editing and rendering always export a new asset.
- Request add-only Photos permission for saves. Use the system Photos picker for later imports.
- Composition guidance is advisory and must not claim an objectively best frame.
