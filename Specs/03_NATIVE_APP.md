# Native macOS App with Extension Bridge

## Goal

Build a native macOS application that displays the chat UI in a proper macOS window, communicating with the Safari Web Extension via native messaging to access page content.

## Why

* Proper macOS window (resizable, movable, always-on-top)
* User controls positioning (side-by-side with Safari)
* No CSS conflicts with webpages
* Full SwiftUI capabilities
* Works on ALL websites
* Professional macOS app experience
* Support multiple AI providers (OpenAI, Anthropic, local models)

## Current State

Working toolbar popup extension with:
* Phase 1: Basic chat UI ✓
* Phase 2: OpenAI API integration ✓
* Phase 3: Page content access ✓

Now transforming into a native macOS app.

---

## Architecture

### Modern SwiftUI Design

**Following 2025 best practices:**
* **No ViewModels** - SwiftUI views don't need them
* **@Observable services** - ExtensionService, OpenAIService
* **@State for view state** - Messages, input, loading states
* **@Environment for DI** - Services injected into views
* **Direct state flow** - Views express state directly

**Architecture layers:**
```
Views (SwiftUI)
    ↕ @Environment
Services (@Observable)
    ↕ APIs
External Systems (Safari, OpenAI)
```

### Component Structure

```
Native macOS App (SwiftUI)
    ↕ Native Messaging
Safari Extension (JavaScript)
    ↕ browser.tabs.sendMessage
Content Script (page content extraction)
```

### Communication Flow

```
User types in native app
    ↓
App → Extension: "getPageContent"
    ↓
Extension → content.js: Request content
    ↓
content.js: Extract page content
    ↓
content.js → Extension: Return content
    ↓
Extension → App: Page content
    ↓
App: Call AI API (OpenAI, Anthropic, etc.)
    ↓
App: Display response
```

---

## Extension API

### Operations

**Native App → Extension:**

| Operation | Purpose | Response |
|-----------|---------|----------|
| `getPageContent` | Get current tab content | Page data with optional images |
| `getTabInfo` | Get tab metadata | URL, title, active state |
| `getAllTabs` | List all open tabs | Array of tab info |
| `ping` | Check connection | Pong with timestamp |

**Extension → Native App:**

| Event | When | Data |
|-------|------|------|
| `pageContent` | Content extracted | Page text, images, metadata |
| `tabChanged` | User switched tabs | Tab ID |
| `pageLoaded` | Page finished loading | URL, title |
| `extensionReady` | Extension loaded | Version |
| `error` | Error occurred | Error code, message |

### Page Content Structure

```typescript
{
    url: string,
    title: string,
    text: string,
    description?: string,
    siteName?: string,
    images?: [
        {
            url: string,
            alt?: string,
            width: number,
            height: number,
            position: string,  // hero, inline, article
            data?: string      // base64 (optional)
        }
    ],
    screenshot?: string  // base64 (optional)
}
```

### Implementation

**manifest.json:**

```json
{
    "manifest_version": 3,
    "permissions": [
        "nativeMessaging",
        "activeTab",
        "storage",
        "tabs"
    ],
    "content_scripts": [{
        "js": ["content.js"],
        "matches": ["<all_urls>"],
        "run_at": "document_idle"
    }],
    "background": {
        "scripts": ["background.js"],
        "type": "module",
        "persistent": false
    }
}
```

**SafariExtensionHandler.swift:**

```swift
import SafariServices

class SafariExtensionHandler: SFSafariExtensionHandler {
    override func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let userInfo = item.userInfo as? [String: Any],
              let message = userInfo[SFExtensionMessageKey] as? [String: Any] else {
            context.completeRequest(returningItems: nil)
            return
        }

        // Forward to native app
        NotificationCenter.default.post(
            name: NSNotification.Name("ExtensionMessage"),
            object: nil,
            userInfo: message
        )

        // Acknowledge
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["status": "received"]]
        context.completeRequest(returningItems: [response])
    }
}
```

**background.js:**

```javascript
let nativePort = browser.runtime.connectNative("com.yourdomain.safarai");

nativePort.onMessage.addListener((message) => {
    handleNativeMessage(message);
});

function handleNativeMessage(message) {
    switch (message.action) {
        case "getPageContent":
            getPageContent(message.tabId);
            break;
        case "ping":
            sendToNative({ action: "pong", timestamp: Date.now() });
            break;
    }
}

async function getPageContent(tabId = null) {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    const tab = tabs[0];

    const content = await browser.tabs.sendMessage(tab.id, {
        action: "getPageContent"
    });

    sendToNative({
        action: "pageContent",
        data: content,
        tabId: tab.id
    });
}

function sendToNative(message) {
    nativePort.postMessage(message);
}

// Auto-send page content on tab changes
browser.tabs.onActivated.addListener((activeInfo) => {
    getPageContent(activeInfo.tabId);
});
```

**ExtensionService.swift:**

```swift
import SafariServices
import Observation

@Observable
final class ExtensionService {
    var pageContent: PageContent?
    var isConnected = false

    private let extensionId = "com.yourdomain.safarai.Extension"
    private var observer: NSObjectProtocol?

    init() {
        setupListener()
        ping()
    }

    private func setupListener() {
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ExtensionMessage"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleMessage(notification.userInfo)
        }
    }

    private func handleMessage(_ data: [AnyHashable: Any]?) {
        guard let action = data?["action"] as? String else { return }

        switch action {
        case "pageContent":
            if let contentData = data?["data"] as? [String: Any] {
                pageContent = PageContent(from: contentData)
            }
        case "pong":
            isConnected = true
        case "extensionReady":
            requestPageContent()
        default:
            break
        }
    }

    func requestPageContent() {
        sendMessage("getPageContent")
    }

    func ping() {
        sendMessage("ping")
    }

    private func sendMessage(_ action: String, data: [String: Any]? = nil) {
        var userInfo: [String: Any] = ["action": action]
        if let data = data {
            userInfo.merge(data) { $1 }
        }

        SFSafariApplication.dispatchMessage(
            withName: action,
            toExtensionWithIdentifier: extensionId,
            userInfo: userInfo
        )
    }

    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

**ContentView.swift:**

```swift
import SwiftUI

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isLoading = false

    @Environment(ExtensionService.self) private var extensionService
    @Environment(AIService.self) private var aiService

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Page context banner
            if let page = extensionService.pageContent {
                pageContextBanner(page)
            }

            Divider()

            // Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageView(message: message)
                    }

                    if isLoading {
                        loadingView
                    }
                }
                .padding()
            }

            Divider()

            // Input
            inputView
        }
        .task {
            await extensionService.requestPageContent()
        }
    }

    private var headerView: some View {
        HStack {
            Text("SafarAI")
                .font(.headline)
            Spacer()
            Button("Get Page", systemImage: "doc.text") {
                Task { await extensionService.requestPageContent() }
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pageContextBanner(_ page: PageContent) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(.blue)
            Text(page.title)
                .lineLimit(1)
            Spacer()
            Button(systemImage: "xmark.circle.fill") {
                extensionService.pageContent = nil
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
    }

    private var inputView: some View {
        HStack(spacing: 8) {
            TextField("Ask me anything...", text: $input)
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 8))
                .onSubmit { sendMessage() }

            Button("Send", systemImage: "arrow.up.circle.fill") {
                sendMessage()
            }
            .disabled(input.isEmpty)
        }
        .padding()
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Thinking...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }

        let userMessage = Message(role: .user, content: input)
        messages.append(userMessage)
        input = ""
        isLoading = true

        Task {
            let response = await aiService.chat(
                messages: messages,
                pageContent: extensionService.pageContent
            )
            isLoading = false

            if let response = response {
                messages.append(Message(role: .assistant, content: response))
            }
        }
    }
}
```

---

## Image Handling

### V1.0: URLs + Metadata (Default)

**What to extract:**
* Image URLs
* Alt text, dimensions
* Position (hero, inline, article)
* Filter images < 100x100px
* Top 10 images by importance

**content.js:**

```javascript
function extractImages() {
    const images = [];
    document.querySelectorAll('img').forEach((img, index) => {
        if (img.naturalWidth < 100 || img.naturalHeight < 100) return;

        const style = window.getComputedStyle(img);
        if (style.display === 'none') return;

        images.push({
            url: img.src,
            alt: img.alt || '',
            width: img.naturalWidth,
            height: img.naturalHeight,
            position: index === 0 ? 'hero' : 'inline'
        });
    });

    return images.slice(0, 10);
}
```

### V1.1: Vision Model Support

**Add base64 encoding for top 3 images:**
* Resize to 1024px max
* 80% JPEG quality
* ~100-300KB per image

**Use with GPT-4 Vision:**

```swift
// Add images to API request
var contentBlocks: [[String: Any]] = [
    ["type": "text", "text": pageContext]
]

for image in pageContent.images.prefix(3) {
    contentBlocks.append([
        "type": "image_url",
        "image_url": ["url": image.url, "detail": "auto"]
    ])
}

let body = [
    "model": "gpt-4-vision-preview",
    "messages": [["role": "user", "content": contentBlocks]],
    "max_tokens": 4096
]
```

**Settings:**
* Toggle: Include images (on/off)
* Picker: Detail level (URLs only / Top 3 / All)
* Cost estimation display

---

## Implementation Plan

### Phase 1: Native App Foundation

1. Add macOS App target in Xcode
2. Create SwiftUI chat interface
3. Create @Observable services (ExtensionService, AIService)
4. Test with mock data

**Architecture follows modern SwiftUI best practices:**
* ✅ No ViewModels - uses @Observable services
* ✅ @State for view-local state
* ✅ @Environment for dependency injection
* ✅ Modern APIs (foregroundStyle, clipShape, Task.sleep)
* ✅ Proper async/await patterns

**Key files:**
* `SafarAIApp.swift` - App entry point, service injection
* `ContentView.swift` - Main chat UI
* `ExtensionService.swift` - Safari extension bridge (@Observable)
* `AIService.swift` - Multi-provider LLM client (@Observable)
* `Models/Message.swift` - Message struct
* `Models/PageContent.swift` - Page content struct
* `Models/AIProvider.swift` - Provider enum

**SafarAIApp.swift:**

```swift
import SwiftUI

@main
struct SafarAIApp: App {
    @State private var extensionService = ExtensionService()
    @State private var aiService = AIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(extensionService)
                .environment(aiService)
                .frame(minWidth: 400, minHeight: 600)
        }
    }
}
```

**AIService.swift:**

```swift
import Foundation
import Observation

@Observable
final class AIService {
    var apiKey: String = ""
    var provider: AIProvider = .openAI  // Future: .anthropic, .local, etc.

    init() {
        loadAPIKey()
    }

    private func loadAPIKey() {
        apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }

    func saveAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }

    func chat(messages: [Message], pageContent: PageContent?) async -> String? {
        guard !apiKey.isEmpty else { return "Please set API key" }

        var apiMessages = messages.map { message in
            ["role": message.role.rawValue, "content": message.content]
        }

        // Add page content to last user message
        if let content = pageContent,
           let lastIndex = apiMessages.lastIndex(where: { $0["role"] == "user" }) {
            let contextText = """
            [Page: \(content.title)]
            \(content.text)

            [Question]
            \(apiMessages[lastIndex]["content"] ?? "")
            """
            apiMessages[lastIndex]["content"] = contextText
        }

        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": apiMessages,
            "temperature": 0.7,
            "max_tokens": 1000
        ]

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let choices = json?["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        return nil
    }
}
```

**AIProvider.swift:**

```swift
enum AIProvider: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case local = "Local Model"
    // Future: .ollama, .custom, etc.
}
```

### Phase 2: Native Messaging

1. Update manifest.json (add `nativeMessaging` permission)
2. Implement SafariExtensionHandler.swift
3. Update background.js with port connection
4. Test message passing

### Phase 3: Connect & Test

1. Request page content from app
2. Receive and display content
3. Send to AI with context (via AIService)
4. Display responses

### Phase 4: Image Support

1. Extract image URLs in content.js
2. Pass to native app
3. Update AIService to support vision models (GPT-4 Vision)
4. Add settings UI

### Phase 5: Polish

1. Settings window
2. Keyboard shortcuts
3. Window management (always-on-top)
4. Error handling
5. Dock integration

---

## Key Technical Details

**Native Messaging:**
* Content scripts CANNOT send to native app directly
* Must go through background.js
* macOS only (iOS doesn't support app→JS messaging)
* Message size limit: ~5-10MB

**Modern SwiftUI Patterns:**
* Use `@Observable` for services (not ObservableObject)
* Use `@State` for view state (not @StateObject)
* Use `@Environment` for service injection (not @EnvironmentObject)
* Always use `await` inside `Task {}` blocks
* Use `.task()` modifier for async view lifecycle
* Use modern APIs: `foregroundStyle()`, `clipShape()`, `Button(systemImage:)`

**Window Management:**

```swift
// Always-on-top
window.level = .floating
```

---

## Migration from Popup

1. Keep popup working during development
2. Build native app independently
3. Test messaging bridge
4. Move AI API calls to native app (AIService)
5. Optional: Remove popup once stable

---

## Success Criteria

* [ ] Native app window opens with chat UI
* [ ] Extension sends page content to app
* [ ] AIService calls LLM API successfully
* [ ] Page content auto-loads on tab change
* [ ] Settings persist (API key, model selection)
* [ ] Window position remembered
* [ ] Performance: < 100MB memory, < 5% CPU
* [ ] Supports multiple AI providers (OpenAI, Anthropic, local)

---

## Resources

**Apple Documentation:**
* [Native Messaging](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
* [SFSafariApplication](https://developer.apple.com/documentation/safariservices/sfsafariapplication)
* [Observation Framework](https://developer.apple.com/documentation/observation)

**Best Practices (see .claude/BEST_PRACTICES/):**
* Modern SwiftUI patterns (@Observable, no ViewModels)
* Async/await patterns (always use `await` in Task)
* Modern UI APIs (foregroundStyle, clipShape)

---

## Next Steps

1. Create macOS App target in Xcode
2. Implement Phase 1 (basic SwiftUI window with AIService)
3. Add native messaging support
4. Test extension bridge
5. Move AI API integration to native app
