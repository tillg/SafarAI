# Content as Markdown

## Goal

Convert web page content to clean, readable Markdown format for better LLM consumption and token efficiency.

**Why Markdown**:
- More compact than HTML (fewer tokens)
- LLMs understand Markdown structure better
- Removes noise (scripts, styles, ads)
- Preserves semantic structure (headings, lists, links)

**Decisions**:
- Use SwiftHTMLtoMarkdown library (pure Swift)
- Extract full `outerHTML` (no content filtering for now)
- Include image links in Markdown
- Preserve code blocks as Markdown code blocks
- Tables handled by library (accept limitations)
- Lazy loading delay configurable in settings
- Wait for `document.readyState === 'complete'` + configurable delay

---

## Architecture

### Data Flow

```
Browser (after JS execution + delay)
  ↓
document.documentElement.outerHTML
  ↓
Swift: SwiftHTMLtoMarkdown
  ↓
Clean Markdown
  ↓
LLM
```

**Key Points**:
- Extract HTML AFTER JavaScript renders DOM ✅
- Works with React, Vue, Angular, SPAs ✅
- Pure Swift, no Node.js or WebKit dependency ✅
- Fallback to plain text if conversion fails ✅

---

## Dynamic Sites Support

### Timing Strategy

**Problem**: JavaScript-heavy sites (Medium, Twitter/X) build content dynamically

**Solution**:
1. Wait for `document.readyState === 'complete'`
2. Add configurable delay (default: 1s) for lazy-loaded content
3. Extract `outerHTML` (all dynamic content captured)

**User Setting**: "Content extraction delay" in Settings
- Default: 1000ms
- Range: 0-5000ms (0s to 5s)
- Helps with infinite scroll, lazy images, etc.

---

## Implementation Plan

### Step 1: Add Swift Package
**File**: Xcode project
- Add dependency: `https://github.com/ActuallyTaylor/SwiftHTMLtoMarkdown`

### Step 2: Update Content Extraction
**File**: `content.js`

Add `getPageAsHTML()`:
```javascript
function getPageAsHTML() {
    return {
        html: document.documentElement.outerHTML,
        url: window.location.href,
        title: document.title
    };
}
```

Modify `extractPageContent()` to:
- Get `outerHTML` instead of walking DOM
- Send to Swift for Markdown conversion

### Step 3: Create Markdown Converter
**File**: Create `Services/MarkdownConverter.swift`

```swift
import SwiftHTMLtoMarkdown

class MarkdownConverter {
    func convert(html: String) -> String? {
        do {
            return try HTMLToMarkdown.parse(html: html).asMarkdown()
        } catch {
            logError("Markdown conversion failed: \(error)")
            return nil
        }
    }
}
```

### Step 4: Update PageContent Model
**File**: `PageContent.swift`

Add fields:
- `html: String?` - Raw HTML
- `markdown: String?` - Converted Markdown
- Keep `text: String` as fallback

### Step 5: Update ExtensionService
**File**: `ExtensionService.swift`

When receiving page content:
1. Store HTML
2. Convert to Markdown
3. Use Markdown in LLM prompts (fallback to text if conversion fails)

### Step 6: Add Settings
**File**: `SettingsView.swift`

Add slider: "Content extraction delay: [0-5000ms]"

---

## Technical Details

### Conversion Settings

SwiftHTMLtoMarkdown preserves:
- ✅ Headings (`<h1>` → `# Heading`)
- ✅ Lists (`<ul>` → `- item`)
- ✅ Links (`<a>` → `[text](url)`)
- ✅ Images (`<img>` → `![alt](src)`) - Links included, not base64
- ✅ Code blocks (`<pre><code>` → ` ```code``` `)
- ⚠️ Tables (limited support, but acceptable)
- ✅ Emphasis (`<em>` → `*italic*`, `<strong>` → `**bold**`)

### Error Handling

**If Markdown conversion fails**:
1. Log error to events timeline
2. Fall back to current plain text extraction
3. Show warning indicator (yellow) in UI
4. LLM still gets content, just not as Markdown

---

## Main Content Detection - Explained

**Your Question**: "Use Readability algorithm or simple selectors?"

**Explanation**:

**Simple Selectors** (what we do now):
- Look for `<main>`, `<article>`, `.content`, `#main-content`
- Fast and simple
- Might include sidebars, navigation, ads

**Readability Algorithm** (Mozilla's approach):
- Analyzes entire page to find "main content"
- Removes navigation, sidebars, ads, footers automatically
- Used by Firefox Reader Mode
- More complex but cleaner results

**Decision**: For now, extract **full page HTML** (no filtering). SwiftHTMLtoMarkdown will convert everything, and the LLM can handle some noise. If results are too noisy, we can add Readability-style filtering later.

---

## Implementation Settings

**New Setting in SettingsView**:
```
Content Extraction Delay: [slider 0-5000ms]
Default: 1000ms

Info: "Delay after page loads before extracting content.
      Increase for sites with heavy lazy-loading."
```

---

## Estimated Time

- Step 1 (Add package): 15 min
- Step 2 (Update content.js): 30 min
- Step 3 (Markdown converter): 1 hour
- Step 4 (Update PageContent): 30 min
- Step 5 (ExtensionService integration): 1 hour
- Step 6 (Settings UI): 30 min

**Total**: ~4 hours
