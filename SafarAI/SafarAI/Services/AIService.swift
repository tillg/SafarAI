import Foundation
import Observation

@Observable
final class AIService {
    // Legacy settings (for backward compatibility)
    var apiKey: String = ""
    var provider: AIProvider = .openAI
    var model: String = "gpt-3.5-turbo"
    var enableTools: Bool = true // Enable tool calling

    // New profile-based settings
    var profiles: [LLMProfile] = []
    var activeProfile: LLMProfile?

    private var toolExecutor: ToolExecutor?

    init() {
        loadSettings()
    }

    func setToolExecutor(_ executor: ToolExecutor) {
        self.toolExecutor = executor
    }

    private func loadSettings() {
        // Load profiles from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "llm_profiles"),
           let decoded = try? JSONDecoder().decode([LLMProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded

            // Load active profile ID
            if let activeID = UserDefaults.standard.string(forKey: "active_profile_id"),
               let uuid = UUID(uuidString: activeID),
               let profile = profiles.first(where: { $0.id == uuid }) {
                activeProfile = profile
            } else {
                // Default to first profile
                activeProfile = profiles.first
            }
        } else {
            // No profiles exist - migrate from legacy settings or create default
            migrateLegacySettings()
        }

        // Load legacy settings for backward compatibility
        apiKey = UserDefaults.standard.string(forKey: "ai_api_key") ?? ""
        if let providerRaw = UserDefaults.standard.string(forKey: "ai_provider"),
           let savedProvider = AIProvider(rawValue: providerRaw) {
            provider = savedProvider
        }
        model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"
    }

    func saveSettings() {
        // Save profiles
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: "llm_profiles")
        }

        // Save active profile ID
        if let activeProfile = activeProfile {
            UserDefaults.standard.set(activeProfile.id.uuidString, forKey: "active_profile_id")
        }

        // Save legacy settings for backward compatibility
        UserDefaults.standard.set(apiKey, forKey: "ai_api_key")
        UserDefaults.standard.set(provider.rawValue, forKey: "ai_provider")
        UserDefaults.standard.set(model, forKey: "ai_model")
    }

    private func migrateLegacySettings() {
        // Load legacy settings
        let legacyKey = UserDefaults.standard.string(forKey: "ai_api_key") ?? ""
        let legacyModel = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"

        // Create default profile from legacy settings
        let defaultProfile = LLMProfile(
            name: "OpenAI",
            baseURL: "https://api.openai.com/v1",
            hasAPIKey: !legacyKey.isEmpty,
            model: legacyModel,
            maxTokens: 4096,
            contextLimit: 16384,
            color: "red"
        )

        profiles = [defaultProfile]
        activeProfile = defaultProfile

        // Save API key to keychain if exists
        if !legacyKey.isEmpty {
            saveAPIKey(legacyKey, for: defaultProfile)
        }

        saveSettings()
    }

    /// Save API key to keychain for a profile
    func saveAPIKey(_ key: String, for profile: LLMProfile) {
        // For now, store in UserDefaults (same as legacy)
        // In future, could move to Keychain for better security
        UserDefaults.standard.set(key, forKey: "api_key_\(profile.id.uuidString)")

        // Update profile's hasAPIKey flag
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].hasAPIKey = !key.isEmpty
        }
    }

    /// Load API key from keychain for a profile
    func loadAPIKey(for profile: LLMProfile) -> String {
        return UserDefaults.standard.string(forKey: "api_key_\(profile.id.uuidString)") ?? ""
    }

    /// Switch to a different profile
    func switchProfile(to profile: LLMProfile) {
        activeProfile = profile
        saveSettings()
    }

    func chat(messages: [Message], pageContent: PageContent?) async -> String? {
        guard let profile = activeProfile else {
            return "❌ No active profile. Please configure a profile in Settings."
        }

        let profileAPIKey = loadAPIKey(for: profile)
        if profile.hasAPIKey && profileAPIKey.isEmpty {
            return "❌ Please set your API key for \(profile.name) in Settings"
        }

        return await chatOpenAI(messages: messages, pageContent: pageContent, profile: profile, apiKey: profileAPIKey)
    }

    private func chatOpenAI(messages: [Message], pageContent: PageContent?, profile: LLMProfile, apiKey: String) async -> String? {
        var apiMessages: [[String: Any]] = messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }

        // Add page content to last user message if available
        if let content = pageContent,
           let lastIndex = apiMessages.lastIndex(where: { ($0["role"] as? String) == "user" }),
           let userContent = apiMessages[lastIndex]["content"] as? String {

            // Calculate available space for page content
            // Rough estimate: ~4 characters per token
            let charsPerToken = 4
            let availableTokens = profile.availableInputTokens
            let overheadChars = 200 // For headers like "[Page Context]", etc.
            let userMessageChars = userContent.count
            let maxContentChars = (availableTokens * charsPerToken) - overheadChars - userMessageChars

            // Truncate page content if needed
            let pageText = content.contentForLLM
            let truncatedContent: String
            if pageText.count > maxContentChars && maxContentChars > 0 {
                truncatedContent = String(pageText.prefix(maxContentChars)) + "\n\n[Content truncated to fit context window]"
                print("⚠️ Truncated page content from \(pageText.count) to \(maxContentChars) chars")
            } else {
                truncatedContent = pageText
            }

            let contextText = """
            [Page Context]
            Title: \(content.title)
            URL: \(content.url)
            \(content.description.map { "Description: \($0)\n" } ?? "")
            Content:
            \(truncatedContent)

            [User Question]
            \(userContent)
            """
            apiMessages[lastIndex]["content"] = contextText
        }

        // Main conversation loop (handles tool calls)
        var conversationMessages = apiMessages
        var maxIterations = 5 // Prevent infinite loops

        while maxIterations > 0 {
            maxIterations -= 1

            var body: [String: Any] = [
                "model": profile.model,
                "messages": conversationMessages,
                "temperature": 0.7,
                "max_tokens": profile.maxTokens
            ]

            print("🤖 Sending request with maxTokens: \(profile.maxTokens) for profile: \(profile.name)")

            // Add tools if enabled
            if enableTools {
                body["tools"] = Tool.allTools.map { tool in
                    [
                        "type": tool.type,
                        "function": [
                            "name": tool.function.name,
                            "description": tool.function.description,
                            "parameters": [
                                "type": "object",
                                "properties": tool.function.parameters.properties.mapValues { prop in
                                    var propDict: [String: Any] = [
                                        "type": prop.type,
                                        "description": prop.description
                                    ]
                                    if let enumValues = prop.enum {
                                        propDict["enum"] = enumValues
                                    }
                                    return propDict
                                },
                                "required": tool.function.parameters.required
                            ]
                        ]
                    ]
                }
            }

            // Construct URL from profile's base URL
            let baseURL = profile.baseURL.hasSuffix("/") ? String(profile.baseURL.dropLast()) : profile.baseURL
            guard let url = URL(string: "\(baseURL)/chat/completions") else {
                return "❌ Invalid base URL: \(profile.baseURL)"
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"

            // Add Authorization header if API key exists
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }

            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    return "❌ Invalid response"
                }

                if httpResponse.statusCode != 200 {
                    let error = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorMessage = (error?["error"] as? [String: Any])?["message"] as? String

                    logError("OpenAI \(httpResponse.statusCode): \(errorMessage ?? "unknown")")

                    switch httpResponse.statusCode {
                    case 401:
                        return "❌ Invalid API key. Please check your settings."
                    case 429:
                        return "❌ Rate limit exceeded. Please try again later."
                    default:
                        return "❌ Error: \(errorMessage ?? "Unknown error")"
                    }
                }

                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                guard let choices = json?["choices"] as? [[String: Any]],
                      let message = choices.first?["message"] as? [String: Any] else {
                    return "❌ No response from API"
                }

                // Check if LLM wants to use tools
                if let toolCalls = message["tool_calls"] as? [[String: Any]], !toolCalls.isEmpty, let executor = toolExecutor {
                    // Execute tools
                    var toolMessages: [[String: Any]] = []

                    for toolCallDict in toolCalls {
                        guard let id = toolCallDict["id"] as? String,
                              let function = toolCallDict["function"] as? [String: Any],
                              let name = function["name"] as? String,
                              let arguments = function["arguments"] as? String else {
                            continue
                        }

                        let toolCall = ToolCall(
                            id: id,
                            type: "function",
                            function: ToolCall.FunctionCall(name: name, arguments: arguments)
                        )

                        // Execute tool
                        let result = await executor.execute(toolCall)

                        // Add tool result to messages
                        toolMessages.append([
                            "role": "tool",
                            "tool_call_id": id,
                            "content": result
                        ])
                    }

                    // Add assistant message with tool calls
                    conversationMessages.append(message)

                    // Add tool results
                    conversationMessages.append(contentsOf: toolMessages)

                    // Continue conversation with tool results
                    continue
                }

                // No tool calls, return final response
                if let content = message["content"] as? String {
                    return content
                }

                return "❌ No response from API"

            } catch {
                logError("Network: \(error.localizedDescription)")
                return "❌ Error: \(error.localizedDescription)"
            }
        }

        return "❌ Too many tool iterations"
    }

    /// Fetch available models from a profile's API endpoint
    func fetchModels(for profile: LLMProfile) async throws -> [LLMModel] {
        let apiKey = loadAPIKey(for: profile)
        let baseURL = profile.baseURL.hasSuffix("/") ? String(profile.baseURL.dropLast()) : profile.baseURL

        guard let url = URL(string: "\(baseURL)/models") else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let decoder = JSONDecoder()
        let modelsResponse = try decoder.decode(ModelsResponse.self, from: data)
        return modelsResponse.data
    }

    /// Add a new profile
    func addProfile(_ profile: LLMProfile) {
        profiles.append(profile)
        if activeProfile == nil {
            activeProfile = profile
        }
        saveSettings()
    }

    /// Update an existing profile
    func updateProfile(_ profile: LLMProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile

            // Update active profile if it's the one being edited
            if activeProfile?.id == profile.id {
                activeProfile = profile
                print("✅ Updated active profile: \(profile.name), maxTokens: \(profile.maxTokens)")
            }

            saveSettings()
        }
    }

    /// Delete a profile
    func deleteProfile(_ profile: LLMProfile) {
        profiles.removeAll { $0.id == profile.id }

        // If active profile was deleted, switch to first available
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
        }

        // Delete associated API key
        UserDefaults.standard.removeObject(forKey: "api_key_\(profile.id.uuidString)")

        saveSettings()
    }
}
