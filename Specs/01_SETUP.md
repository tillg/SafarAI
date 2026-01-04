# Setup

I want to create the Safari extension for macOS.

* What do i need to do?
* What is the process step by step?
* What is the "smallest" i.e. less complex setup I can do?

Visually I want a chat box on the left part, next to the content of the page i am visiting. In the chat I can talk to the AI that can access the content as well as the chat.

---

## Implementation Plan

### Architecture: Toolbar Popup

We'll use the **Toolbar Popup** approach - when the user clicks the extension icon in Safari's toolbar, a popup window appears with the chat interface. This is the simplest and most standard Safari extension pattern.


### Prerequisites

* Xcode (latest version recommended)
* macOS 10.14+ for development
* Apple Developer account (for distribution, not required for local development)
* Enable unsigned extensions in Safari: `Develop > Allow Unsigned Extensions`

### Step-by-Step Setup

**1. Create Xcode Project**

* Open Xcode
* File > New > Project
* Select **macOS** platform
* Choose **Safari Extension App** template
* Configure:
  * Product Name: "SafarAI"
  * Team: Can be "None" for local development
  * Organization Identifier: e.g., "com.yourdomain"
  * Type: Safari Web Extension
  * Language: Swift
  * Include Tests: Uncheck

**2. Understand Generated Structure**

Xcode creates two targets:

* **SafarAI** (macOS app): The containing application
* **SafarAI Extension**: The actual Safari extension

Key files in the Extension:

* `manifest.json`: Extension configuration (permissions, scripts, icons)
* `background.js`: Background script (handles API calls, manages state)
* `content.js`: Content script (reads page content)
* `popup.html/js/css`: **Chat interface UI** (main focus)
* `Resources/images/`: Extension icons

**3. Build and Enable Extension**

* Build the project (⌘B)
* Run the app (⌘R)
* Open Safari > Preferences > Extensions
* Enable "SafarAI"
* Grant necessary permissions

### Architecture Components

```
Popup UI (popup.html)
       ↓
Background Script (background.js)
       ↓
OpenAI/LLM API
       ↑
Content Script (content.js) → Reads page content
```

**Data Flow:**

1. User clicks extension icon → popup.html opens
2. User types message in chat → popup.js sends to background.js
3. If "Summarize page" requested → background.js requests content from content.js
4. content.js extracts page content → sends back to background.js
5. background.js calls OpenAI API with message + page content
6. API response → background.js → popup.js → Display in chat UI

### Required Permissions

```json
{
  "permissions": [
    "activeTab",
    "storage"
  ]
}
```

* `activeTab`: Access current page content
* `storage`: Store API keys and chat history

### Implementation Steps

**Phase 1: Basic Popup Chat**

* Modify `popup.html` to create chat UI (input box, message list)
* Implement basic message display in `popup.js`
* Store OpenAI API key in settings
* Test popup opens and displays correctly

**Phase 2: LLM Integration**

* Implement API call handler in `background.js`
* Connect popup to background script via `browser.runtime.sendMessage()`
* Handle streaming responses from OpenAI
* Add error handling and loading states

**Phase 3: Page Content Access**

* Implement page content extraction in `content.js`
* Add commands: "Summarize this page", "Answer about page"
* Send page content as context to LLM
* Display page context indicator in chat

**Phase 4: Advanced Features**

* Multiple LLM backends (OpenAI, Anthropic, local)
* MCP server integration
* Chat history persistence
* Settings UI for API keys

### Technical Notes

**Popup Characteristics:**

* Opens when toolbar icon clicked
* Closes when user clicks outside
* Size configurable in manifest.json (recommend 400x600px)
* Can communicate with background script and content scripts

**Content Script Access:**

* Can read page DOM, text content, and structure
* Cannot make API calls (CSP restrictions)
* Must send data to background script for processing

**Background Script:**

* Persists between page loads
* Handles all API calls to LLM backends
* Manages extension storage (API keys, settings)
* Routes messages between popup and content scripts

### Resources

* [Creating a Safari web extension](https://developer.apple.com/documentation/safariservices/creating-a-safari-web-extension)
* [Messaging between app and JavaScript](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
