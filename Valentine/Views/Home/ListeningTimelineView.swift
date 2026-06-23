//
//  ListeningTimelineView.swift
//  Aries
//

import SwiftUI

struct ListeningTimelineView: View {
    let days: [ListeningTimelineDay]
    let accent: Color
    var onSelectTrack: ((LibraryTrack) -> Void)? = nil
    var maxDays: Int = 14

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
        VStack(alignment: .leading, spacing: 10) {
            Text(dayLabel(for: day.date))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 6) {
                ForEach(day.items.prefix(12)) { item in
                    Button {
                        onSelectTrack?(item.track)
                    } label: {
                        HStack(spacing: 12) {
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
                }
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
