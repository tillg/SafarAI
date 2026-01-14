import SwiftUI

struct SettingsView: View {
    @Environment(AIService.self) private var aiService
    @Environment(ExtensionService.self) private var extensionService

    @State private var contentExtractionDelay: Double = 1000
    @State private var toolTimeout: Double = 10.0
    @State private var profileFormState: ProfileFormState?

    struct ProfileFormState: Identifiable {
        let id = UUID()
        let profile: LLMProfile?

        static func add() -> ProfileFormState {
            ProfileFormState(profile: nil)
        }

        static func edit(_ profile: LLMProfile) -> ProfileFormState {
            ProfileFormState(profile: profile)
        }
    }

    var body: some View {
        Form {
            Section("LLM Profiles") {
                if aiService.profiles.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("No profiles configured")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(aiService.profiles) { profile in
                        profileRow(profile)
                    }
                }

                Button("Add Profile") {
                    profileFormState = .add()
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
        .onAppear {
            contentExtractionDelay = UserDefaults.standard.double(forKey: "content_extraction_delay")
            if contentExtractionDelay == 0 {
                contentExtractionDelay = 1000 // Default
            }
            toolTimeout = UserDefaults.standard.double(forKey: "tool_timeout")
            if toolTimeout == 0 {
                toolTimeout = 10.0 // Default
            }
        }
        .sheet(item: $profileFormState) { formState in
            ProfileFormView(profile: formState.profile) { savedProfile, apiKey in
                if formState.profile != nil {
                    // Editing existing profile
                    aiService.updateProfile(savedProfile)
                } else {
                    // Adding new profile
                    aiService.addProfile(savedProfile)
                }

                if !apiKey.isEmpty {
                    aiService.saveAPIKey(apiKey, for: savedProfile)
                }
            }
            .environment(aiService)
        }
    }

    @ViewBuilder
    private func profileRow(_ profile: LLMProfile) -> some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(profile.displayColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(profile.name)
                        .font(.headline)

                    if aiService.activeProfile?.id == profile.id {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 4))
                            .foregroundStyle(.blue)
                    }
                }

                Text(profile.model)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Label(profile.baseURL, systemImage: "link")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if profile.hasAPIKey {
                        Image(systemName: "key.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if aiService.activeProfile?.id != profile.id {
                    Button("Use") {
                        aiService.switchProfile(to: profile)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Edit") {
                    profileFormState = ProfileFormState.edit(profile)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    aiService.deleteProfile(profile)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help("Delete profile")
                .disabled(aiService.profiles.count == 1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .environment(AIService())
        .environment(ExtensionService())
}
