import SwiftUI

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isLoading = false

    @Environment(ExtensionService.self) private var extensionService
    @Environment(AIService.self) private var aiService

    var body: some View {
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
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
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
