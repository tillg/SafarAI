import SwiftUI

struct EventTimelineView: View {
    let events: [BrowserEvent]
    let eventsLogURL: URL

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
                            ForEach(events) { event in
                                EventCardView(event: event)
                                    .id(event.id)
                            }
                        }
                        .padding(8)
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

#Preview {
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
