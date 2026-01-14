import SwiftUI

struct ProfileFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AIService.self) private var aiService

    @State private var name: String
    @State private var baseURL: String
    @State private var apiKey: String
    @State private var selectedModel: String
    @State private var maxTokens: Int
    @State private var contextLimit: Int
    @State private var selectedColor: String
    @State private var selectedPreset: LLMProfile.Preset?

    @State private var availableModels: [LLMModel] = []
    @State private var isTestingConnection: Bool = false
    @State private var isFetchingModels: Bool = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var showManualModelEntry: Bool = false

    let profile: LLMProfile?
    let onSave: (LLMProfile, String) -> Void

    enum ConnectionStatus {
        case idle
        case success(modelCount: Int)
        case failed(error: String)

        var color: Color {
            switch self {
            case .idle: return .secondary
            case .success: return .green
            case .failed: return .red
            }
        }

        var icon: String {
            switch self {
            case .idle: return "circle"
            case .success: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }

        var message: String {
            switch self {
            case .idle: return ""
            case .success(let count): return "Connection successful. Found \(count) models"
            case .failed(let error): return "Connection failed: \(error)"
            }
        }
    }

    init(profile: LLMProfile? = nil, onSave: @escaping (LLMProfile, String) -> Void) {
        self.profile = profile
        self.onSave = onSave

        _name = State(initialValue: profile?.name ?? "")
        _baseURL = State(initialValue: profile?.baseURL ?? "https://api.openai.com/v1")
        _apiKey = State(initialValue: "")
        _selectedModel = State(initialValue: profile?.model ?? "")
        _maxTokens = State(initialValue: profile?.maxTokens ?? 4096)
        _contextLimit = State(initialValue: profile?.contextLimit ?? 16384)
        _selectedColor = State(initialValue: profile?.color ?? "red")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(profile == nil ? "Add Profile" : "Edit Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Profile Details") {
                    TextField("Profile Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    // Preset selector
                    Picker("Provider Preset", selection: $selectedPreset) {
                        Text("Select a provider...").tag(nil as LLMProfile.Preset?)
                        ForEach(LLMProfile.presets) { preset in
                            Text(preset.name).tag(preset as LLMProfile.Preset?)
                        }
                    }
                    .onChange(of: selectedPreset) { _, newValue in
                        if let preset = newValue, preset.name != "Custom" {
                            baseURL = preset.baseURL
                            if name.isEmpty {
                                name = preset.name
                            }
                        }
                    }

                    TextField("Base URL", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                        .help("API endpoint (e.g., https://api.openai.com/v1)")

                    SecureField("API Key (optional)", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .help("Leave empty for local endpoints")

                    HStack {
                        Button(action: testConnection) {
                            HStack(spacing: 6) {
                                if isTestingConnection {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .controlSize(.small)
                                }
                                Text("Test Connection")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(baseURL.isEmpty || isTestingConnection)

                        if case .success = connectionStatus {
                            Image(systemName: connectionStatus.icon)
                                .foregroundStyle(connectionStatus.color)
                        } else if case .failed = connectionStatus {
                            Image(systemName: connectionStatus.icon)
                                .foregroundStyle(connectionStatus.color)
                        }

                        Spacer()
                    }

                    if !connectionStatus.message.isEmpty {
                        Text(connectionStatus.message)
                            .font(.caption)
                            .foregroundStyle(connectionStatus.color)
                    }
                }

                Section("Model Configuration") {
                    if !availableModels.isEmpty && !showManualModelEntry {
                        Picker("Model", selection: $selectedModel) {
                            if selectedModel.isEmpty {
                                Text("Select a model...").tag("")
                            }
                            ForEach(availableModels) { model in
                                Text(model.displayName).tag(model.id)
                            }
                        }

                        Button("Enter model manually") {
                            showManualModelEntry = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    } else {
                        TextField("Model", text: $selectedModel)
                            .textFieldStyle(.roundedBorder)
                            .help("Model identifier (e.g., gpt-4-turbo)")

                        if !availableModels.isEmpty {
                            Button("Select from available models") {
                                showManualModelEntry = false
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                        }
                    }

                    if availableModels.isEmpty && !isTestingConnection {
                        Text("Test connection to load available models")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max Tokens:")
                            Spacer()
                            Text("\(maxTokens)")
                                .foregroundStyle(.secondary)

                            if let limit = getModelTokenLimit(selectedModel) {
                                Button("Set to max") {
                                    maxTokens = limit
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }

                        Slider(value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ), in: 256...32768, step: 256)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Maximum tokens for response (default: 4096)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !selectedModel.isEmpty {
                                if let limit = getModelTokenLimit(selectedModel) {
                                    Text("Note: \(selectedModel) supports up to \(limit) completion tokens")
                                        .font(.caption)
                                        .foregroundStyle(maxTokens > limit ? .orange : .green)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Check your provider's docs for \(selectedModel)'s token limits")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Context Limit:")
                            Spacer()
                            Text("\(contextLimit)")
                                .foregroundStyle(.secondary)

                            if let limit = getModelContextLimit(selectedModel) {
                                Button("Set to model default") {
                                    contextLimit = limit
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }

                        Slider(value: Binding(
                            get: { Double(contextLimit) },
                            set: { contextLimit = Int($0) }
                        ), in: 1024...131072, step: 1024)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total context window size (input + output tokens)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !selectedModel.isEmpty {
                                if let limit = getModelContextLimit(selectedModel) {
                                    Text("Note: \(selectedModel) has \(limit) token context window")
                                        .font(.caption)
                                        .foregroundStyle(contextLimit == limit ? .green : .orange)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Check your provider's docs for \(selectedModel)'s context limit")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }

                Section("Visual") {
                    Picker("Color", selection: $selectedColor) {
                        ForEach(LLMProfile.availableColors, id: \.self) { color in
                            HStack {
                                Circle()
                                    .fill(colorForString(color))
                                    .frame(width: 12, height: 12)
                                Text(color.capitalized)
                            }
                            .tag(color)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("Save") {
                    saveProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Load all profile data when view appears (for editing)
            if let profile = profile {
                name = profile.name
                baseURL = profile.baseURL
                selectedModel = profile.model
                maxTokens = profile.maxTokens
                contextLimit = profile.contextLimit
                selectedColor = profile.color
                apiKey = aiService.loadAPIKey(for: profile)
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !baseURL.isEmpty && !selectedModel.isEmpty
    }

    private func testConnection() {
        guard !baseURL.isEmpty else { return }

        isTestingConnection = true
        isFetchingModels = true
        connectionStatus = .idle

        Task {
            do {
                let tempProfile = LLMProfile(
                    name: name.isEmpty ? "Test" : name,
                    baseURL: baseURL,
                    hasAPIKey: !apiKey.isEmpty,
                    model: "test",
                    maxTokens: maxTokens,
                    contextLimit: contextLimit,
                    color: selectedColor
                )

                // Save API key temporarily for testing
                if !apiKey.isEmpty {
                    aiService.saveAPIKey(apiKey, for: tempProfile)
                }

                let models = try await aiService.fetchModels(for: tempProfile)
                availableModels = models
                connectionStatus = .success(modelCount: models.count)

                // Auto-select first model if none selected
                if selectedModel.isEmpty && !models.isEmpty {
                    selectedModel = models[0].id
                }

            } catch {
                connectionStatus = .failed(error: error.localizedDescription)
                availableModels = []
            }

            isTestingConnection = false
            isFetchingModels = false
        }
    }

    private func saveProfile() {
        let savedProfile: LLMProfile

        if let existingProfile = profile {
            savedProfile = LLMProfile(
                id: existingProfile.id,
                name: name,
                baseURL: baseURL,
                hasAPIKey: !apiKey.isEmpty,
                model: selectedModel,
                maxTokens: maxTokens,
                contextLimit: contextLimit,
                color: selectedColor
            )
        } else {
            savedProfile = LLMProfile(
                name: name,
                baseURL: baseURL,
                hasAPIKey: !apiKey.isEmpty,
                model: selectedModel,
                maxTokens: maxTokens,
                contextLimit: contextLimit,
                color: selectedColor
            )
        }

        onSave(savedProfile, apiKey)
        dismiss()
    }

    private func colorForString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        default: return .gray
        }
    }

    /// Get known token limits for common models
    private func getModelTokenLimit(_ model: String) -> Int? {
        let modelLower = model.lowercased()

        // OpenAI models
        if modelLower.contains("gpt-4o") {
            return 16384
        } else if modelLower.contains("gpt-4-turbo") || modelLower.contains("gpt-4-1106") || modelLower.contains("gpt-4-0125") {
            return 4096
        } else if modelLower.contains("gpt-4-32k") {
            return 32768
        } else if modelLower.contains("gpt-4") {
            return 8192
        } else if modelLower.contains("gpt-3.5-turbo-16k") {
            return 16384
        } else if modelLower.contains("gpt-3.5-turbo") {
            return 4096
        }

        // Anthropic models (via OpenRouter/Together)
        else if modelLower.contains("claude-3-5-sonnet") || modelLower.contains("claude-3-opus") || modelLower.contains("claude-3-sonnet") {
            return 4096
        } else if modelLower.contains("claude-2") {
            return 4096
        }

        // Groq models (fast inference)
        else if modelLower.contains("mixtral") || modelLower.contains("llama") {
            return 8192
        }

        // Gemini models
        else if modelLower.contains("gemini-pro") {
            return 8192
        }

        return nil
    }

    /// Get known context window limits for common models
    private func getModelContextLimit(_ model: String) -> Int? {
        let modelLower = model.lowercased()

        // OpenAI models
        if modelLower.contains("gpt-4o") {
            return 128000
        } else if modelLower.contains("gpt-4-turbo") || modelLower.contains("gpt-4-1106") || modelLower.contains("gpt-4-0125") {
            return 128000
        } else if modelLower.contains("gpt-4-32k") {
            return 32768
        } else if modelLower.contains("gpt-4") {
            return 8192
        } else if modelLower.contains("gpt-3.5-turbo-16k") {
            return 16384
        } else if modelLower.contains("gpt-3.5-turbo") {
            return 16385
        }

        // Anthropic models (via OpenRouter/Together)
        else if modelLower.contains("claude-3") {
            return 200000
        } else if modelLower.contains("claude-2") {
            return 100000
        }

        // Groq models
        else if modelLower.contains("mixtral") {
            return 32768
        } else if modelLower.contains("llama-3") {
            return 8192
        } else if modelLower.contains("llama-2") {
            return 4096
        }

        // Gemini models
        else if modelLower.contains("gemini-1.5") {
            return 1000000
        } else if modelLower.contains("gemini-pro") {
            return 32768
        }

        return nil
    }
}

#Preview {
    ProfileFormView { _, _ in }
        .environment(AIService())
}
