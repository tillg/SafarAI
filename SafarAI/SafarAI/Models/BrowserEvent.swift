import Foundation

struct BrowserEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: EventType
    let tabId: Int?
    let url: String?
    let title: String?
    let details: [String: String]

    enum EventType: String, Codable {
        case tabSwitch = "tab_switch"
        case tabOpen = "tab_open"
        case tabClose = "tab_close"
        case pageLoad = "page_load"
        case linkClick = "link_click"
        case aiQuery = "ai_query"
        case aiResponse = "ai_response"

        var icon: String {
            switch self {
            case .tabSwitch: return "🔄"
            case .tabOpen: return "➕"
            case .tabClose: return "➖"
            case .pageLoad: return "🔗"
            case .linkClick: return "🔗"
            case .aiQuery: return "💬"
            case .aiResponse: return "🤖"
            }
        }

        var displayName: String {
            switch self {
            case .tabSwitch: return "Tab Switch"
            case .tabOpen: return "Tab Opened"
            case .tabClose: return "Tab Closed"
            case .pageLoad: return "Page Loaded"
            case .linkClick: return "Link Clicked"
            case .aiQuery: return "AI Query"
            case .aiResponse: return "AI Response"
            }
        }
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), type: EventType, tabId: Int? = nil, url: String? = nil, title: String? = nil, details: [String: String] = [:]) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.tabId = tabId
        self.url = url
        self.title = title
        self.details = details
    }

    // Initialize from JavaScript event data
    init?(from data: [String: Any]) {
        guard let typeString = data["type"] as? String,
              let type = EventType(rawValue: typeString),
              let timestampMs = data["timestamp"] as? Double else {
            print("❌ BrowserEvent init failed: type=\(data["type"] ?? "nil"), timestamp=\(data["timestamp"] ?? "nil")")
            return nil
        }

        self.id = UUID()
        self.timestamp = Date(timeIntervalSince1970: timestampMs / 1000.0)
        self.type = type
        self.tabId = data["tabId"] as? Int

        // Handle URL - convert empty strings to nil
        if let urlString = data["url"] as? String, !urlString.isEmpty {
            self.url = urlString
        } else {
            self.url = nil
        }

        // Handle title - convert empty strings to nil
        if let titleString = data["title"] as? String, !titleString.isEmpty {
            self.title = titleString
        } else {
            self.title = nil
        }

        // Handle details dictionary, filtering out null/NSNull values
        if let detailsDict = data["details"] as? [String: Any] {
            var stringDetails: [String: String] = [:]
            for (key, value) in detailsDict {
                if let stringValue = value as? String {
                    stringDetails[key] = stringValue
                }
            }
            self.details = stringDetails
        } else {
            self.details = [:]
        }
    }

    // Format for log file
    var logFormat: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = timeFormatter.string(from: timestamp)

        var parts = ["\(timeString) [\(type.displayName)]"]

        if let title = title, !title.isEmpty {
            parts.append(title)
        }

        if let url = url, !url.isEmpty {
            parts.append("(\(url))")
        }

        if let tabId = tabId {
            parts.append("tab:\(tabId)")
        }

        if !details.isEmpty {
            let detailsStr = details.map { "\($0)=\($1)" }.joined(separator: ", ")
            parts.append("{\(detailsStr)}")
        }

        return parts.joined(separator: " ")
    }
}
