import Foundation

struct PageContent: Codable, Equatable {
    let url: String
    let title: String
    let html: String?
    let markdown: String?
    let text: String
    let description: String?
    let siteName: String?
    let faviconUrl: String?
    let faviconData: String? // Base64-encoded favicon image
    let images: [PageImage]?
    let screenshot: String?

    init(
        url: String,
        title: String,
        html: String? = nil,
        markdown: String? = nil,
        text: String,
        description: String? = nil,
        siteName: String? = nil,
        faviconUrl: String? = nil,
        faviconData: String? = nil,
        images: [PageImage]? = nil,
        screenshot: String? = nil
    ) {
        self.url = url
        self.title = title
        self.html = html
        self.markdown = markdown
        self.text = text
        self.description = description
        self.siteName = siteName
        self.faviconUrl = faviconUrl
        self.faviconData = faviconData
        self.images = images
        self.screenshot = screenshot
    }

    init(from dictionary: [String: Any]) {
        self.url = dictionary["url"] as? String ?? ""
        self.title = dictionary["title"] as? String ?? ""
        self.html = dictionary["html"] as? String
        self.markdown = nil // Will be converted in Swift
        self.text = dictionary["text"] as? String ?? ""
        self.description = dictionary["description"] as? String
        self.siteName = dictionary["siteName"] as? String
        self.faviconUrl = dictionary["faviconUrl"] as? String
        self.faviconData = dictionary["faviconData"] as? String

        if let imagesData = dictionary["images"] as? [[String: Any]] {
            self.images = imagesData.compactMap { PageImage(from: $0) }
        } else {
            self.images = nil
        }

        self.screenshot = dictionary["screenshot"] as? String
    }

    // Get best available content for LLM (prefer markdown, fallback to text)
    var contentForLLM: String {
        return markdown ?? text
    }
}

struct PageImage: Codable, Equatable {
    let url: String
    let alt: String?
    let width: Int
    let height: Int
    let position: String
    let data: String?

    init(from dictionary: [String: Any]) {
        self.url = dictionary["url"] as? String ?? ""
        self.alt = dictionary["alt"] as? String
        self.width = dictionary["width"] as? Int ?? 0
        self.height = dictionary["height"] as? Int ?? 0
        self.position = dictionary["position"] as? String ?? "inline"
        self.data = dictionary["data"] as? String
    }

    static func == (lhs: PageImage, rhs: PageImage) -> Bool {
        lhs.url == rhs.url &&
        lhs.alt == rhs.alt &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height &&
        lhs.position == rhs.position &&
        lhs.data == rhs.data
    }
}
