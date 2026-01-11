# Visualize Browser Events

## Goal

Display browser events (tab switches, page loads, link clicks, tab open/close) in a vertical timeline panel alongside the chat interface.

## Current State

**Already Working** ✅:
- Tab switches → `tabChanged` event sent to native app (background.js:100-109)
- Page loads → `pageLoaded` event sent to native app (background.js:112-125)
- Native messaging via App Group shared container (polls every 0.1s)
- ContentView.swift is the main chat UI (SwiftUI)

**Missing** ❌:
- Tab open/close listeners
- Link click tracking in content.js
- Event storage on disk
- UI to display events

---

## Architecture Decisions

### Storage: Native App (Disk)
- Events sent from background.js → native app via existing `sendToNative()`
- Native app (ExtensionService) stores events **on disk in human-readable format** (formatted log lines)
- ContentView reads events directly from ExtensionService
- Events appear in UI immediately when received (already polling at 0.1s)

### Event Capture
- Capture **all events**  (tab switch, open, close, page load, link clicks)
- Log everything to disk

### UI Layout: Separate Timeline Panel
- Events appear in a **dedicated vertical timeline panel** always at the right side to chat
- **Infinite scroll** with auto-scroll to bottom by default
- Clear visual separation from chat messages

### Event Card Design
```
🔄 Tab Switch -> Github.com    10:23 AM  [▼]
```
Collapsed by default. Click to expand for details.

**Elements**:
- Icon (🔄 switch, ➕ open, ➖ close, 🔗 navigate)
- Brief label with key info
- Timestamp
- Expand/collapse indicator

---

## Implementation Plan

### Step 1: Add Missing Event Listeners
**File**: `background.js`
- Add `tabs.onCreated` → send `tabOpened` event
- Add `tabs.onRemoved` → send `tabClosed` event

**File**: `content.js`
- Add link click listener → send `linkClicked` event to background script

### Step 2: Create Event Storage in Native App
**Files**: Create `Models/BrowserEvent.swift`, update `ExtensionService.swift`
- Create `BrowserEvent` struct:
  ```swift
  struct BrowserEvent: Identifiable, Codable {
      let id: UUID
      let timestamp: Date
      let type: EventType // tab_switch, tab_open, tab_close, page_load, link_click
      let url: String?
      let title: String?
      let details: [String: String]? // Additional event-specific data
  }
  ```
- Add to ExtensionService:
  ```swift
  @Published var events: [BrowserEvent] = []
  ```
- Add event handling in `handleMessage()` for new event types
- Implement disk persistence (save to JSON file in app container)
- Load events from disk on app start

### Step 3: Create Event Timeline UI
**Files**: Create `Views/EventTimelineView.swift`, `Views/EventCardView.swift`
- EventTimelineView: ScrollView with LazyVStack of events
- EventCardView: Collapsible card with icon, label, timestamp
- Auto-scroll to bottom on new events
- Expandable details section

### Step 4: Integrate into ContentView
**File**: `ContentView.swift`
- Add EventTimelineView to layout (user-configurable position)
- Wire up to `extensionService.events`
- Add position toggle in settings (left/right/between)

### Step 5: Settings & Polish (Later)
- Event type filtering UI
- Clear history button
- Export events option

---

## Event Data Structure

**JavaScript (from browser extension)**:
```javascript
{
  action: "browserEvent",
  event: {
    type: "tab_switch" | "tab_open" | "tab_close" | "page_load" | "link_click",
    timestamp: 1673892345678,
    tabId: 123,
    url: "https://github.com",
    title: "GitHub",
    details: { /* event-specific data */ }
  }
}
```

**Swift (stored on disk)**:
Saved as JSON array in Application Support directory.

---

## Communication Flow

```
Browser Event → background.js → sendToNative() → ExtensionService
                                                      ↓
                                              Save to disk (JSON)
                                              Update @Published events array
                                                      ↓
                                              ContentView auto-updates
                                              EventTimelineView displays
```

---

## Open Questions (Future)

1. **Page content capture**: Extract/store DOM content when event happens, or on-demand when expanded?
2. **Performance toggle**: Option to disable event tracking?
3. **Privacy filtering**: Filter sensitive domains/events?
4. **Event retention**: How long to keep events on disk? Rotation policy?

---

## Estimated Time

- Step 1 (Event listeners): 30-60 min
- Step 2 (Native storage): 1-2 hours
- Step 3 (UI components): 2-3 hours
- Step 4 (Integration): 1 hour
- **Total**: ~5-7 hours
