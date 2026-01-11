import Foundation
import Observation

@Observable
final class AIService {
    var apiKey: String = ""
    var provider: AIProvider = .openAI
    var model: String = "gpt-3.5-turbo"
    var enableTools: Bool = true // Enable tool calling

    private var toolExecutor: ToolExecutor?

    init() {
        loadSettings()
    }

    func setToolExecutor(_ executor: ToolExecutor) {
        self.toolExecutor = executor
    }

    private func loadSettings() {
        apiKey = UserDefaults.standard.string(forKey: "ai_api_key") ?? ""
        if let providerRaw = UserDefaults.standard.string(forKey: "ai_provider"),
           let savedProvider = AIProvider(rawValue: providerRaw) {
            provider = savedProvider
        }
        model = UserDefaults.standard.string(forKey: "ai_model") ?? "gpt-3.5-turbo"
    }

    func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: "ai_api_key")
        UserDefaults.standard.set(provider.rawValue, forKey: "ai_provider")
        UserDefaults.standard.set(model, forKey: "ai_model")
    }

    func chat(messages: [Message], pageContent: PageContent?) async -> String? {
        guard !apiKey.isEmpty else {
            return "❌ Please set your API key in Settings"
        }

        switch provider {
        case .openAI:
            return await chatOpenAI(messages: messages, pageContent: pageContent)
        case .anthropic:
            return "Anthropic support coming soon!"
        case .local:
            return "Local model support coming soon!"
        }
    }

    private func chatOpenAI(messages: [Message], pageContent: PageContent?) async -> String? {
        var apiMessages: [[String: Any]] = messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }

        // Add page content to last user message if available
        if let content = pageContent,
           let lastIndex = apiMessages.lastIndex(where: { ($0["role"] as? String) == "user" }),
           let userContent = apiMessages[lastIndex]["content"] as? String {
            let contextText = """
            [Page Context]
            Title: \(content.title)
            URL: \(content.url)
            \(content.description.map { "Description: \($0)\n" } ?? "")
            Content: \(content.text)

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
                "model": model,
                "messages": conversationMessages,
                "temperature": 0.7,
                "max_tokens": 1000
            ]

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

            guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                return nil
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
}
