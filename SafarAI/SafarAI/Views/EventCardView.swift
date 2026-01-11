import SwiftUI

struct EventCardView: View {
    let event: BrowserEvent
    @State private var isExpanded = false
    @State private var showingPageContext = false
    @State private var showingFullPrompt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            HStack(spacing: 6) {
                Text(event.type.icon(isError: isToolError))
                    .font(.caption)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headerText)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(Color(nsColor: .labelColor))

                        Text(timeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Quick open button for URLs
                if let url = event.url, URL(string: url) != nil {
                    Button {
                        if let nsURL = URL(string: url) {
                            NSWorkspace.shared.open(nsURL)
                        }
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Open URL")
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.vertical, 4)

                    if let url = event.url, !url.isEmpty {
                        ClickableURLRow(label: "URL", url: url)
                    }

                    if let tabId = event.tabId {
                        DetailRow(label: "Tab ID", value: String(tabId))
                    }

                    if !event.details.isEmpty {
                        ForEach(Array(event.details.keys.sorted()), id: \.self) { key in
                            if let value = event.details[key] {
                                // Special handling for prompt - show with clickable [pagecontext]
                                if key == "prompt" {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Prompt:")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        PromptView(
                                            promptText: value,
                                            hasPageContext: event.details["hasPageContext"] == "true",
                                            onShowPageContext: { showingPageContext = true },
                                            onShowFullPrompt: { showingFullPrompt = true }
                                        )
                                    }
                                } else if key == "result" {
                                    // Special handling for tool results - highlight errors
                                    ResultRow(label: "Result", value: value, isError: isToolError)
                                } else if key != "fullPrompt" && key != "userMessage" && key != "pageContext" {
                                    // Skip internal fields, only show user-relevant ones
                                    DetailRow(label: key.capitalized, value: value)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 6))
        .sheet(isPresented: $showingPageContext) {
            PageContextSheet(pageContext: event.details["pageContext"] ?? "")
        }
        .sheet(isPresented: $showingFullPrompt) {
            FullPromptSheet(fullPrompt: event.details["fullPrompt"] ?? "")
        }
    }

    private var headerText: String {
        if let title = event.title, !title.isEmpty {
            return "\(event.type.displayName) → \(title)"
        } else if let url = event.url {
            // Extract domain from URL
            if let host = URL(string: url)?.host {
                return "\(event.type.displayName) → \(host)"
            }
            return event.type.displayName
        } else {
            return event.type.displayName
        }
    }

    private var timeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: event.timestamp, relativeTo: Date())
    }

    private var isToolError: Bool {
        // Check if this is a tool result with an error
        guard event.type == .toolResult else { return false }

        // Try to parse result as JSON and check for error field
        if let resultString = event.details["result"],
           let jsonData = resultString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

            // Check for explicit error field
            if json["error"] != nil {
                return true
            }

            // Check for empty text result
            if let text = json["text"] as? String, text.isEmpty {
                return true
            }

            // Check for zero-length text
            if let textLength = json["textLength"] as? Int, textLength == 0 {
                return true
            }
        }

        return false
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption2)
                .foregroundStyle(Color(nsColor: .labelColor))
                .lineLimit(3)

            Spacer(minLength: 0)
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption2)
                .foregroundStyle(isError ? .red : Color(nsColor: .labelColor))
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isError ? Color.red.opacity(0.1) : Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 4))
        }
    }
}

struct ClickableURLRow: View {
    let label: String
    let url: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                if let nsURL = URL(string: url) {
                    NSWorkspace.shared.open(nsURL)
                }
            } label: {
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .underline()
                    .lineLimit(3)
            }
            .buttonStyle(.plain)
            .help("Click to open in browser")

            Spacer(minLength: 0)
        }
    }
}

struct PromptView: View {
    let promptText: String
    let hasPageContext: Bool
    let onShowPageContext: () -> Void
    let onShowFullPrompt: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Parse and display prompt with clickable [pagecontext]
            if hasPageContext && promptText.contains("[pagecontext]") {
                HStack(alignment: .top, spacing: 4) {
                    Button {
                        onShowPageContext()
                    } label: {
                        Text("[pagecontext]")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .help("Click to view page context")

                    Text(promptText.replacingOccurrences(of: "[pagecontext]\n\n", with: ""))
                        .font(.caption2)
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .textSelection(.enabled)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 4))

                // Button to see full prompt
                Button {
                    onShowFullPrompt()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("View full prompt sent to LLM")
                            .font(.caption2)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } else {
                // No page context, just show text
                ScrollView {
                    Text(promptText)
                        .font(.caption2)
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 100)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 4))
            }
        }
    }
}

struct PageContextSheet: View {
    let pageContext: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Page Context")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                Text(pageContext)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct FullPromptSheet: View {
    let fullPrompt: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Full Prompt Sent to LLM")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                Text(fullPrompt)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    VStack(spacing: 8) {
        EventCardView(event: BrowserEvent(
            timestamp: Date().addingTimeInterval(-300),
            type: .tabSwitch,
            tabId: 123,
            url: "https://github.com",
            title: "GitHub",
            details: ["previousTabId": "122"]
        ))

        EventCardView(event: BrowserEvent(
            timestamp: Date().addingTimeInterval(-60),
            type: .pageLoad,
            tabId: 124,
            url: "https://anthropic.com",
            title: "Anthropic"
        ))

        EventCardView(event: BrowserEvent(
            timestamp: Date(),
            type: .linkClick,
            url: "https://example.com/page",
            title: "Example Link",
            details: ["currentUrl": "https://example.com", "opensInNewTab": "false"]
        ))
    }
    .padding()
    .frame(width: 300)
}
