import SwiftUI

struct EventTimelineView: View {
    let events: [BrowserEvent]
    let eventsLogURL: URL
    var expandedEventIDs: Set<UUID> = []

    /// Groups events by day for rendering with separators
    private var eventsByDay: [(date: Date, events: [BrowserEvent])] {
        EventTimelineHelpers.groupEventsByDay(events)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Events")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                // Link to open log file
                Button {
                    NSWorkspace.shared.selectFile(eventsLogURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "doc.text")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .help("Show events log file in Finder")

                Text("\(events.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(.capsule)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Events list
            if events.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(eventsByDay.enumerated()), id: \.element.date) { _, dayGroup in
                                DaySeparatorView(date: dayGroup.date)

                                ForEach(dayGroup.events) { event in
                                    EventCardView(
                                        event: event,
                                        initiallyExpanded: expandedEventIDs.contains(event.id)
                                    )
                                    .id(event.id)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onAppear {
                        // Scroll to bottom on first load
                        if let lastEvent = events.last {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(lastEvent.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: events.count) { _, _ in
                        // Auto-scroll to bottom when new event is added
                        if let lastEvent = events.last {
                            withAnimation {
                                proxy.scrollTo(lastEvent.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No events yet")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Browse the web to see events")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }
}

/// Day separator shown between events from different days
struct DaySeparatorView: View {
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    private var formattedDate: String {
        EventTimelineHelpers.formatDaySeparator(for: date)
    }
}

#Preview("With Day Separators") {
    HStack(spacing: 0) {
        Color.blue.opacity(0.1)
            .frame(width: 300)
            .overlay {
                Text("Chat Area")
                    .foregroundStyle(.secondary)
            }

        Divider()

        EventTimelineView(
            events: [
                // Events from 3 days ago
                BrowserEvent(
                    timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date())!.addingTimeInterval(-7200),
                    type: .tabOpen,
                    tabId: 100,
                    url: "https://swift.org",
                    title: "Swift.org"
                ),
                BrowserEvent(
                    timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date())!.addingTimeInterval(-3600),
                    type: .aiQuery,
                    details: ["prompt": "What is Swift?"]
                ),
                // Events from yesterday
                BrowserEvent(
                    timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!.addingTimeInterval(-7200),
                    type: .tabOpen,
                    tabId: 110,
                    url: "https://developer.apple.com",
                    title: "Apple Developer"
                ),
                BrowserEvent(
                    timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!.addingTimeInterval(-3600),
                    type: .toolCall,
                    details: ["tool": "get_page_content"]
                ),
                BrowserEvent(
                    timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!.addingTimeInterval(-3500),
                    type: .toolResult,
                    details: ["result": "{\"error\": \"Timeout\"}"]
                ),
                // Events from today
                BrowserEvent(
                    timestamp: Date().addingTimeInterval(-600),
                    type: .tabOpen,
                    tabId: 120,
                    url: "https://apple.com",
                    title: "Apple"
                ),
                BrowserEvent(
                    timestamp: Date().addingTimeInterval(-300),
                    type: .tabSwitch,
                    tabId: 123,
                    url: "https://github.com",
                    title: "GitHub",
                    details: ["previousTabId": "122"]
                ),
                BrowserEvent(
                    timestamp: Date().addingTimeInterval(-60),
                    type: .pageLoad,
                    tabId: 124,
                    url: "https://anthropic.com",
                    title: "Anthropic"
                ),
                BrowserEvent(
                    timestamp: Date(),
                    type: .linkClick,
                    url: "https://example.com/page",
                    title: "Example Link",
                    details: ["currentUrl": "https://example.com"]
                )
            ],
            eventsLogURL: URL(fileURLWithPath: "/tmp/browser_events.log")
        )
        .frame(width: 250)
    }
    .frame(height: 600)
}
