import SwiftUI

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isLoading = false

    @Environment(ExtensionService.self) private var extensionService
    @Environment(AIService.self) private var aiService

    var body: some View {
        HStack(spacing: 0) {
            // Main chat area
            VStack(spacing: 0) {
                // Header
                headerView

                // Page context banner
                if let page = extensionService.pageContent {
                    pageContextBanner(page)
                }

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
            extensionService.requestPageContent()
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

            Button("Refresh", systemImage: "arrow.clockwise") {
                extensionService.requestPageContent()
            }
            .buttonStyle(.plain)
            .help("Refresh page content")
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pageContextBanner(_ page: PageContent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.fill")
                .foregroundStyle(Color.blue)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title)
                    .font(.caption)
                    .lineLimit(1)
                Text(page.url)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Remove", systemImage: "xmark.circle.fill") {
                extensionService.pageContent = nil
            }
            .buttonStyle(.plain)
            .font(.caption)
            .labelStyle(.iconOnly)
            .help("Remove page context")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
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
            if let content = extensionService.pageContent {
                // Page context available
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)

                    Text("Page context available")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(content.text.count) chars")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .clipShape(.rect(cornerRadius: 6))
            } else if extensionService.currentTabUrl != nil {
                // Tab is open but content extraction failed
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)

                    Text("Page context unavailable (content script failed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        extensionService.requestPageContent()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Retry content extraction")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(.rect(cornerRadius: 6))
            } else {
                // No tab
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text("No page loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
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

        // Capture page context snapshot for logging
        let pageContextSnapshot: String?
        if let content = extensionService.pageContent {
            print("✅ Page content available: \(content.title)")
            pageContextSnapshot = """
            [Page Context]
            Title: \(content.title)
            URL: \(content.url)
            \(content.description.map { "Description: \($0)\n" } ?? "")Content: \(content.text)
            """
        } else {
            print("❌ No page content available when sending query")
            print("   Current tab URL: \(extensionService.currentTabUrl ?? "nil")")
            print("   Current tab title: \(extensionService.currentTabTitle ?? "nil")")
            pageContextSnapshot = nil
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
                pageContent: extensionService.pageContent
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
}

#Preview {
    ContentView()
        .environment(ExtensionService())
        .environment(AIService())
        .frame(width: 400, height: 600)
}
