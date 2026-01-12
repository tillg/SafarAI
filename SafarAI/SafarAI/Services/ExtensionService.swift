import SafariServices
import Observation

enum ToolError: Error {
    case timeout(message: String)
    case executionFailed(message: String)

    var localizedDescription: String {
        switch self {
        case .timeout(let message):
            return message
        case .executionFailed(let message):
            return message
        }
    }
}

@Observable
final class ExtensionService {
    var pageContent: PageContent?
    var isConnected = false
    var currentTabId: Int?
    var currentTabUrl: String?
    var currentTabTitle: String?
    var events: [BrowserEvent] = []
    let eventsLogURL: URL

    private let extensionBundleIdentifier = "com.grtnr.SafarAI.Extension"
    private let appGroupIdentifier = "group.com.grtnr.SafarAI"
    private var observer: NSObjectProtocol?
    private var lastMessageTimestamp: TimeInterval = 0
    private var pollTimer: Timer?
    private let markdownConverter = MarkdownConverter()

    // Request/response correlation
    private var pendingRequests: [String: CheckedContinuation<String, Error>] = [:]
    private var requestTimeouts: [String: Task<Void, Never>] = [:]

    init() {
        // Set up events log file path
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("SafarAI", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        eventsLogURL = appDir.appendingPathComponent("browser_events.log")

        setupListener()
        ping()
        loadRecentEvents()
    }

    private func setupListener() {
        // Poll for new messages in shared container
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkForNewMessages()
        }
    }

    private func checkForNewMessages() {
        guard let shared = UserDefaults(suiteName: appGroupIdentifier) else {
            if lastMessageTimestamp == 0 {
                logError("Failed to access App Group: \(appGroupIdentifier)")
            }
            return
        }

        let timestamp = shared.double(forKey: "lastMessageTimestamp")

        if timestamp > lastMessageTimestamp {
            lastMessageTimestamp = timestamp

            if let messageData = shared.data(forKey: "lastMessage"),
               let messageDict = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
                handleMessage(messageDict)
            }
        }
    }

    private func handleMessage(_ data: [String: Any]) {
        guard let action = data["action"] as? String else {
            log("⚠️ Message without action: \(data.keys)")
            return
        }

        log("📨 Received: \(action)")

        switch action {
        case "pageContent":
            if let contentData = data["data"] as? [String: Any] {
                var content = PageContent(from: contentData)

                log("📄 Received page content: html=\(content.html?.count ?? 0) chars, text=\(content.text.count) chars")

                // Convert HTML to Markdown if HTML is available
                if let html = content.html, !html.isEmpty {
                    log("🔄 Converting HTML to Markdown...")
                    let markdown = markdownConverter.convertToMarkdown(html: html, fallbackText: content.text)

                    // Create new PageContent with markdown
                    content = PageContent(
                        url: content.url,
                        title: content.title,
                        html: content.html,
                        markdown: markdown,
                        text: content.text,
                        description: content.description,
                        siteName: content.siteName,
                        faviconUrl: content.faviconUrl,
                        faviconData: content.faviconData,
                        images: content.images,
                        screenshot: content.screenshot
                    )
                } else {
                    log("⚠️ No HTML available for Markdown conversion")
                }

                pageContent = content
                log("📄 Page: \(pageContent?.title ?? "unknown")")
            }
        case "browserEvent":
            if let eventData = data["event"] as? [String: Any] {
                if let event = BrowserEvent(from: eventData) {
                    addEvent(event)

                    // Update current tab info from browser events
                    if event.type == .tabSwitch {
                        if let tabId = event.tabId {
                            currentTabId = tabId
                        }
                        currentTabUrl = event.url
                        currentTabTitle = event.title

                        // Clear old page content when switching tabs
                        // It will be refreshed when content script responds
                        pageContent = nil
                        log("⚠️ Tab switched - page content cleared, waiting for refresh")
                    } else if event.type == .pageLoad {
                        if let tabId = event.tabId {
                            currentTabId = tabId
                        }
                        currentTabUrl = event.url
                        currentTabTitle = event.title

                        // Clear old page content on page load/reload
                        // It will be refreshed when content script responds
                        pageContent = nil
                        log("⚠️ Page loaded - page content cleared, waiting for refresh")
                    }
                } else {
                    logError("Failed to parse browser event: \(eventData)")
                }
            } else {
                logError("browserEvent missing event data: \(data)")
            }
        case "pong":
            isConnected = true
        case "extensionReady":
            isConnected = true
            log("✅ Extension connected")
            requestPageContent()
        case "error":
            if let message = data["message"] as? String {
                logError("Extension: \(message)")
            }
        case "toolResponse":
            if let requestId = data["requestId"] as? String,
               let continuation = pendingRequests[requestId] {
                // Cancel timeout
                requestTimeouts[requestId]?.cancel()
                requestTimeouts.removeValue(forKey: requestId)
                pendingRequests.removeValue(forKey: requestId)

                // Resume with result or error
                if let error = data["error"] as? String {
                    continuation.resume(throwing: ToolError.executionFailed(message: error))
                } else if let result = data["result"] as? String {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: ToolError.executionFailed(message: "Invalid response format"))
                }
            }
        default:
            break
        }
    }

    private func addEvent(_ event: BrowserEvent) {
        events.append(event)

        // Keep only last 500 events in memory
        if events.count > 500 {
            events.removeFirst(events.count - 500)
        }

        // Append to log file
        saveEventToLog(event)

        log("\(event.type.icon()) \(event.type.displayName): \(event.title ?? event.url ?? "")")
    }

    private func saveEventToLog(_ event: BrowserEvent) {
        // Convert event to JSON
        let eventDict: [String: Any] = [
            "id": event.id.uuidString,
            "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
            "type": event.type.rawValue,
            "tabId": event.tabId as Any,
            "url": event.url as Any,
            "title": event.title as Any,
            "details": event.details
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventDict),
              var jsonString = String(data: jsonData, encoding: .utf8) else {
            logError("Failed to serialize event to JSON")
            return
        }

        // JSON Lines format: one JSON object per line
        jsonString += "\n"

        if let data = jsonString.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: eventsLogURL.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: eventsLogURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                // Create new file
                try? data.write(to: eventsLogURL)
            }
        }
    }

    private func loadRecentEvents() {
        // Load last 100 events from JSON log file on startup
        guard FileManager.default.fileExists(atPath: eventsLogURL.path),
              let content = try? String(contentsOf: eventsLogURL, encoding: .utf8) else {
            log("📋 No events log file found")
            return
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let recentLines = Array(lines.suffix(100))

        var loadedEvents: [BrowserEvent] = []

        for line in recentLines {
            guard let jsonData = line.data(using: .utf8),
                  let eventDict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let typeString = eventDict["type"] as? String,
                  let type = BrowserEvent.EventType(rawValue: typeString),
                  let timestampString = eventDict["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
                continue
            }

            let event = BrowserEvent(
                id: UUID(uuidString: eventDict["id"] as? String ?? "") ?? UUID(),
                timestamp: timestamp,
                type: type,
                tabId: eventDict["tabId"] as? Int,
                url: eventDict["url"] as? String,
                title: eventDict["title"] as? String,
                details: eventDict["details"] as? [String: String] ?? [:]
            )

            loadedEvents.append(event)
        }

        events = loadedEvents
        log("📋 Loaded \(events.count) events from JSON log")
    }

    func requestPageContent(options: [String: Any]? = nil) {
        var userInfo: [String: Any] = ["action": "getPageContent"]
        if let options = options {
            userInfo["options"] = options
        }
        sendMessage(userInfo)
    }

    func ping() {
        sendMessage(["action": "ping"])
    }

    func logAIQuery(userMessage: String, fullPrompt: String, pageContextSnapshot: String?) {
        // Create display prompt with [pagecontext] marker if context was included
        let displayPrompt: String
        if pageContextSnapshot != nil {
            displayPrompt = """
            [pagecontext]

            \(userMessage)
            """
        } else {
            displayPrompt = userMessage
        }

        let event = BrowserEvent(
            timestamp: Date(),
            type: .aiQuery,
            tabId: currentTabId,
            url: pageContent?.url ?? currentTabUrl,
            title: String(userMessage.prefix(100)), // First 100 chars as title
            details: [
                "prompt": displayPrompt, // Prompt with [pagecontext] marker
                "fullPrompt": fullPrompt, // Actual prompt sent to LLM
                "userMessage": userMessage, // Original user message
                "pageContext": pageContextSnapshot ?? "", // Page context snapshot
                "messageLength": String(userMessage.count),
                "hasPageContext": pageContextSnapshot != nil ? "true" : "false",
                "pageTitle": pageContent?.title ?? currentTabTitle ?? "N/A"
            ]
        )
        addEvent(event)
    }

    func logAIResponse(responseLength: Int, model: String? = nil) {
        let event = BrowserEvent(
            timestamp: Date(),
            type: .aiResponse,
            tabId: currentTabId,
            url: pageContent?.url,
            title: "Response received",
            details: [
                "responseLength": String(responseLength),
                "model": model ?? "unknown"
            ]
        )
        addEvent(event)
    }

    func logToolCall(name: String, arguments: String) {
        let event = BrowserEvent(
            timestamp: Date(),
            type: .toolCall,
            tabId: currentTabId,
            url: currentTabUrl,
            title: name,
            details: [
                "toolName": name,
                "arguments": arguments
            ]
        )
        addEvent(event)
    }

    func logToolResult(name: String, result: String, duration: TimeInterval) {
        let event = BrowserEvent(
            timestamp: Date(),
            type: .toolResult,
            tabId: currentTabId,
            url: currentTabUrl,
            title: name,
            details: [
                "toolName": name,
                "result": result,
                "duration": String(format: "%.2f", duration)
            ]
        )
        addEvent(event)
    }

    func requestOpenTab(url: String) {
        sendMessage([
            "action": "openTab",
            "url": url
        ])
    }

    /// Execute a tool call and wait for response
    func executeToolCall(name: String, arguments: [String: Any] = [:], timeout: TimeInterval = 10.0) async throws -> String {
        let requestId = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation for when response arrives
            pendingRequests[requestId] = continuation

            // Set up timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                // Check if request is still pending
                if pendingRequests[requestId] != nil {
                    pendingRequests.removeValue(forKey: requestId)
                    requestTimeouts.removeValue(forKey: requestId)

                    // Log timeout error
                    let errorMsg = "Tool '\(name)' timed out after \(timeout)s"
                    logError(errorMsg)

                    continuation.resume(throwing: ToolError.timeout(message: errorMsg))
                }
            }
            requestTimeouts[requestId] = timeoutTask

            // Send tool call request
            sendMessage([
                "action": "toolCall",
                "requestId": requestId,
                "toolName": name,
                "arguments": arguments
            ])
        }
    }

    private func sendMessage(_ userInfo: [String: Any]) {
        guard let action = userInfo["action"] as? String else { return }

        SFSafariApplication.dispatchMessage(
            withName: action,
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: userInfo
        ) { error in
            if let error = error {
                logError("Send '\(action)' failed: \(error.localizedDescription)")
                self.isConnected = false
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }

        // Cancel all pending requests
        for (_, task) in requestTimeouts {
            task.cancel()
        }
        for (_, continuation) in pendingRequests {
            continuation.resume(throwing: ToolError.executionFailed(message: "Service deinitialized"))
        }
    }
}
