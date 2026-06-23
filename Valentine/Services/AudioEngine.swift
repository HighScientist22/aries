//
//  AudioEngine.swift
//  Aries
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//  Playback core reworked onto AVAudioEngine for equalizer and rate control.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI
import MediaPlayer

enum RepeatMode: Int {
    case off = 0
    case one = 1
    case all = 2
}

@MainActor
class AudioEngine: ObservableObject {
    @Published var queue: [Track] = []
    @Published var currentTrackIndex: Int?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var showLyrics: Bool = false
    @Published var showLyricsEditor: Bool = false
    @Published var showMutagenInstaller: Bool = false
    @Published var isFetchingLyrics: Bool = false

    @Published var repeatMode: RepeatMode = .off
    @Published var shuffleMode: Bool = false
    @Published var isGlowEffectEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isGlowEffectEnabled, forKey: "isGlowEffectEnabled")
        }
    }
    @Published var isNeonEffectEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isNeonEffectEnabled, forKey: "isNeonEffectEnabled")
        }
    }
    @Published var volume: Float = 1.0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    @Published var playbackRate: Float = 1.0 {
        didSet {
            timePitch.rate = playbackRate
            UserDefaults.standard.set(playbackRate, forKey: "playbackRate")
            updateNowPlayingInfo()
        }
    }

    @Published var equalizer = Equalizer()

    @Published var waveformPoints: [Float] = []

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eqNode: AVAudioUnitEQ

    private var currentFile: AVAudioFile?
    private var currentFormat: AVAudioFormat?
    private var sampleRate: Double = 44_100
    private var frameLength: AVAudioFramePosition = 0

    // Frame offset applied when resuming from a paused/seeked position. The
    // player node's sampleTime resets to zero on every scheduleFile, so the
    // played position is segmentStartFrame + (node sampleTime since start).
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var isSegmentScheduled = false
    // Incremented every time a segment is scheduled or playback is stopped, so
    // completion callbacks from flushed/replaced segments can be ignored.
    private var playbackGeneration = 0
    private var displayLink: Timer?

    // Library IDs aligned to `queue`, used to record recently-played tracks.
    private var queueLibraryIDs: [UUID] = []
    private weak var libraryStore: LibraryStore?

    private var userDefaultsObserver: NSObjectProtocol?
    private var hasScrobbledCurrentTrack = false
    private var currentTrackStartTime: Int = 0
    private var lyricsFetchTask: Task<Void, Never>?

    var currentTrack: Track? {
        guard let index = currentTrackIndex, queue.indices.contains(index) else { return nil }
        return queue[index]
    }

    init() {
        self.eqNode = AVAudioUnitEQ(numberOfBands: Equalizer.bandFrequencies.count)

        self.isGlowEffectEnabled = UserDefaults.standard.bool(forKey: "isGlowEffectEnabled")
        self.isNeonEffectEnabled = UserDefaults.standard.bool(forKey: "isNeonEffectEnabled")
        if let storedRate = UserDefaults.standard.object(forKey: "playbackRate") as? Float {
            self.playbackRate = storedRate
        }

        configureEngine()
        setupRemoteCommandCenter()
        equalizer.load()
        applyEqualizer()

        self.userDefaultsObserver = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let newGlow = UserDefaults.standard.bool(forKey: "isGlowEffectEnabled")
                let newNeon = UserDefaults.standard.bool(forKey: "isNeonEffectEnabled")
                if self.isGlowEffectEnabled != newGlow { self.isGlowEffectEnabled = newGlow }
                if self.isNeonEffectEnabled != newNeon { self.isNeonEffectEnabled = newNeon }
                // Reload equalizer settings from UserDefaults so the settings
                // window can modify them without holding a reference to the
                // engine. `equalizer.load()` updates the model from defaults.
                let previousEnabled = self.equalizer.isEnabled
                self.equalizer.load()
                // If equalizer state changed, apply to the audio graph.
                self.applyEqualizer()
            }
        }
    }

    deinit {
        displayLink?.invalidate()
        if let defaultsObserver = userDefaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }

    private func configureEngine() {
        timePitch.rate = playbackRate
        timePitch.overlap = 8

        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(eqNode)

        // playerNode -> timePitch -> eq -> mainMixer
        engine.connect(playerNode, to: timePitch, format: nil)
        engine.connect(timePitch, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)

        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayback() }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.nextTrack() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.previousTrack() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let time = positionEvent.positionTime
            Task { @MainActor [weak self] in self?.seek(to: time) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let track = currentTrack {
            nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
            if let album = track.album {
                nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = album
            }
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration

            if let nsImage = track.nsImage {
                let artwork = MPMediaItemArtwork(boundsSize: nsImage.size) { _ in nsImage }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(playbackRate) : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    #if os(macOS)
    func showAddFileDialog() {
        let urls = MusicImportPanel.pickFiles(allowFolders: false)
        guard !urls.isEmpty else { return }
        addTracks(urls)
    }

    func showAddFolderDialog() {
        let urls = MusicImportPanel.pickFiles(allowFolders: true)
        guard !urls.isEmpty else { return }
        addTracks(urls)
    }
    #endif

    func clearPlaylist() {
        stopPlayback()
        self.queue.removeAll()
        self.queueLibraryIDs.removeAll()
        self.currentTrackIndex = nil
        self.currentTime = 0
        self.duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // Replaces the queue with tracks resolved from the persistent library and
    // starts playback at `startIndex`.
    func playFromLibrary(
        _ libraryTracks: [LibraryTrack],
        startIndex: Int,
        store: LibraryStore,
        shuffleTracks: Bool = false
    ) {
        queueFromLibrary(
            libraryTracks,
            startIndex: startIndex,
            store: store,
            mode: .playNow,
            shuffleTracks: shuffleTracks
        )
    }

    func queueFromLibrary(
        _ libraryTracks: [LibraryTrack],
        startIndex: Int = 0,
        store: LibraryStore,
        mode: LibraryQueueMode = .playNow,
        shuffleTracks: Bool = false
    ) {
        Task {
            self.libraryStore = store
            let resolved = await Self.resolveLibraryTracks(libraryTracks, store: store, shuffle: shuffleTracks)
            guard !resolved.isEmpty else { return }

            switch mode {
            case .playNow:
                stopPlayback()
                queue = resolved.map(\.track)
                queueLibraryIDs = resolved.map(\.libraryID)
                let target = queue.indices.contains(startIndex) ? startIndex : 0
                playTrack(at: target)

            case .playNext:
                let insertIndex: Int
                if let current = currentTrackIndex {
                    insertIndex = min(current + 1, queue.count)
                } else {
                    insertIndex = 0
                }
                let tracksToInsert = resolved.map(\.track)
                let idsToInsert = resolved.map(\.libraryID)
                queue.insert(contentsOf: tracksToInsert, at: insertIndex)
                queueLibraryIDs.insert(contentsOf: idsToInsert, at: insertIndex)
                if currentTrackIndex == nil {
                    playTrack(at: 0)
                }

            case .addToQueue:
                queue.append(contentsOf: resolved.map(\.track))
                queueLibraryIDs.append(contentsOf: resolved.map(\.libraryID))
                if currentTrackIndex == nil, !queue.isEmpty {
                    playTrack(at: 0, autoPlay: false)
                }
            }
        }
    }

    private static func resolveLibraryTracks(
        _ libraryTracks: [LibraryTrack],
        store: LibraryStore,
        shuffle: Bool
    ) async -> [(track: Track, libraryID: UUID)] {
        var sourceTracks = libraryTracks
        if shuffle { sourceTracks.shuffle() }

        var resolved: [(track: Track, libraryID: UUID)] = []
        for libTrack in sourceTracks {
            guard let url = store.resolveURL(for: libTrack) else { continue }

            var track = Track(url: url)
            track.title = libTrack.title
            track.artist = libTrack.artist
            track.album = libTrack.album
            track.duration = libTrack.duration
            if let artURL = store.artworkURL(for: libTrack),
               let image = await ArtworkLoader.shared.image(at: artURL, maxPixelSize: 512) {
                track.nsImage = image
                track.albumArt = Image(nsImage: image)
            }
            resolved.append((track, libTrack.id))
        }
        return resolved
    }

    func addTracks(_ urls: [URL]) {
        Task {
            var audioURLs: [URL] = []
            let fileManager = FileManager.default
            let supportedExtensions = SupportedAudioFormats.extensions

            for url in urls {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                            while let fileURL = enumerator.nextObject() as? URL {
                                let ext = fileURL.pathExtension.lowercased()
                                if supportedExtensions.contains(ext) {
                                    audioURLs.append(fileURL)
                                }
                            }
                        }
                    } else {
                        audioURLs.append(url)
                    }
                }
            }

            for url in audioURLs {
                var track = Track(url: url)
                await track.loadMetadata()
                self.queue.append(track)
            }
            if self.currentTrackIndex == nil && !self.queue.isEmpty {
                self.playTrack(at: 0, autoPlay: false)
            }
        }
    }

    func playTrack(at index: Int, autoPlay: Bool = true) {
        guard queue.indices.contains(index) else { return }
        let track = queue[index]

        stopPlayback()

        do {
            let file = try AVAudioFile(forReading: track.url)
            currentFile = file
            currentFormat = file.processingFormat
            sampleRate = file.processingFormat.sampleRate
            frameLength = file.length
        } catch {
            print("Failed to open \(track.url): \(error)")
            return
        }

        currentTrackIndex = index
        duration = track.duration
        currentTime = 0
        segmentStartFrame = 0

        if queueLibraryIDs.indices.contains(index) {
            libraryStore?.markPlayed(queueLibraryIDs[index])
        }

        hasScrobbledCurrentTrack = false
        currentTrackStartTime = Int(Date().timeIntervalSince1970)
        LastFMService.shared.updateNowPlaying(track: track.title, artist: track.artist, album: track.album, duration: Int(track.duration))
        ListenBrainzService.shared.updateNowPlaying(track: track.title, artist: track.artist, album: track.album)

        generateWaveform(for: track.url, generation: playbackGeneration)

        if autoPlay {
            play()
        } else {
            isPlaying = false
            updateNowPlayingInfo()
        }

        fetchLyricsIfNeeded(for: index)
    }

    // Schedules the current file from `segmentStartFrame` to its end. Uses the
    // .dataPlayedBack callback so completion fires only when audio has actually
    // finished playing, not when the buffer is merely consumed by the renderer.
    private func scheduleFromCurrentSegment() {
        guard let file = currentFile else { return }
        let startFrame = segmentStartFrame
        let framesToPlay = AVAudioFrameCount(max(0, frameLength - startFrame))
        guard framesToPlay > 0 else { return }

        file.framePosition = startFrame
        playbackGeneration += 1
        let generation = playbackGeneration
        isSegmentScheduled = true

        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: framesToPlay, at: nil, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Ignore completions from a segment we've since replaced (skip/seek/stop).
                guard self.playbackGeneration == generation, self.isPlaying else { return }
                self.isSegmentScheduled = false
                self.nextTrack(isAutomatic: true)
            }
        }
    }

    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        guard currentFile != nil else { return }
        startEngineIfNeeded()
        if !isSegmentScheduled {
            scheduleFromCurrentSegment()
        }
        playerNode.play()
        isPlaying = true
        startDisplayLink()
        updateNowPlayingInfo()
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        stopDisplayLink()
        updateNowPlayingInfo()
    }

    private func stopPlayback() {
        playerNode.stop()
        isPlaying = false
        isSegmentScheduled = false
        stopDisplayLink()
    }

    func nextTrack(isAutomatic: Bool = false) {
        guard let currentIndex = currentTrackIndex else { return }

        if isAutomatic && repeatMode == .one {
            seek(to: 0)
            play()
            return
        }

        if shuffleMode {
            if queue.count > 1 {
                var nextIndex = Int.random(in: 0..<queue.count)
                while nextIndex == currentIndex {
                    nextIndex = Int.random(in: 0..<queue.count)
                }
                playTrack(at: nextIndex)
            } else if repeatMode == .all {
                playTrack(at: currentIndex)
            } else {
                stopPlayback()
                segmentStartFrame = 0
                currentTime = 0
            }
            return
        }

        if currentIndex + 1 < queue.count {
            playTrack(at: currentIndex + 1)
        } else if repeatMode == .all {
            playTrack(at: 0)
        } else {
            stopPlayback()
            segmentStartFrame = 0
            currentTime = 0
        }
    }

    func previousTrack() {
        guard let currentIndex = currentTrackIndex else { return }
        if currentTime > 3.0 {
            seek(to: 0)
        } else if currentIndex > 0 {
            playTrack(at: currentIndex - 1)
        }
    }

    func seek(to time: TimeInterval) {
        guard currentFile != nil else { return }
        let clamped = max(0, min(time, duration))
        let wasPlaying = isPlaying

        playerNode.stop()
        isSegmentScheduled = false
        segmentStartFrame = AVAudioFramePosition(clamped * sampleRate)
        currentTime = clamped

        scheduleFromCurrentSegment()
        if wasPlaying {
            startEngineIfNeeded()
            playerNode.play()
            isPlaying = true
            startDisplayLink()
        }
        updateNowPlayingInfo()
    }

    func removeTrack(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }

    func removeTracks(withIds ids: Set<UUID>) {
        let currentTrackId = currentTrack?.id

        let indicesToRemove = queue.enumerated().compactMap { index, track in
            ids.contains(track.id) ? index : nil
        }

        queue.remove(atOffsets: IndexSet(indicesToRemove))

        if let currentId = currentTrackId {
            if ids.contains(currentId) {
                stopPlayback()
                currentTrackIndex = queue.isEmpty ? nil : 0
                if !queue.isEmpty {
                    playTrack(at: 0)
                }
            } else {
                currentTrackIndex = queue.firstIndex(where: { $0.id == currentId })
            }
        }
    }

    // MARK: - Equalizer

    func applyEqualizer() {
        eqNode.globalGain = equalizer.isEnabled ? equalizer.preamp : 0
        for (index, band) in eqNode.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = Equalizer.bandFrequencies[index]
            band.bandwidth = 0.5
            band.bypass = !equalizer.isEnabled
            band.gain = equalizer.isEnabled ? equalizer.gains[index] : 0
        }
    }

    func setEqualizerBand(_ index: Int, gain: Float) {
        guard equalizer.gains.indices.contains(index) else { return }
        equalizer.gains[index] = gain
        equalizer.activePreset = nil
        equalizer.save()
        applyEqualizer()
    }

    func setEqualizerEnabled(_ enabled: Bool) {
        equalizer.isEnabled = enabled
        equalizer.save()
        applyEqualizer()
    }

    func applyEqualizerPreset(_ preset: EqualizerPreset) {
        equalizer.gains = preset.gains
        equalizer.activePreset = preset.id
        equalizer.save()
        applyEqualizer()
    }

    // MARK: - Position tracking

    private func startDisplayLink() {
        stopDisplayLink()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updatePlayhead() }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayLink = timer
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updatePlayhead() {
        guard isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }

        let playedFrames = Double(playerTime.sampleTime)
        let elapsed = Double(segmentStartFrame) / sampleRate + playedFrames / playerTime.sampleRate
        currentTime = min(max(0, elapsed), duration)

        if let currentTrack = currentTrack, duration > 30, !hasScrobbledCurrentTrack {
            let scrobblePoint = min(duration / 2.0, 240.0)
            if currentTime >= scrobblePoint {
                hasScrobbledCurrentTrack = true
                LastFMService.shared.scrobble(track: currentTrack.title, artist: currentTrack.artist, album: currentTrack.album, timestamp: currentTrackStartTime)
                ListenBrainzService.shared.scrobble(track: currentTrack.title, artist: currentTrack.artist, album: currentTrack.album, timestamp: currentTrackStartTime)
            }
        }
    }

    private func generateWaveform(for url: URL, generation: Int) {
        Task.detached(priority: .utility) {
            do {
                if let cached = Self.loadCachedWaveform(for: url) {
                    await MainActor.run {
                        guard self.playbackGeneration == generation else { return }
                        self.waveformPoints = cached
                    }
                    return
                }

                let file = try AVAudioFile(forReading: url)
                let format = file.processingFormat
                let channelCount = Int(format.channelCount)
                let totalFrames = Int(file.length)
                guard totalFrames > 0 else { return }

                let targetSamples = 100
                let samplesPerPoint = max(1, totalFrames / targetSamples)
                let chunkSize: AVAudioFrameCount = 16_384

                var peaks = [Float](repeating: 0, count: targetSamples)
                var globalFrame = 0
                var pointIndex = 0
                var pointMax: Float = 0

                while globalFrame < totalFrames {
                    let framesToRead = min(chunkSize, AVAudioFrameCount(totalFrames - globalFrame))
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else { break }
                    try file.read(into: buffer, frameCount: framesToRead)

                    let length = Int(buffer.frameLength)
                    guard let floatChannelData = buffer.floatChannelData else { break }

                    for frame in 0..<length {
                        guard pointIndex < targetSamples else { break }
                        var samplePeak: Float = 0
                        for channel in 0..<channelCount {
                            samplePeak = max(samplePeak, abs(floatChannelData[channel][frame]))
                        }
                        pointMax = max(pointMax, samplePeak)

                        let framesSeen = globalFrame + frame + 1
                        let nextBoundary = min(totalFrames, (pointIndex + 1) * samplesPerPoint)
                        if framesSeen >= nextBoundary {
                            peaks[pointIndex] = pointMax
                            pointIndex += 1
                            pointMax = 0
                        }
                    }

                    globalFrame += length
                }

                while pointIndex < targetSamples {
                    peaks[pointIndex] = pointMax
                    pointIndex += 1
                    pointMax = 0
                }

                let overallMax = peaks.max() ?? 1
                let normalized = peaks.map { $0 / max(overallMax, 0.0001) }
                Self.saveCachedWaveform(normalized, for: url)

                await MainActor.run {
                    guard self.playbackGeneration == generation else { return }
                    self.waveformPoints = normalized
                }
            } catch {
                print("Error generating waveform: \(error)")
            }
        }
    }

    nonisolated private static func waveformCacheURL(for url: URL) -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Aries/Waveforms", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let key = url.standardizedFileURL.path
            .data(using: .utf8)
            .map { $0.base64EncodedString() } ?? UUID().uuidString
        return dir.appendingPathComponent("\(key).wf")
    }

    nonisolated private static func loadCachedWaveform(for url: URL) -> [Float]? {
        let cacheURL = waveformCacheURL(for: url)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              let cacheAttrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
              let cacheModified = cacheAttrs[.modificationDate] as? Date,
              cacheModified >= modified,
              let data = try? Data(contentsOf: cacheURL),
              data.count == 100 * MemoryLayout<Float>.size else { return nil }

        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    nonisolated private static func saveCachedWaveform(_ points: [Float], for url: URL) {
        let cacheURL = waveformCacheURL(for: url)
        let data = points.withUnsafeBufferPointer { Data(buffer: $0) }
        try? data.write(to: cacheURL, options: .atomic)
    }

    func updateCurrentTrackLyrics(with text: String) {
        guard let index = currentTrackIndex else { return }
        var track = queue[index]
        track.updateLyrics(from: text)
        queue[index] = track
    }

    private var autoFetchLyricsEnabled: Bool {
        UserDefaults.standard.object(forKey: "autoFetchLyrics") as? Bool ?? true
    }

    private func fetchLyricsIfNeeded(for index: Int) {
        lyricsFetchTask?.cancel()
        lyricsFetchTask = Task { await ensureLyrics(for: index) }
    }

    private func ensureLyrics(for index: Int) async {
        guard autoFetchLyricsEnabled else { return }
        guard queue.indices.contains(index) else { return }

        let trackID = queue[index].id
        let artist = queue[index].artist
        let title = queue[index].title
        let album = queue[index].album
        let trackDuration = queue[index].duration

        await MainActor.run { isFetchingLyrics = true }
        defer { Task { @MainActor in isFetchingLyrics = false } }

        if queue[index].lyrics == nil {
            var track = queue[index]
            await track.loadMetadata()
            await MainActor.run {
                guard currentTrackIndex == index, queue[index].id == trackID else { return }
                queue[index] = track
            }
        }

        if let lyrics = await MainActor.run(body: { queue[index].lyrics }), !lyrics.isEmpty {
            return
        }

        if let cached = LyricsCache.shared.lyrics(artist: artist, title: title) {
            await MainActor.run {
                guard currentTrackIndex == index, queue[index].id == trackID else { return }
                updateCurrentTrackLyrics(with: cached)
            }
            return
        }

        guard !Task.isCancelled else { return }

        do {
            let fetched = try await LRCLibService.shared.searchLyrics(
                trackName: title,
                artistName: artist,
                albumName: album,
                duration: trackDuration > 0 ? trackDuration : nil
            )
            guard let fetched, !Task.isCancelled else { return }

            LyricsCache.shared.store(artist: artist, title: title, lyrics: fetched)
            await MainActor.run {
                guard let currentIndex = currentTrackIndex,
                      queue[currentIndex].id == trackID else { return }
                updateCurrentTrackLyrics(with: fetched)
            }
        } catch {
            print("Auto lyrics fetch failed for \(artist) - \(title): \(error)")
        }
    }

    func checkAndShowLyricsEditor() {
        let path = MutagenInstallerService.mutagenTargetDirectory.appendingPathComponent("mutagen").path
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
            showLyricsEditor = true
        } else {
            showMutagenInstaller = true
        }
    }
}
