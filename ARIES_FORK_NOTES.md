# Aries — fork migration & build notes

This is a fork of `JesusChapman/valentine`, rebranded to **Aries**, with three new
features added on top: a graphic equalizer, playback-speed control, and a
library/home view. The app stays GPL-3.0; original authorship is retained.

These files were produced outside Xcode and have NOT been compiled. Treat the
first build as a compile-and-fix pass. Everything below is what you change on
your Mac.

## 1. Files in this changeset

New files:
- `Valentine/Models/Equalizer.swift` — EQ state, presets, persistence.
- `Valentine/Models/LibraryTrack.swift` — persistable library record (Codable).
- `Valentine/Services/LibraryStore.swift` — persistent library: JSON index +
  file bookmarks + on-disk artwork cache in Application Support/Aries.
- `Valentine/Views/Player/EqualizerView.swift` — 10-band EQ panel (popover).
- `Valentine/Views/Player/SpeedControlView.swift` — speed slider + presets (popover).
- `Valentine/Views/HomeView.swift` — library browser (Now Playing, Recently
  Added, Albums) built on `LibraryStore`.
- `Valentine/App/AriesApp.swift` — renamed app entry (replaces `ValentineApp.swift`),
  provides `LibraryStore` to the environment.

Rewritten files:
- `Valentine/Services/AudioEngine.swift` — playback core moved from `AVPlayer`
  to `AVAudioEngine` + `AVAudioPlayerNode` + `AVAudioUnitTimePitch` +
  `AVAudioUnitEQ`. Public API the views use is unchanged; added `playbackRate`,
  `equalizer`, EQ/preset methods, and `playFromLibrary(_:startIndex:store:)`.
- `Valentine/App/ContentView.swift` — adds a Library toggle in the toolbar,
  presents `HomeView`, shows the library when the queue is empty, and adds
  dropped files to the library. Empty-state title changed to "Aries".
- `Valentine/Views/Player/PlayerView.swift` — adds EQ + speed buttons to the
  bottom control row.

Rebrand-only files:
- `README.md`, `.github/FUNDING.yml`, `distribution.xml`.

## 2. Replace ValentineApp.swift with AriesApp.swift

Delete `Valentine/App/ValentineApp.swift` and add `AriesApp.swift`. There can be
only one `@main`. The `@main` type is now `AriesApp`; `RootView` is unchanged.

## 3. Xcode project settings (not in source files)

In the target's Build Settings / General:
- **Product Bundle Identifier:** `dev.HighScientist22.Aries`
  (was `dev.jesuschapman.Valentine`).
- **Product Name / Display Name:** `Aries`.
- **Scheme:** rename the `Valentine` scheme to `Aries` if you want `Cmd+R`
  to read naturally (optional).

You can keep the on-disk `Valentine/` source folder name and the
`Valentine.xcodeproj` name to minimize churn, or rename both — if you rename the
project, also update the `open Aries.xcodeproj` line in the README and the
output names in `create-pkg-release.sh` / `distribution.xml`
(`Aries-component.pkg`, already set in `distribution.xml`).

The new Swift files must be added to the target. The project uses Xcode 16
synchronized folders, so dropping them into the right folders should pick them
up automatically; confirm target membership.

## 4. Things to verify on first run (because I couldn't)

The engine rewrite is the highest-risk part. Test specifically:
- **Playback position / scrubbing:** `currentTime` is derived from the player
  node's render time plus a segment offset. Confirm the waveform progress and
  seek land where expected, including seeking while paused.
- **End-of-track advance:** auto-advance is driven by the `scheduleSegment`
  completion handler, guarded against stale completions after seek/skip. Confirm
  no double-skips and that repeat-one / repeat-all / shuffle behave.
- **EQ audibility:** toggle the EQ on and move the 32 Hz / 16k bands; the graph
  is `playerNode -> timePitch -> eq -> mainMixer`. If bands seem inverted or
  silent, check `band.bypass` / `globalGain`.
- **Speed + pitch:** `AVAudioUnitTimePitch.rate` preserves pitch. Confirm 0.5×
  and 2× sound right and that now-playing rate updates.
- **Format changes between tracks:** connecting nodes with `format: nil` lets the
  engine infer formats; if a track with a different sample rate fails, reconnect
  `playerNode -> timePitch` with the file's `processingFormat` in `playTrack`.

## 5. Library notes

The library persists to `~/Library/Application Support/Aries/`:
`library.json` (the index) and `Artwork/` (cached JPEGs). Files are referenced by
plain `URL` bookmarks, which is correct because this app is **not sandboxed**
(no `.entitlements` in the project, and the README ships with an `xattr -cr`
Gatekeeper step). If you ever enable App Sandbox, switch the bookmark calls in
`LibraryStore` to `.withSecurityScope` and add the
`com.apple.security.files.user-selected.read-only` and
`com.apple.security.files.bookmarks.app-scope` entitlements, and wrap file reads
in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`.

The library is the source of truth: playing an album/track via `HomeView` loads
those tracks into the engine's queue with `playFromLibrary`. Drag-and-drop and
Add File/Folder still feed the ephemeral queue and also import into the library.

## 6. Not done here

- App icon still shows the original art (`appicon.icon`). Replace with your own.
- `Localizable.xcstrings` has the new UI strings only as default English; add
  translations if you localize.
- No persistent library DB — `HomeView` organizes the current queue, not an
  imported on-disk library. A real library store would be a separate feature.
