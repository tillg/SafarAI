import SwiftUI

struct SettingsView: View {
    @Environment(AIService.self) private var aiService
    @Environment(ExtensionService.self) private var extensionService

    @State private var apiKey: String = ""
    @State private var contentExtractionDelay: Double = 1000
    @State private var toolTimeout: Double = 10.0

    var body: some View {
        Form {
            Section("AI Provider") {
                Picker("Provider", selection: Binding(
                    get: { aiService.provider },
                    set: { aiService.provider = $0 }
                )) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                TextField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    aiService.apiKey = apiKey
                    aiService.saveSettings()
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Extension") {
                LabeledContent("Status") {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(extensionService.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(extensionService.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                    }
                }

                Button("Test Connection") {
                    extensionService.ping()
                }
            }

            Section("Page Content") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Extraction Delay:")
                        Spacer()
                        Text("\(Int(contentExtractionDelay))ms")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $contentExtractionDelay, in: 0...5000, step: 100)

                    Text("Delay after page loads before extracting content. Increase for sites with heavy lazy-loading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Save Delay") {
                        UserDefaults.standard.set(contentExtractionDelay, forKey: "content_extraction_delay")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tool Timeout:")
                        Spacer()
                        Text("\(Int(toolTimeout))s")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $toolTimeout, in: 1...30, step: 1)

                    Text("Maximum time to wait for tool execution. Tools that take longer will show a timeout error.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Save Timeout") {
                        UserDefaults.standard.set(toolTimeout, forKey: "tool_timeout")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                if let page = extensionService.pageContent {
                    LabeledContent("Current Page") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(page.title)
                                .font(.caption)
                            Text(page.url)
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            if page.markdown != nil {
                                Text("(Markdown)")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Text("(Plain text)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                } else {
                    Text("No page loaded")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .onAppear {
            apiKey = aiService.apiKey
            contentExtractionDelay = UserDefaults.standard.double(forKey: "content_extraction_delay")
            if contentExtractionDelay == 0 {
                contentExtractionDelay = 1000 // Default
            }
            toolTimeout = UserDefaults.standard.double(forKey: "tool_timeout")
            if toolTimeout == 0 {
                toolTimeout = 10.0 // Default
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AIService())
        .environment(ExtensionService())
}
