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
