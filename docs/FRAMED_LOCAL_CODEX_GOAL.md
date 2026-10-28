# Codex Goal: Build FramedLocal

Work in the private repository:

`https://github.com/MithunDB/FramedLocal`

Build the complete private/local `Framed` iPhone camera app described in `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`.

## Working Directory

Perform the implementation in:

`/Users/mithundb/Desktop/Code/Framed`

Create the directory if it does not exist. Treat that folder as the local Xcode project workspace and keep all app source, project files, assets, tests, and build-support files there. The GitHub repository is the source for these planning documents and should also receive the implementation commits when Git is initialized or connected from the working directory. Do not implement the app in the repository's `docs` folder.

## Required Startup

1. Read `docs/PROJECT_STATUS.md` if it exists.
2. Read `docs/FRAMED_LOCAL_IOS_PROJECT_INIT.md`.
3. If `docs/PROJECT_STATUS.md` does not exist, copy `docs/FRAMED_LOCAL_PROJECT_STATUS_TEMPLATE.md` to that path.
4. Inspect the repository, Xcode project state, `git status`, and current diffs.
5. Build the untouched project before feature work.
6. Record Xcode, Swift, iOS, macOS, signing, and physical-device details in `PROJECT_STATUS.md`.
7. Report the audit and the smallest safe first implementation step before editing.

## Target Configuration

- Test device: iPhone 12 on iOS 27
- Development Mac: base M5 MacBook Pro with 16 GB memory
- Development OS: macOS 27 Golden Gate
- Xcode: 27.1 initially
- Temporary display name: `Framed`
- Bundle identifier: `local.mithundb.framed`
- Front and rear camera support
- JPEG-first output
- Portrait and landscape support
- Cinematic plus several original film presets
- Minimal guidance UI
- Dedicated `Framed` Photos album
- New captures first; existing Photos editing is a later phase after capture/export are stable

## Implementation Order

1. Establish a clean Xcode build and physical-device run.
2. Implement AVFoundation camera preview and still capture.
3. Implement orientation handling and camera permission states.
4. Implement PhotoKit add-only export and the dedicated album.
5. Implement original Core Image film presets and frame/date rendering.
6. Implement Photos-picker import for existing images without modifying originals.
7. Implement Vision face/subject detection and explainable composition metrics.
8. Implement stable minimal guidance messages and optional haptics.
9. Implement tap-to-select subject tracking.
10. Add performance, memory, cancellation, permission, and physical-device tests.
11. Produce a reliable local build that installs and runs on the iPhone 12.

## Non-Negotiable Rules

- Do not copy Framed’s source code, branding, assets, private implementation, or exact filter recipes.
- Do not add cloud AI, analytics, photo uploads, or network dependencies in the initial release.
- Do not overwrite original photos; always export new assets.
- Do not request full Photos-library access when the Photos picker or add-only access is sufficient.
- Do not run Vision or full-resolution rendering on the main thread.
- Do not call a composition recommendation objectively “the best frame.”
- Do not implement every phase in one unverified change.

## Status And Context Recovery

After every meaningful turn, update `docs/PROJECT_STATUS.md` with:

- current objective;
- completed work and changed files;
- builds and tests run;
- exact errors and attempted fixes;
- blockers;
- exact next smallest step.

When context becomes large, read `PROJECT_STATUS.md` first, inspect `git status` and the latest diff, and then read only the relevant sections of the init document. Do not redo completed work.

Continue until the app builds, installs on the physical iPhone, captures photos from both cameras, applies presets and frames, provides composition guidance, edits selected existing photos without changing originals, and saves final results into Photos.
