import Foundation

class ToolExecutor {
    private weak var extensionService: ExtensionService?

    init(extensionService: ExtensionService) {
        self.extensionService = extensionService
    }

    func execute(_ toolCall: ToolCall) async -> String {
        guard let extensionService = extensionService else {
            return jsonError("Extension service not available")
        }

        let startTime = Date()
        log("🔧 Executing tool: \(toolCall.function.name)")

        // Log tool call event
        extensionService.logToolCall(
            name: toolCall.function.name,
            arguments: toolCall.function.arguments
        )

        let result: String

        switch toolCall.function.name {
        case "getPageText":
            result = await getPageText()

        case "getTabs":
            result = await executeToolViaExtension(toolCall: toolCall)

        case "getPageStructure":
            result = await executeToolViaExtension(toolCall: toolCall)

        case "getImage":
            result = await executeToolViaExtension(toolCall: toolCall)

        case "searchOnPage":
            result = await searchOnPage(arguments: toolCall.function.arguments)

        case "getLinks":
            result = await executeToolViaExtension(toolCall: toolCall)

        case "openInNewTab":
            result = await openInNewTab(arguments: toolCall.function.arguments)

        case "getFullPageScreenshot":
            result = await executeToolViaExtension(toolCall: toolCall)

        default:
            result = jsonError("Unknown tool: \(toolCall.function.name)")
        }

        let duration = Date().timeIntervalSince(startTime)
        log("✅ Tool completed in \(String(format: "%.2f", duration))s")

        // Log tool result event
        extensionService.logToolResult(
            name: toolCall.function.name,
            result: result,
            duration: duration
        )

        return result
    }

    // Execute tool via extension service (new async communication)
    private func executeToolViaExtension(toolCall: ToolCall) async -> String {
        guard let extensionService = extensionService else {
            return jsonError("Extension service not available")
        }

        // Parse arguments
        let arguments: [String: Any]
        if let argsData = toolCall.function.arguments.data(using: .utf8),
           let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
            arguments = args
        } else {
            arguments = [:]
        }

        // Get timeout from settings
        let timeout = UserDefaults.standard.double(forKey: "tool_timeout")
        let actualTimeout = timeout > 0 ? timeout : 10.0

        do {
            let result = try await extensionService.executeToolCall(
                name: toolCall.function.name,
                arguments: arguments,
                timeout: actualTimeout
            )
            return result
        } catch {
            return jsonError(error.localizedDescription)
        }
    }

    // MARK: - Tool Implementations

    private func getPageText() async -> String {
        guard let content = extensionService?.pageContent else {
            return jsonError("No page content available")
        }

        // Use contentForLLM which prefers markdown over plain text
        let contentText = content.contentForLLM

        // Check if text is empty or too short
        if contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return jsonError("Page text is empty - content script may have failed")
        }

        let result: [String: Any] = [
            "url": content.url,
            "title": content.title,
            "text": contentText, // Now uses Markdown if available
            "format": content.markdown != nil ? "markdown" : "plaintext",
            "description": content.description ?? "",
            "textLength": contentText.count
        ]

        return jsonEncode(result)
    }


    private func searchOnPage(arguments: String) async -> String {
        guard let argsData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
              let query = args["query"] as? String else {
            return jsonError("Invalid arguments: query required")
        }

        // Simple implementation using current page content
        guard let content = extensionService?.pageContent else {
            return jsonError("No page content available")
        }

        let text = content.text.lowercased()
        let queryLower = query.lowercased()
        let matches = text.components(separatedBy: queryLower).count - 1

        let result: [String: Any] = [
            "query": query,
            "totalMatches": matches,
            "note": "Searching in extracted text. Full page search requires reload."
        ]

        return jsonEncode(result)
    }

    private func openInNewTab(arguments: String) async -> String {
        guard let argsData = arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
              let urlString = args["url"] as? String,
              URL(string: urlString) != nil else {
            return jsonError("Invalid arguments: valid url required")
        }

        // Request to open new tab via extension
        extensionService?.requestOpenTab(url: urlString)

        let result: [String: Any] = [
            "success": true,
            "url": urlString,
            "message": "Opening tab..."
        ]

        return jsonEncode(result)
    }

    // MARK: - Helpers

    private func jsonEncode(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8) else {
            return jsonError("Failed to encode result")
        }
        return json
    }

    private func jsonError(_ message: String) -> String {
        return "{\"error\": \"\(message)\"}"
    }
}
