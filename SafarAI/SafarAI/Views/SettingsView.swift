import SwiftUI

struct SettingsView: View {
    @Environment(AIService.self) private var aiService
    @Environment(ExtensionService.self) private var extensionService

    @State private var apiKey: String = ""

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
                if let page = extensionService.pageContent {
                    LabeledContent("Current Page") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(page.title)
                                .font(.caption)
                            Text(page.url)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
        }
    }
}

#Preview {
    SettingsView()
        .environment(AIService())
        .environment(ExtensionService())
}
