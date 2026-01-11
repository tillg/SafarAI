import SafariServices
import Observation

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
                pageContent = PageContent(from: contentData)
                log("📄 Page: \(pageContent?.title ?? "unknown")")
            }
        case "browserEvent":
            if let eventData = data["event"] as? [String: Any] {
                if let event = BrowserEvent(from: eventData) {
                    addEvent(event)

                    // Update current tab info from browser events
                    if event.type == .tabSwitch || event.type == .pageLoad {
                        if let tabId = event.tabId {
                            currentTabId = tabId
                        }
                        currentTabUrl = event.url
                        currentTabTitle = event.title
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

        log("\(event.type.icon) \(event.type.displayName): \(event.title ?? event.url ?? "")")
    }

    private func saveEventToLog(_ event: BrowserEvent) {
        let logLine = event.logFormat + "\n"

        if let data = logLine.data(using: .utf8) {
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
        // Load last 100 events from log file on startup
        guard FileManager.default.fileExists(atPath: eventsLogURL.path),
              let content = try? String(contentsOf: eventsLogURL, encoding: .utf8) else {
            return
        }

        let lines = content.components(separatedBy: .newlines)
        let recentLines = Array(lines.suffix(100)).filter { !$0.isEmpty }

        log("📋 Loaded \(recentLines.count) recent events from log")
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
        if let context = pageContextSnapshot {
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
    }
}
