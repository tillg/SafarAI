# More Tools

## Problem

Current tools are broken because Safari native app uses fire-and-forget messaging. Tools that need fresh DOM queries or content script responses can't return results.



## Architecture Solution

**Request/Response via Background Script:**

```
Native App → Extension (background.js) → Content Script
     ↑                                          ↓
     └──────────── Response ←──────────────────┘
```

**Implementation:**

- Native sends request with unique ID via `dispatchMessage()`
- Background script routes to content script via `browser.tabs.sendMessage()`
- Content script returns result to background
- Background sends result to native via `sendNativeMessage()`
- Native matches response by ID with settable timeout (default: 10s)
- Timeout errors show in red in event history with human-readable message

## Tool List

**Currently working:**

- `getPageText` - Extract text/markdown from current page
- `searchOnPage` - Search in extracted text
- `openInNewTab` - Open URLs

**To fix (need async communication):**

- `getPageStructure` - Fresh DOM query for headings/sections
- `getImage` - Get image by CSS selector
- `getLinks` - Extract links from page

**To add:**

- `getTabs` - List all open tabs (fixes confusion issue)
- `getFullPageScreenshot` - Visual page capture
- `scrollPage` - Navigate long pages
- `clickElement` - Interact with page elements

## Implementation Steps

1. Add request/response correlation to `ExtensionService.swift` and `background.js`
2. Add configurable timeout setting (default: 10s)
3. Implement `getTabs` in background.js (no content script needed)
4. Fix broken tools using new async pattern
5. Add new tools as needed
6. Test timeout handling with slow/blocked content scripts

## Tool Specification: getFullPageScreenshot

### Purpose

Captures a visual screenshot of the currently visible viewport. Useful for AI analysis of visual layout, design elements, or when page content is primarily visual.

### Browser-Side Implementation

Implemented in `background.js` using the browser's native screenshot API:

```javascript
// In background.js
async function captureScreenshot(tabId) {
  const dataUrl = await browser.tabs.captureVisibleTab(null, {
    format: 'png'
  });

  return dataUrl;
}
```

### Image Format & Passing

**Format: PNG**
- Lossless compression for quality
- Data URL format: `data:image/png;base64,iVBORw0KGgoAAAA...`
- Typical size: ~500KB - 5MB for standard viewport

**Message Flow:**

```
background.js → Native App
     ↓
sendNativeMessage({
  type: 'toolResponse',
  requestId: requestId,
  result: {
    imageDataUrl: dataUrl,
    format: 'png',
    dimensions: {
      width: viewportWidth,
      height: viewportHeight
    },
    captureTime: ISO timestamp
  }
})
```

**Swift Side Handling:**

```swift
// In ToolExecutor.swift
case "getFullPageScreenshot":
    if let imageDataUrl = result["imageDataUrl"] as? String,
       let imageData = extractDataFromDataURL(imageDataUrl),
       let image = NSImage(data: imageData) {

        // Return as base64 string to LLM
        let base64String = imageData.base64EncodedString()
        return base64String
    }
```

### Tool Definition

```swift
Tool(
    name: "getFullPageScreenshot",
    description: "Captures a PNG screenshot of the currently visible viewport",
    inputSchema: .object(
        properties: [:],
        required: []
    )
)
```

### Implementation Notes

- No parameters needed - always captures current viewport as PNG
- Uses default timeout (10s) - sufficient for viewport capture
- Safari extension messages support up to ~50MB (more than adequate)
- Future enhancement: Full-page scrolling capture (deferred)

### Privacy & Permissions

**Manifest.json:**

```json
{
  "permissions": [
    "activeTab",
    "tabs",
    "<all_urls>"
  ]
}
```

**Privacy Considerations:**
- Screenshot captures ALL visible content (including sensitive data)
- User should be aware this will be sent to LLM
- Consider showing preview confirmation in future version
