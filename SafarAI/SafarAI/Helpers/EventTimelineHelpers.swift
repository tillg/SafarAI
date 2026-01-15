import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Helper functions for event timeline functionality.
/// These functions are extracted for testability.
enum EventTimelineHelpers {

    /// Groups browser events by day, returning an array of (date, events) tuples.
    /// Events are assumed to be sorted chronologically.
    ///
    /// - Parameter events: Array of BrowserEvent to group
    /// - Returns: Array of tuples containing the start of day date and events for that day
    static func groupEventsByDay(_ events: [BrowserEvent]) -> [(date: Date, events: [BrowserEvent])] {
        guard !events.isEmpty else { return [] }

        let calendar = Calendar.current
        var groups: [(date: Date, events: [BrowserEvent])] = []
        var currentDay: Date?
        var currentEvents: [BrowserEvent] = []

        for event in events {
            let eventDay = calendar.startOfDay(for: event.timestamp)

            if let day = currentDay, calendar.isDate(day, inSameDayAs: eventDay) {
                currentEvents.append(event)
            } else {
                if !currentEvents.isEmpty, let day = currentDay {
                    groups.append((date: day, events: currentEvents))
                }
                currentDay = eventDay
                currentEvents = [event]
            }
        }

        // Add the last group
        if !currentEvents.isEmpty, let day = currentDay {
            groups.append((date: day, events: currentEvents))
        }

        return groups
    }

    /// Formats a date for display as a day separator.
    /// Returns "Today", "Yesterday", or a formatted date like "Sat 23.1.2026"
    ///
    /// - Parameter date: The date to format
    /// - Returns: Formatted string for the day separator
    static func formatDaySeparator(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "E d.M.yyyy"  // e.g., "Sat 23.1.2026"
            return formatter.string(from: date)
        }
    }

    /// Formats a timestamp for display in event cards.
    /// Returns time in HH:mm format, e.g., "14:32"
    ///
    /// - Parameter date: The date to format
    /// - Returns: Formatted time string
    static func formatEventTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Icon Validation

extension BrowserEvent.EventType {

    /// All valid SF Symbol names used by event icons.
    /// Can be used for validation in tests.
    static var allIconSymbols: Set<String> {
        var symbols: Set<String> = []

        for eventType in [
            BrowserEvent.EventType.aiQuery,
            .aiResponse,
            .toolCall,
            .toolResult,
            .tabOpen,
            .tabClose,
            .tabSwitch,
            .pageLoad,
            .linkClick
        ] {
            let icon = eventType.icon(isError: false)
            symbols.insert(icon.base)
            if let direction = icon.direction {
                symbols.insert(direction)
            }

            // Also check error variant for tool results
            if eventType == .toolResult {
                let errorIcon = eventType.icon(isError: true)
                if let errorDirection = errorIcon.direction {
                    symbols.insert(errorDirection)
                }
            }
        }

        return symbols
    }

    /// Validates that all SF Symbol names used by icons are valid.
    /// Returns true if all symbols exist in the system.
    ///
    /// Note: This requires AppKit to verify symbols exist.
    /// In unit tests, you may want to mock this or use a known list.
    static func validateIconSymbols() -> Bool {
        #if canImport(AppKit)
        for symbol in allIconSymbols {
            if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) == nil {
                return false
            }
        }
        return true
        #else
        // On other platforms, assume valid
        return true
        #endif
    }
}
