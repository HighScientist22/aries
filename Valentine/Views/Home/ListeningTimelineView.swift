//
//  ListeningTimelineView.swift
//  Aries
//

import SwiftUI

struct ListeningTimelineView: View {
    let days: [ListeningTimelineDay]
    let accent: Color
    let artworkURL: (LibraryTrack) -> URL?
    var onPlayTrack: ((LibraryTrack) -> Void)? = nil
    var onOpenAlbum: ((LibraryTrack) -> Void)? = nil
    var maxDays: Int = 14

    @State private var expandedDays: Set<String> = []

    private var visibleDays: [ListeningTimelineDay] {
        Array(days.prefix(maxDays))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listening History")
                .font(.headline)

            if visibleDays.isEmpty {
                Text("Your play timeline will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(visibleDays) { day in
                        daySection(day)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func daySection(_ day: ListeningTimelineDay) -> some View {
        let isExpanded = expandedDays.contains(day.id)
        let visibleItems = isExpanded ? day.items : Array(day.items.prefix(12))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayLabel(for: day.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(day.items.count) plays")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                ForEach(visibleItems) { item in
                    timelineRow(item)
                }

                if day.items.count > 12 {
                    Button(isExpanded ? "Show Less" : "Show \(day.items.count - 12) More") {
                        if isExpanded {
                            expandedDays.remove(day.id)
                        } else {
                            expandedDays.insert(day.id)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.top, 2)
                }
            }
        }
    }

    private func timelineRow(_ item: ListeningTimelineItem) -> some View {
        HStack(spacing: 12) {
            Button {
                onPlayTrack?(item.track)
            } label: {
                HStack(spacing: 12) {
                    CachedArtwork(url: artworkURL(item.track), size: 36, rounded: false)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Text(timeLabel(item.playedAt))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.track.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(item.track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(item.track.duration.formatTime())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onOpenAlbum {
                Button(action: { onOpenAlbum(item.track) }) {
                    Image(systemName: "square.stack")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Album")
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
