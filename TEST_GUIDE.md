# SafarAI Testing Guide

## Quick Start Test

**1. Launch & Connect**
- Run app in Xcode (⌘R)
- Open Safari
- Navigate to google.com
- Check for green dot in app header ✅

**2. Test Chat Without Page Context**
- In app: Click X to remove page context
- Type: "Hello, what can you do?"
- Press Enter or click Send
- Should get AI response ✅

**3. Test Chat With Page Context**
- Navigate to a Wikipedia article in Safari
- App should auto-load page (banner appears)
- Type: "Summarize this page"
- AI should respond with summary ✅

**4. Test Settings**
- App menu → Settings (⌘,)
- Verify green dot shows "Connected"
- Verify current page title appears
- Change API key, click Save
- Close settings ✅

---

## Test Scenarios

### Test 1: Extension Connection
**Steps:**
1. Launch app
2. Wait 2 seconds

**Expected:**
- Green dot appears in header
- Status changes from "Disconnected" to connected

**If fails:**
- Check Xcode console for "Extension ready"
- Check Safari extension is enabled

---

### Test 2: Page Content Auto-Load
**Steps:**
1. With app running, navigate to different pages in Safari:
   - google.com
   - wikipedia.org
   - news.ycombinator.com

**Expected:**
- Page title banner updates automatically
- New page context appears within 1 second

**If fails:**
- Check Safari extension background console for errors
- Check if content script is injecting (⌘⌥C on page)

---

### Test 3: Basic Chat
**Steps:**
1. Type: "What is 2+2?"
2. Press Enter

**Expected:**
- Message appears in blue bubble (right side)
- "Thinking..." appears briefly
- AI response appears in gray bubble (left side)

**If fails:**
- Check API key is set (Settings)
- Check Xcode console for API errors

---

### Test 4: Page-Aware Chat
**Steps:**
1. Navigate to https://en.wikipedia.org/wiki/Safari_(web_browser)
2. Wait for page banner to appear
3. Type: "What is this article about?"
4. Send

**Expected:**
- AI mentions Safari browser
- Response is contextual to page

**If fails:**
- Check page banner shows correct title
- Check Settings shows current page

---

### Test 5: Manual Refresh
**Steps:**
1. Navigate to any page
2. Click "Refresh" button (↻) in header

**Expected:**
- Page banner updates
- Console shows "Requesting page content..."

---

### Test 6: Multi-Turn Conversation
**Steps:**
1. Navigate to any article
2. Ask: "Summarize this page"
3. Then ask: "What are the key points?"
4. Then ask: "Explain point 2 in detail"

**Expected:**
- Each response references page content
- Conversation maintains context

---

### Test 7: Tab Switching
**Steps:**
1. Open 3 tabs in Safari:
   - Tab 1: https://google.com
   - Tab 2: [https://wikipedia.org (any article)](https://en.wikipedia.org/wiki/Albert_Einstein)
   - Tab 3: [github.com](https://github.com)
2. Switch between tabs

**Expected:**
- Page banner updates to show current tab
- Title changes instantly

**If fails:**
- Check extension console for "Tab changed" logs

---

### Test 8: Extension Restart
**Steps:**
1. App running, extension connected (green dot)
2. Safari → Preferences → Extensions
3. Disable SafarAI
4. Wait 2 seconds
5. Re-enable SafarAI

**Expected:**
- Green dot disappears when disabled
- Green dot reappears when enabled
- Page content reloads automatically

---

## Console Debugging

### Native App Console (Xcode ⌘⇧Y)

**Healthy logs:**
```
ExtensionService initializing...
Setting up App Groups listener: group.com.grtnr.SafarAI
✅ App Groups polling started
Pinging extension...
Message 'ping' sent successfully
📥 Received message from App Group!
Decoded message: extensionReady
Extension ready, version: 1.0
Extension connected
```

**Problem indicators:**
- `❌ Failed to access App Group` → Check App Groups capability
- `Error sending message` → Check bundle IDs
- `API key not set` → Configure settings

### Extension Background Console

**Open:** Safari → Develop → Web Extension Background Pages → SafarAI

**Healthy logs:**
```
SafarAI background script loaded
✅ browser.runtime.connectNative() succeeded
✅ Port listeners attached
📤 Sending extensionReady via sendNativeMessage...
Requesting content from tab: ...
Received content from tab: Google
✅ sendNativeMessage called for: pageContent
```

**Problem indicators:**
- `❌ Failed to connect` → Native app not running
- `Content script returned null` → Content script not injecting
- `Error getting page content` → Page not accessible

### Content Script Console

**Open:** On any webpage, press **⌘⌥C** → Console tab

**Healthy logs:**
```
🟢 SafarAI content script loaded on: https://...
Content script is ALIVE and listening for messages
📥 Content script received message: ...
✅ Extracting page content...
📦 Extracted content: {url: ..., title: ..., textLength: 1234}
```

**Problem indicators:**
- No "🟢 SafarAI content script loaded" → Script not injecting
- No "📥 Content script received" → Background not requesting

---

## Common Issues

### Issue: Green Dot Never Appears

**Check:**
1. Is native app running?
2. Is Safari extension enabled? (Preferences → Extensions)
3. App Groups added to BOTH targets?
4. Bundle IDs correct? (com.grtnr.SafarAI, com.grtnr.SafarAI.Extension)

**Fix:**
- Verify App Groups: group.com.grtnr.SafarAI in both targets
- Clean build (⌘⇧K) and rebuild

### Issue: Page Content Not Loading

**Check:**
1. Does page banner appear at all?
2. Check content script console (⌘⌥C on page)
3. Is content script being injected?

**Fix:**
- Verify manifest.json has: `"matches": ["<all_urls>"]`
- Check content.js is in Extension target in Xcode
- Reload extension in Safari

### Issue: AI Not Responding

**Check:**
1. API key set in Settings?
2. Check Xcode console for API errors
3. Network connection working?

**Fix:**
- Set valid OpenAI API key in Settings
- Check error messages in chat
- Verify API key at https://platform.openai.com/api-keys

### Issue: Chat Messages Don't Appear

**Check:**
1. Input field enabled?
2. Send button clickable?
3. Console errors?

**Fix:**
- Make sure app is focused
- Check for Swift errors in Xcode console

---

## Performance Tests

### Memory Usage
**Check:** Activity Monitor → SafarAI app
**Expected:** < 100MB

### CPU Usage
**Check:** Activity Monitor → SafarAI app
**Expected:** < 5% when idle, < 20% when processing

### Response Time
**Expected:**
- Page content load: < 1 second
- AI response: 2-5 seconds (depends on OpenAI)
- Tab switch update: < 500ms

---

## Test Checklist

- [ ] App launches without errors
- [ ] Green dot appears within 2 seconds
- [ ] Page content auto-loads on navigation
- [ ] Chat works without page context
- [ ] Chat works with page context
- [ ] Settings window opens and saves
- [ ] Tab switching updates page banner
- [ ] Extension can be disabled/re-enabled
- [ ] Multiple messages in conversation work
- [ ] Page refresh button works
- [ ] App survives Safari restart
- [ ] Memory usage acceptable
- [ ] No crashes or errors in console

---

## Regression Tests

After making changes, run these quick tests:

**Smoke Test (2 minutes):**
1. Launch app → Green dot ✅
2. Navigate to google.com → Banner updates ✅
3. Ask "What is this page?" → Gets response ✅

**Full Test (5 minutes):**
- Run all 8 test scenarios above

---

## Logging Levels

**Normal operation:** Should see minimal logs
**Debug mode:** Extensive logs with timestamps

**To see extension logs:**
- Background: Safari → Develop → Web Extension Background Pages
- Content: On page → ⌘⌥C → Console tab
- Native app: Xcode → Console (⌘⇧Y)
