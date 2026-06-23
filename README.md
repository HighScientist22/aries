# Aries

**A native, elegant local music player for macOS**

Play your local music files on your Mac in an intuitive, modern interface with built-in synchronized lyrics.

## Overview

Aries is a native macOS music player for your local audio library, with a synchronized lyrics player, a lyrics editor backed by LRCLib, and deep integration with macOS media controls.

Aries is a fork of [Valentine](https://github.com/JesusChapman/valentine) by Jesús David Chapman Vélez, and remains licensed under the GNU General Public License v3.0.

## Key Features

- **Synchronized Lyrics Player:** Lyrics highlight in real time, parsed natively from LRC timestamps.
- **Lyrics Editor:** Search and fetch time-synced lyrics via LRCLib, written into your files' metadata with `mutagen`.
- **Playback Speed Control:** Adjust playback rate from 0.5× to 2× without changing pitch.
- **Graphic Equalizer:** Multi-band EQ with presets, powered by the native audio engine.
- **Dynamic Themes:** Adapts to macOS Light and Dark mode, with optional glow and neon effects and a glass UI.
- **Native Media Controls:** Integrates with macOS media keys, the Now Playing widget, and AirPods.
- **Drag & Drop:** Drag audio files and folders from Finder straight into the window.

## Built With

- **[LRCLib](https://lrclib.net/)** — open-source lyrics API for time-synced `.lrc` lyrics.
- **[Mutagen](https://mutagen.readthedocs.io/)** — Python tagging library used to write lyrics into file metadata.
- **[AVFoundation](https://developer.apple.com/av-foundation/)** — Apple's native audio framework driving playback, EQ, and waveform data.
- **[Last.fm API](https://www.last.fm/api)** — optional scrobbling.
- **[ListenBrainz](https://listenbrainz.org/)** — optional scrobbling via user token.

## Download

Grab the latest `Aries.dmg` from the [Releases](https://github.com/HighScientist22/aries/releases) page, open it, and drag **Aries** into your Applications folder.

> **First launch:** Aries is signed with a personal development certificate, not a paid Apple Developer ID, so macOS Gatekeeper will warn you the first time. Either right-click the app and choose **Open**, or run:
> ```
> xattr -cr /Applications/Aries.app
> ```
> If the build stops launching after about a week, that's the development-certificate expiry — rebuild from source or grab a newer release.

## How to Compile

You need a Mac running **macOS Tahoe 26** or newer with Xcode installed.

1. Clone the repository:

```
git clone https://github.com/HighScientist22/aries.git
cd aries
```

2. Open the Xcode project:

```
open Aries.xcodeproj
```

3. Configure the project:
   - Select your Apple Developer ID team in the project settings.
   - **Last.fm (optional):** to enable scrobbling, copy `Valentine/Config/Secrets.example.swift` to `Secrets.swift`, uncomment it, and add your own [Last.fm API key](https://www.last.fm/api/account/create). `Secrets.swift` is gitignored and never committed.

4. Build & run:
   - Select your Mac as the destination and press `Cmd + R`.
   - If Python 3 is present, the app will offer to install `mutagen` from its UI when you first edit lyrics.

## License

Licensed under the GNU General Public License v3.0. See the [LICENSE](LICENSE) file.

Original work © Jesús David Chapman Vélez (Valentine). Modifications © the Aries contributors.
