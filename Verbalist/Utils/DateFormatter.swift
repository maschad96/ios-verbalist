//
//  DateFormatter.swift
//  Verbalist
//
//  Created by Matt Schad on 6/1/25.
//

import Foundation

struct DateFormatters {
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    static func formatRelative(date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.component(.day, from: date) - calendar.component(.day, from: now) < 7 {
            return relativeFormatter.localizedString(for: date, relativeTo: now)
        } else {
            return displayFormatter.string(from: date)
        }
    }
}