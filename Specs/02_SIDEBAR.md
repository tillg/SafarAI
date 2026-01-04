# Sidebar Implementation

## Goal

Implement a persistent side-by-side chat interface that appears alongside webpage content, replacing the current toolbar popup approach.

## Why

**Current popup limitations:**
* Closes when clicking outside
* Not visible while reading page content
* Can't maintain ongoing conversation while browsing
* Requires reopening for each interaction

**Desired experience:**
* Chat interface always visible on the left
* Page content visible on the right
* Seamless back-and-forth between reading and chatting
* True integration with browsing experience

## Current State

We have a working toolbar popup extension with:
* Phase 1: Basic chat UI ✓
* Phase 2: OpenAI API integration ✓
* Phase 3: Page content access ✓

Now we want to transform this into a sidebar experience.

---

## Architectural Options

### Option 1: Content Script Injected Sidebar (RECOMMENDED)

**How it works:**
* Content script injects iframe on every page load
* Iframe loads sidebar.html from extension resources
* Page content shifts right via CSS (`margin-left: 400px`)
* Sidebar positioned fixed on left side

**Architecture:**
```
Content Script (content.js)
  ↓ injects
Sidebar iframe (sidebar.html)
  ↓ contains
Chat UI (moved from popup.html)
  ↓ communicates with
Background Script (background.js)
  ↓ calls
OpenAI API
```

**Pros:**
* Full control over positioning and behavior
* Can persist across page navigation
* Keyboard shortcuts for show/hide
* Works on most websites

**Cons:**
* CSS conflicts with page layouts
* Some responsive sites break with margin-left
* Need to handle z-index wars
* Can interfere with page functionality

### Option 2: Browser Sidebar API

**Safari does NOT support this.**

Firefox has `browser.sidebarAction` API, but Safari Web Extensions don't have an equivalent. This is not an option for Safari.

### Option 3: Hybrid Approach

**How it works:**
* Keep toolbar popup for quick access
* Add keyboard shortcut (⌘⇧A) to inject sidebar on demand
* Sidebar can be toggled on/off per tab
* Best of both worlds

**Pros:**
* Flexibility - user chooses when to use sidebar
* Less intrusive than always-on sidebar
* Popup still works for quick questions

**Cons:**
* More complex codebase (two UI modes)
* State management between popup and sidebar
* User confusion about which mode to use

---

## Implementation Plan (Option 1)

### Phase 1: Sidebar Injection

**1. Create sidebar.html**
* Copy popup.html structure
* Optimize for fixed height (100vh)
* Adjust styling for sidebar context

**2. Update content.js**
* Check if sidebar already exists (avoid duplicates)
* Create iframe element
* Set iframe src to `browser.runtime.getURL('sidebar.html')`
* Apply CSS for fixed positioning
* Inject into page body
* Shift page content right

**3. Add toggle functionality**
* Listen for keyboard shortcut (⌘⇧A)
* Show/hide sidebar with animation
* Remove page margin when hidden
* Store state in `browser.storage.local`

### Phase 2: Communication

**1. Update messaging**
* Sidebar → Content Script → Background Script
* Use `window.postMessage` for iframe communication
* Content script relays messages via `browser.runtime.sendMessage`

**2. Page content access**
* Content script already extracts page content
* Sidebar requests via postMessage
* Same flow as current implementation

### Phase 3: State Management

**1. Per-tab state**
* Track sidebar visibility per tab
* Remember open/closed state
* Sync with background script

**2. Persistence**
* Save chat history per tab/URL
* Restore conversation on page reload
* Clear on navigation (optional)

### Phase 4: CSS Hardening

**1. Handle edge cases**
* Fixed position elements on page
* Responsive breakpoints
* Full-width content
* Overlays and modals

**2. Exclusions**
* Add exclusion list for problematic sites
* Disable on banking sites (security)
* User-configurable blocklist

---

## Technical Considerations

### CSS Implementation

**Sidebar styling:**
```css
#safarai-sidebar {
  position: fixed;
  top: 0;
  left: 0;
  width: 400px;
  height: 100vh;
  z-index: 2147483647; /* Maximum z-index */
  border: none;
  box-shadow: 2px 0 10px rgba(0,0,0,0.1);
}
```

**Page shift:**
```css
body {
  margin-left: 400px !important;
  transition: margin-left 0.3s ease;
}

body.safarai-sidebar-hidden {
  margin-left: 0 !important;
}
```

**Challenges:**
* Pages with `overflow-x: hidden` on body
* Fixed position elements that don't respect body margin
* CSS Grid/Flexbox layouts that span viewport width
* Media queries that break with reduced width

### Communication Flow

**Sidebar → Background:**
```javascript
// sidebar.js
window.parent.postMessage({
  type: 'safarai-message',
  action: 'chat',
  data: { message: 'Hello' }
}, '*');

// content.js
window.addEventListener('message', (event) => {
  if (event.data.type === 'safarai-message') {
    browser.runtime.sendMessage(event.data);
  }
});
```

**Background → Sidebar:**
```javascript
// background.js
browser.tabs.sendMessage(tabId, {
  action: 'response',
  data: { message: 'AI response' }
});

// content.js
browser.runtime.onMessage.addListener((msg) => {
  const iframe = document.getElementById('safarai-sidebar');
  iframe.contentWindow.postMessage({
    type: 'safarai-response',
    data: msg.data
  }, '*');
});
```

### Lifecycle Management

**Injection timing:**
* `document_idle` - After DOM loaded but before images
* Check for existing sidebar before injecting
* Handle SPA navigation (listen for URL changes)

**Cleanup:**
* Remove sidebar on navigation (optional)
* Clear event listeners
* Store state before removal

---

## Open Questions

### 1. Sidebar Behavior

**Always visible or opt-in?**
* **Option A:** Inject on all pages by default, keyboard shortcut to hide
* **Option B:** Hidden by default, keyboard shortcut to show
* **Option C:** Remember per-site preference

**Recommendation:** Start with Option B (opt-in) to avoid disrupting normal browsing.

### 2. Width and Responsiveness

**Fixed or resizable?**
* **Fixed:** 400px (simpler, consistent)
* **Resizable:** Drag handle to adjust (more complex)
* **Responsive:** Auto-adjust based on viewport width

**Recommendation:** Start with fixed 400px, add resizing in v2.

### 3. Page Layout Strategy

**How to handle page shift?**
* **Option A:** `margin-left` on body (simple, some pages break)
* **Option B:** Transform/translate page content (more robust)
* **Option C:** Overlay sidebar, no shift (blocks content)

**Recommendation:** Start with Option A, detect problematic pages and fall back to overlay.

### 4. State Persistence

**Should conversations persist?**
* **Per tab:** Each tab has own conversation
* **Per URL:** Conversation tied to URL, survives reload
* **Global:** One conversation for all pages

**Recommendation:** Start with per-tab, add per-URL persistence later.

### 5. Exclusions

**Which pages should be excluded?**
* Browser internal pages (chrome://, about:)
* Banking/financial sites
* Sites with custom exclusion by user
* Sites that break with sidebar (auto-detect?)

**Recommendation:** Start with browser pages + user exclusion list.

### 6. Performance

**When to inject content script?**
* All pages immediately (higher memory usage)
* Only when activated (delayed first use)
* Smart detection (only on content pages)

**Recommendation:** Start with all pages, optimize later if needed.

---

## Migration Path

### Step 1: Keep Popup Working
* Don't remove popup.html yet
* Create sidebar.html as copy
* Test sidebar independently

### Step 2: Add Toggle
* Keep both popup and sidebar functional
* User can choose which to use
* Keyboard shortcut for sidebar

### Step 3: Deprecate Popup
* Once sidebar is stable
* Add migration notice
* Eventually remove popup code

**Reason:** Gradual migration reduces risk, allows user feedback.

---

## Implementation Steps

### Milestone 1: Basic Sidebar Injection
- [ ] Create sidebar.html (copy from popup.html)
- [ ] Create sidebar.js (copy from popup.js)
- [ ] Create sidebar.css (optimize for fixed height)
- [ ] Update content.js to inject sidebar iframe
- [ ] Add CSS to shift page content
- [ ] Test on simple websites

### Milestone 2: Communication
- [ ] Implement postMessage bridge in content.js
- [ ] Update sidebar.js to use postMessage
- [ ] Test chat functionality through bridge
- [ ] Verify page content access works

### Milestone 3: Toggle & Keyboard Shortcut
- [ ] Add keyboard shortcut to manifest.json
- [ ] Implement show/hide logic
- [ ] Add smooth animations
- [ ] Store visibility state
- [ ] Test across page navigations

### Milestone 4: Hardening
- [ ] Test on top 20 popular websites
- [ ] Fix CSS conflicts
- [ ] Add exclusion list
- [ ] Handle edge cases (modals, fixed elements)
- [ ] Performance testing

### Milestone 5: Polish
- [ ] Add resize handle (optional)
- [ ] Improve animations
- [ ] Add settings for sidebar width
- [ ] Dark mode support
- [ ] Documentation

---

## Risks & Mitigations

### Risk 1: CSS Conflicts
**Problem:** Sidebar breaks page layouts

**Mitigation:**
* Extensive testing on popular sites
* User exclusion list
* Auto-detect broken layouts and disable
* Provide "Report broken site" button

### Risk 2: Performance Impact
**Problem:** Injecting on all pages increases memory usage

**Mitigation:**
* Lazy-load sidebar iframe content
* Remove sidebar on inactive tabs
* Use lightweight communication protocol
* Monitor performance metrics

### Risk 3: Security Concerns
**Problem:** Injected content could be exploited

**Mitigation:**
* Use CSP-compliant iframe
* Sanitize all postMessage data
* Validate origins
* Exclude sensitive sites by default

### Risk 4: User Disruption
**Problem:** Users don't want sidebar always visible

**Mitigation:**
* Opt-in by default (keyboard shortcut to enable)
* Remember per-site preference
* Easy toggle (keyboard shortcut, close button)
* Clear UI feedback

---

## Success Criteria

* [ ] Sidebar injects reliably on 95% of websites
* [ ] Chat functionality works identically to popup
* [ ] Page content access functions correctly
* [ ] Performance impact < 50MB memory, < 5% CPU
* [ ] Keyboard shortcut works consistently
* [ ] No visible CSS conflicts on top 20 sites
* [ ] State persists across page reloads
* [ ] User can easily disable/enable per site

---

## Resources

* [Chrome Extension Content Script Injection](https://developer.chrome.com/docs/extensions/mv3/content_scripts/)
* [iframe postMessage API](https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage)
* [Safari Web Extension Commands](https://developer.apple.com/documentation/safariservices/safari_web_extensions/assessing_your_safari_web_extension_s_browser_compatibility)

## Next Steps

1. **Get user approval** on approach (Option 1 vs Option 3)
2. **Answer open questions** (behavior, width, state, etc.)
3. **Create Milestone 1** implementation
4. **Test on your most-used websites**
5. **Iterate based on real-world usage**
