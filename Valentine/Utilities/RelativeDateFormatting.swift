//
//  RelativeDateFormatting.swift
//  Aries
//

import Foundation

enum RelativeDateFormatting {
    static func lastPlayed(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0

        if days < 7 { return "\(days)d ago" }
        if days < 30 { return "\(days / 7)w ago" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
