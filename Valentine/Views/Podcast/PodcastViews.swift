//
//  PodcastViews.swift
//  Aries
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Home section

struct PodcastHomeSection: View {
    @ObservedObject var podcastStore: PodcastStore
    @ObservedObject var engine: AudioEngine
    let accent: Color
    var onViewAll: () -> Void

    private var recentEpisodes: [PodcastEpisode] {
        Array(podcastStore.newEpisodes.prefix(8))
    }

    var body: some View {
        HomeSectionRow(title: "New Episodes") {
            if podcastStore.feeds.isEmpty {
                Text("Subscribe to podcasts from the Podcasts section in the sidebar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if recentEpisodes.isEmpty {
                Text("No new episodes. Use Refresh in the Podcasts browser.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(recentEpisodes) { episode in
                            if let feed = podcastStore.feed(for: episode.feedID) {
                                PodcastEpisodeTile(
                                    episode: episode,
                                    feed: feed,
                                    accent: accent,
                                    artworkURL: podcastStore.artworkURL(for: feed),
                                    isDownloading: podcastStore.isDownloadingEpisode == episode.id,
                                    onPlay: {
                                        let feedEpisodes = podcastStore.episodes(for: feed)
                                        let index = feedEpisodes.firstIndex(where: { $0.id == episode.id }) ?? 0
                                        engine.playPodcastEpisodes(feedEpisodes, startIndex: index, feed: feed, store: podcastStore)
                                    }
                                )
                            }
                        }
                    }
                }
                .scrollClipDisabled()

                Button("View All Podcasts", action: onViewAll)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: podcastStore.feeds.isEmpty ? nil : 200)
    }
}

private struct PodcastEpisodeTile: View {
    let episode: PodcastEpisode
    let feed: PodcastFeed
    let accent: Color
    let artworkURL: URL?
    let isDownloading: Bool
    let onPlay: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onPlay) {
                    CachedArtwork(url: artworkURL, size: 110, rounded: false)
                        .scaleEffect(isHovered ? 1.02 : 1)
                }
                .buttonStyle(.plain)

                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                } else if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(accent.opacity(0.95), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                Text(feed.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 110, alignment: .leading)
        }
        .frame(width: 110)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Browser

struct PodcastBrowserView: View {
    @ObservedObject var podcastStore: PodcastStore
    @ObservedObject var engine: AudioEngine
    let accent: Color
    var onOpenFeed: (PodcastFeed) -> Void

    @State private var showAddSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Podcasts")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                    Spacer()
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Subscribe", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        importOPML()
                    } label: {
                        Label("Import OPML", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        Task { await podcastStore.refreshAllFeeds() }
                    } label: {
                        if podcastStore.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(podcastStore.isRefreshing)
                }
                .padding(.top, 24)

                if podcastStore.feeds.isEmpty {
                    LibraryEmptySectionHint(
                        icon: "mic.fill",
                        title: "No Podcasts",
                        message: "Subscribe to an RSS feed to stream and download episodes.",
                        actionTitle: "Subscribe to Feed",
                        action: { showAddSheet = true }
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 20) {
                        ForEach(podcastStore.feeds) { feed in
                            PodcastFeedCard(
                                feed: feed,
                                accent: accent,
                                artworkURL: podcastStore.artworkURL(for: feed),
                                episodeCount: podcastStore.episodes(for: feed).count,
                                onOpen: { onOpenFeed(feed) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .sheet(isPresented: $showAddSheet) {
            AddPodcastSheet(podcastStore: podcastStore)
        }
    }

    private func importOPML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            _ = try? await podcastStore.subscribeOPML(at: url)
        }
    }
}

private struct PodcastFeedCard: View {
    let feed: PodcastFeed
    let accent: Color
    let artworkURL: URL?
    let episodeCount: Int
    let onOpen: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                CachedArtwork(url: artworkURL, size: 160, rounded: false)
                    .scaleEffect(isHovered ? 1.02 : 1)
                Text(feed.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(episodeCount) episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Feed detail

struct PodcastFeedDetailView: View {
    let feed: PodcastFeed
    @ObservedObject var podcastStore: PodcastStore
    @ObservedObject var engine: AudioEngine
    let accent: Color
    let onBack: () -> Void

    private var feedEpisodes: [PodcastEpisode] {
        podcastStore.episodes(for: feed)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Label("Podcasts", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                }
                .padding(.top, 24)

                HStack(alignment: .top, spacing: 20) {
                    CachedArtwork(url: podcastStore.artworkURL(for: feed), size: 180, rounded: false)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(feed.title)
                            .font(.system(size: 28, weight: .regular, design: .serif))
                        if let author = feed.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let description = feed.feedDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        HStack(spacing: 12) {
                            Button {
                                guard !feedEpisodes.isEmpty else { return }
                                engine.playPodcastEpisodes(feedEpisodes, startIndex: 0, feed: feed, store: podcastStore)
                            } label: {
                                Label("Play Latest", systemImage: "play.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(accent, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(feedEpisodes.isEmpty)

                            Button(role: .destructive) {
                                podcastStore.unsubscribe(feed)
                                onBack()
                            } label: {
                                Label("Unsubscribe", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Text("Episodes")
                    .font(.title3.weight(.semibold))

                LazyVStack(spacing: 2) {
                    ForEach(Array(feedEpisodes.enumerated()), id: \.element.id) { index, episode in
                        PodcastEpisodeRow(
                            episode: episode,
                            accent: accent,
                            isDownloading: podcastStore.isDownloadingEpisode == episode.id,
                            onPlay: {
                                engine.playPodcastEpisodes(feedEpisodes, startIndex: index, feed: feed, store: podcastStore)
                            },
                            onMarkPlayed: {
                                podcastStore.markEpisodePlayed(episode.id)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

private struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let accent: Color
    let isDownloading: Bool
    let onPlay: () -> Void
    let onMarkPlayed: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                Image(systemName: episode.isPlayed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(episode.isPlayed ? .secondary : accent)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(episode.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    if let date = episode.publishDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if isDownloading {
                    ProgressView().controlSize(.small)
                } else if let duration = episode.duration {
                    Text(duration.formatTime())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if isHovered {
                    Button(action: onMarkPlayed) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Mark as played")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? accent.opacity(0.08) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Add subscription

struct AddPodcastSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var podcastStore: PodcastStore

    @State private var feedURL = ""
    @State private var isSubscribing = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscribe to Podcast")
                .font(.headline)
            Text("Enter the RSS feed URL for the podcast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("https://example.com/feed.xml", text: $feedURL)
                .textFieldStyle(.roundedBorder)
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Subscribe") { subscribe() }
                    .buttonStyle(.borderedProminent)
                    .disabled(feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubscribing)
            }
        }
        .padding(24)
        .frame(width: 420)
        .overlay {
            if isSubscribing {
                ProgressView("Fetching feed…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func subscribe() {
        isSubscribing = true
        errorMessage = nil
        Task {
            do {
                try await podcastStore.subscribe(feedURLString: feedURL)
                await MainActor.run {
                    isSubscribing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubscribing = false
                }
            }
        }
    }
}
