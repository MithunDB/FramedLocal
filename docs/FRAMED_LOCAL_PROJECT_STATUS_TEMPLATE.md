# FramedLocal Project Status

This is the compact living memory for the iOS project. Update it after every meaningful change, build, test, or failed attempt.

## Current State

- Date:
- Phase:
- Branch:
- Xcode version:
- Swift version:
- iOS deployment target:
- Physical iPhone connected: `yes` / `no`
- Last known-good build:
- Status: `not-started` / `in-progress` / `blocked` / `ready-for-review`

## Current Objective

<!-- One concrete objective only. -->

## Last Completed Step

<!-- Files changed and verification performed. -->

## Current Problem

<!-- Exact error or incorrect behavior. Write “None” if clear. -->

## Next Smallest Step

<!-- One focused action for the next Codex turn. -->

## Verification

| Check | Result | Notes |
|---|---|---|
| Simulator build | Not run | |
| Physical-device build | Not run | |
| Camera permission flow | Not run | |
| Capture orientation | Not run | |
| Vision performance | Not run | |
| Film preset rendering | Not run | |
| Frame rendering | Not run | |
| Photos export | Not run | |
| Permission denial handling | Not run | |

## Decisions

- Native SwiftUI/Xcode app.
- Local processing only for the initial release.
- Use AVFoundation, Vision, Core Image, and PhotoKit.
- Preserve original captures and export new assets.
- Composition advice is a recommendation, not an objective truth.
- No cloud AI backend in the initial release.

## Known Issues

- None recorded.

## Blockers And Failed Attempts

<!-- Include command, error, attempted fix, and current outcome. -->

- None recorded.

## Files To Revisit

- None recorded.

## Recovery Instruction

Read this file first after context compression. Then inspect `git status`, the latest diff, and only the relevant sections of `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`.
