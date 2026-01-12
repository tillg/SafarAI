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
                                    // Check if this is a screenshot result
                                    if isScreenshotResult(value) {
                                        ImageResultRow(
                                            label: "Result",
                                            resultJson: value,
                                            onTap: {
                                                if let image = extractImageFromResult(value) {
                                                    openScreenshotWindow(image: image)
                                                }
                                            }
                                        )
                                    } else {
                                        // Special handling for tool results - highlight errors
                                        ResultRow(label: "Result", value: value, isError: isToolError)
                                    }
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

    private func isScreenshotResult(_ resultString: String) -> Bool {
        guard let jsonData = resultString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return false
        }
        return json["imageDataUrl"] != nil
    }

    private func extractImageFromResult(_ resultString: String) -> NSImage? {
        guard let jsonData = resultString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let dataUrl = json["imageDataUrl"] as? String else {
            return nil
        }

        return imageFromDataURL(dataUrl)
    }

    private func imageFromDataURL(_ dataUrl: String) -> NSImage? {
        guard let range = dataUrl.range(of: "base64,") else {
            return nil
        }

        let base64String = String(dataUrl[range.upperBound...])

        guard let imageData = Data(base64Encoded: base64String),
              let image = NSImage(data: imageData) else {
            return nil
        }

        return image
    }

    private func openScreenshotWindow(image: NSImage) {
        let contentView = ScreenshotWindowView(image: image)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Screenshot"
        window.setContentSize(NSSize(width: 900, height: 700))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.isReleasedWhenClosed = false
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

struct ImageResultRow: View {
    let label: String
    let resultJson: String
    let onTap: () -> Void

    private var thumbnailImage: NSImage? {
        guard let jsonData = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let dataUrl = json["imageDataUrl"] as? String,
              let range = dataUrl.range(of: "base64,") else {
            return nil
        }

        let base64String = String(dataUrl[range.upperBound...])

        guard let imageData = Data(base64Encoded: base64String) else {
            return nil
        }

        return NSImage(data: imageData)
    }

    private var imageInfo: String {
        guard let jsonData = resultJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let dimensions = json["dimensions"] as? [String: Any],
              let width = dimensions["width"] as? Int,
              let height = dimensions["height"] as? Int else {
            return "Screenshot"
        }
        return "\(width)×\(height) PNG"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                onTap()
            } label: {
                HStack(spacing: 8) {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                            .clipShape(.rect(cornerRadius: 4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screenshot captured")
                            .font(.caption2)
                            .foregroundStyle(.primary)

                        Text(imageInfo)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("Click to view full size")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(.rect(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Click to view full size screenshot")
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

struct ErrorView: View {
    let message: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Error: Image not available")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Close") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}

struct ScreenshotWindowView: View {
    let image: NSImage
    @State private var scale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Screenshot")
                    .font(.headline)

                Text("(\(Int(image.size.width))×\(Int(image.size.height)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Zoom controls
                HStack(spacing: 8) {
                    Button {
                        scale = max(0.1, scale - 0.1)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .help("Zoom out")

                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .frame(width: 50)

                    Button {
                        scale = min(3.0, scale + 0.1)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .help("Zoom in")

                    Button {
                        scale = 1.0
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Reset zoom")
                }
            }
            .padding()

            Divider()

            // Image
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: image.size.width * scale,
                            height: image.size.height * scale
                        )
                        .frame(
                            minWidth: geometry.size.width,
                            minHeight: geometry.size.height,
                            alignment: .center
                        )
                }
            }
        }
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
