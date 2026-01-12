import SwiftUI

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var faviconImage: NSImage?

    @Environment(ExtensionService.self) private var extensionService
    @Environment(AIService.self) private var aiService

    var body: some View {
        HStack(spacing: 0) {
            // Main chat area
            VStack(spacing: 0) {
                // Header
                headerView

                Divider()

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                emptyStateView
                            } else {
                                ForEach(messages) { message in
                                    MessageView(message: message)
                                        .id(message.id)
                                }
                            }

                            if isLoading {
                                loadingView
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input
                inputView
            }

            Divider()

            // Event timeline on the right
            EventTimelineView(
                events: extensionService.events,
                eventsLogURL: extensionService.eventsLogURL
            )
            .frame(width: 250)
        }
        .onAppear {
            // Wire up tool executor
            let executor = ToolExecutor(extensionService: extensionService)
            aiService.setToolExecutor(executor)

            // Ping extension to initiate connection
            extensionService.ping()
        }
        .onChange(of: extensionService.pageContent) { oldValue, newValue in
            // Extract favicon from page content
            print("🔄 Page content changed")
            if let content = newValue {
                print("📄 New content: \(content.title)")
                if let faviconDataUrl = content.faviconData, !faviconDataUrl.isEmpty {
                    print("🖼️ Extracting favicon from base64 data...")
                    extractFaviconImage(from: faviconDataUrl)
                } else {
                    print("⚠️ No favicon data in page content")
                    faviconImage = nil
                }
            } else {
                print("⚠️ Page content is nil, clearing favicon")
                faviconImage = nil
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("SafarAI")
                .font(.headline)

            if extensionService.isConnected {
                Image(systemName: "circle.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.green)
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            if let page = extensionService.pageContent {
                Text("Ask me anything about:")
                    .font(.headline)
                Text(page.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No page content loaded")
                    .font(.headline)
                Text("Open a webpage in Safari")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    private var inputView: some View {
        VStack(spacing: 8) {
            // Page context status indicator
            pageContextIndicator

            HStack(spacing: 8) {
                TextField("Ask me anything...", text: $input, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(.rect(cornerRadius: 8))
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }

                Button("Send", systemImage: "arrow.up.circle.fill") {
                    sendMessage()
                }
                .buttonStyle(.plain)
                .font(.title2)
                .foregroundStyle(input.isEmpty ? .secondary : Color.blue)
                .disabled(input.isEmpty || isLoading)
                .help("Send message")
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var pageContextIndicator: some View {
        Group {
            if !extensionService.isConnected {
                // Extension not connected
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Safari Extension Not Connected")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Make sure the SafarAI extension is enabled in Safari")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        extensionService.ping()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Retry connection")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))
            } else if let content = extensionService.pageContent {
                // Page content loaded - show page title
                HStack(spacing: 6) {
                    // Favicon or fallback icon
                    if let favicon = faviconImage {
                        Image(nsImage: favicon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    } else {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(content.title.isEmpty ? "Page content available" : content.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let url = URL(string: content.url), let host = url.host {
                            Text(host)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text("\(content.text.count) chars")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
                .clipShape(.rect(cornerRadius: 6))
            } else {
                // Connected but no content - could be loading or no tab open
                HStack(spacing: 6) {
                    if extensionService.currentTabUrl != nil {
                        // Tab is open, content might be loading
                        ProgressView()
                            .scaleEffect(0.6)
                            .controlSize(.small)

                        Text("Loading page content...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        // No tab open
                        Image(systemName: "safari")
                            .foregroundStyle(.blue)
                            .font(.caption)

                        Text("Open a webpage in Safari")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(.rect(cornerRadius: 6))
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.7)
                .controlSize(.small)
            Text("Thinking...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }

        let userMessage = Message(role: .user, content: input)
        messages.append(userMessage)

        // Capture page context snapshot for logging (only if enabled)
        let pageContextSnapshot: String?
        let pageContentToSend: PageContent?

        if let content = extensionService.pageContent {
            pageContextSnapshot = """
            [Page Context]
            Title: \(content.title)
            URL: \(content.url)
            \(content.description.map { "Description: \($0)\n" } ?? "")Content:
            \(content.contentForLLM)
            """
            pageContentToSend = content
        } else {
            pageContextSnapshot = nil
            pageContentToSend = nil
        }

        // Build full prompt as it will be sent to LLM
        let fullPrompt: String
        if let context = pageContextSnapshot {
            fullPrompt = """
            \(context)

            [User Question]
            \(input)
            """
        } else {
            fullPrompt = input
        }

        // Log AI query event with full context
        extensionService.logAIQuery(
            userMessage: input,
            fullPrompt: fullPrompt,
            pageContextSnapshot: pageContextSnapshot
        )

        input = ""
        isLoading = true

        Task {
            let response = await aiService.chat(
                messages: messages,
                pageContent: pageContentToSend // Use checkbox-controlled value
            )

            isLoading = false

            if let response = response {
                let aiMessage = Message(role: .assistant, content: response)
                messages.append(aiMessage)

                // Log AI response event
                extensionService.logAIResponse(
                    responseLength: response.count,
                    model: "\(aiService.provider.rawValue)/\(aiService.model)"
                )
            }
        }
    }

    private func extractFaviconImage(from dataUrl: String) {
        // Extract base64 image data (same logic as screenshots)
        guard let range = dataUrl.range(of: "base64,") else {
            print("❌ No base64 data in favicon")
            faviconImage = nil
            return
        }

        let base64String = String(dataUrl[range.upperBound...])
        guard let imageData = Data(base64Encoded: base64String),
              let image = NSImage(data: imageData) else {
            print("❌ Failed to decode favicon base64 data")
            faviconImage = nil
            return
        }

        print("✅ Created favicon NSImage: \(image.size.width)x\(image.size.height)")
        faviconImage = image
    }
}

#Preview {
    ContentView()
        .environment(ExtensionService())
        .environment(AIService())
        .frame(width: 400, height: 600)
}
