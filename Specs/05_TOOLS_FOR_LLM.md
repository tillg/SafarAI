# Tools for LLM

## Goal

Currently the LLM gets page content directly in the prompt (always included). This is inefficient for large pages and repeated interactions.

**Better approach**: Give the LLM tools to interact with the browser on-demand.

**Decisions**:
- Use native tool calling API (OpenAI function calling)
- Keep auto-including page context by default, add checkbox to disable
- Tool calls shown in event timeline + subtle chat indicator
- Tool results expandable in event history
- Highlight errors, don't hide them
- Cache tool results in event log

---

## LLM Tool Calling Support

### ✅ Supported (Native Tool Calling)
- **OpenAI** (GPT-3.5-turbo+, GPT-4+): Function calling API
- **Anthropic** (Claude 3+): Tool use API (different format)
- **Google Gemini**: Function calling
- **Grok** (xAI): Function calling support
- **Ollama**: Model-dependent (LLaMA 3.1+, Mistral, others support it)

### ❌ Not Supported
- **Apple Intelligence/macOS LLMs**: No public tool calling API
- **Older models**: GPT-3, Claude 1/2
- **Most local models**: Unless explicitly trained for it

### API Format Comparison

**OpenAI**:
```json
{
  "tools": [{"type": "function", "function": {...}}],
  "tool_choice": "auto"
}
```
Response: `tool_calls` array with `id`, `function.name`, `function.arguments`

**Anthropic**:
```json
{
  "tools": [{"name": "...", "description": "...", "input_schema": {...}}]
}
```
Response: `content` array with `type: "tool_use"`, includes `id`, `name`, `input`

**Ollama**:
Same as OpenAI format (compatible), but model must support it.

**Recommendation**: Start with OpenAI, add Anthropic adapter later (same tool definitions, different wire format). Till: Yes, that's what we do!

---

## Priority Tools (First 6)

1. `getPageText()` - Current functionality as tool
2. `getPageStructure()` - DOM outline (headings, sections)
3. `getImage(selector)` - Get specific image
4. `searchOnPage(query)` - Find text on page
5. `getLinks()` - Extract all links
6. `openInNewTab(url)` - Open new tab

---

## Implementation Plan

### Step 1: Tool Infrastructure
**Files**: `AIService.swift`, create `Models/Tool.swift`

- Define tool schema struct
- Create 6 tool definitions
- Update `chatOpenAI()` to include tools in request
- Handle `tool_calls` in response
- Execute tool → send result → continue conversation loop

### Step 2: Tool Executor
**Files**: Create `Services/ToolExecutor.swift`

- Execute tool calls via ExtensionService
- Request data from content script via background.js
- Return results as JSON strings
- Cache results in memory for conversation

### Step 3: Content Script Tools
**Files**: `content.js`

Add message handlers:
- `getPageStructure` → return DOM outline
- `getImage` → return image as base64
- `searchOnPage` → return matches with context
- `getLinks` → return all links

### Step 4: Event Logging
**Files**: Update `ExtensionService.swift`, `BrowserEvent.swift`

- Add tool event types: `tool_call`, `tool_result`
- Log tool name, arguments, results
- Show in event timeline with expand/collapse

### Step 5: UI Indicators
**Files**: `ContentView.swift`

- Add checkbox: "Include page context automatically"
- Show subtle indicator during tool execution
- Tool calls appear as events in timeline

---

## Event Log Format Change

**Current**: Text-based log (problematic for long prompts)
```
2026-01-11 10:23:45 [AI Query] What do i see? (https://...)
```

**New**: JSON Lines format (one JSON object per line)
```json
{"timestamp":"2026-01-11T10:23:45Z","type":"ai_query","title":"What do i see?","url":"https://...","details":{...}}
```

**Benefits**:
- Long prompts don't break parsing
- Easy to parse and query
- Can store complex data (tool arguments, results)
- Standard format

**Implementation**: Update `saveEventToLog()` in ExtensionService to write JSON instead of formatted text.

---

## Tool Execution Flow

```
User: "What images are on this page?"
  ↓
AIService.chat() → OpenAI API (with tools array)
  ↓
Response: tool_calls: [{"name": "getImages", "id": "call_1"}]
  ↓
ToolExecutor.execute("getImages") → ExtensionService → background.js → content.js
  ↓
content.js extracts images → returns to app
  ↓
Log event: 🔧 Tool Call: getImages
  ↓
Send result back to OpenAI
  ↓
Final response: "The page has 3 images: ..."
  ↓
Display in chat
```

---

## Open Questions

1. **Screenshot format**: Base64 in JSON or save to temp file and send path?
2. **Tool timeout**: How long to wait for tool execution? 5s? 10s?
3. **Concurrent tools**: Can LLM call multiple tools in parallel? Execute sequentially or parallel?
4. **Context window**: Keep tool results in conversation history or just pass once?

---

## Estimated Time

- Step 1 (Infrastructure): 3-4 hours
- Step 2 (Tool executor): 2-3 hours
- Step 3 (Content script tools): 3-4 hours
- Step 4 (Event logging): 1-2 hours
- Step 5 (UI indicators): 1-2 hours
- JSON log refactor: 1 hour

**Total**: ~12-16 hours
