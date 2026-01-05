import SafariServices
import Observation

@Observable
final class ExtensionService {
    var pageContent: PageContent?
    var isConnected = false
    var currentTabId: Int?

    private let extensionBundleIdentifier = "com.grtnr.SafarAI.Extension"
    private let appGroupIdentifier = "group.com.grtnr.SafarAI"
    private var observer: NSObjectProtocol?
    private var lastMessageTimestamp: TimeInterval = 0
    private var pollTimer: Timer?

    init() {
        setupListener()
        ping()
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
        guard let action = data["action"] as? String else { return }

        switch action {
        case "pageContent":
            if let contentData = data["data"] as? [String: Any] {
                pageContent = PageContent(from: contentData)
                log("📄 Page: \(pageContent?.title ?? "unknown")")
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
