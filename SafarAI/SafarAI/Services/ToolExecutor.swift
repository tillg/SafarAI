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

        case "getPageStructure":
            result = await getPageStructure()

        case "getImage":
            result = await getImage(arguments: toolCall.function.arguments)

        case "searchOnPage":
            result = await searchOnPage(arguments: toolCall.function.arguments)

        case "getLinks":
            result = await getLinks()

        case "openInNewTab":
            result = await openInNewTab(arguments: toolCall.function.arguments)

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

    // MARK: - Tool Implementations

    private func getPageText() async -> String {
        guard let content = extensionService?.pageContent else {
            return jsonError("No page content available")
        }

        // Check if text is empty or too short
        if content.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return jsonError("Page text is empty - content script may have failed")
        }

        let result: [String: Any] = [
            "url": content.url,
            "title": content.title,
            "text": content.text,
            "description": content.description ?? "",
            "textLength": content.text.count
        ]

        return jsonEncode(result)
    }

    private func getPageStructure() async -> String {
        // TODO: Implement async content script communication
        // For now, return basic structure from page content
        guard let content = extensionService?.pageContent else {
            return jsonError("No page content available. Please reload the page.")
        }

        let result: [String: Any] = [
            "url": content.url,
            "title": content.title,
            "description": content.description ?? "",
            "siteName": content.siteName ?? "",
            "note": "Full DOM structure requires page reload (async communication not yet implemented)"
        ]

        return jsonEncode(result)
    }

    private func getImage(arguments: String) async -> String {
        // TODO: Implement content script communication
        return jsonError("getImage tool requires async communication (not yet implemented). Please reload page.")
    }

    private func searchOnPage(arguments: String) async -> String {
        guard let args = try? JSONSerialization.jsonObject(with: arguments.data(using: .utf8)!) as? [String: Any],
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

    private func getLinks() async -> String {
        // TODO: Implement content script communication
        return jsonError("getLinks tool requires async communication (not yet implemented). Please reload page.")
    }

    private func openInNewTab(arguments: String) async -> String {
        guard let args = try? JSONSerialization.jsonObject(with: arguments.data(using: .utf8)!) as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
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
