# LLM Max Token

Better token limit handling with external model database.

## Token Limits Explained

```text
┌─────────────────────────────────────────────┐
│           CONTEXT WINDOW (e.g. 16K)         │
├─────────────────────────────────────────────┤
│  INPUT                    │  OUTPUT         │
│  • System prompt          │  • LLM response │
│  • Page content           │  • Tool calls   │
│  • Chat history           │                 │
│  • Tool definitions       │                 │
├─────────────────────────────────────────────┤
│  INPUT + OUTPUT must fit within CONTEXT     │
└─────────────────────────────────────────────┘
```

**Context Window**: Total capacity (input + output combined)
**Output Limit**: Max tokens for the response (often smaller than context)

Example: GPT-3.5-turbo has 16K context but only 4K output limit.

## Feature

1. Fetch model limits from models.dev (external maintained database)
2. Guide users with color-coded warnings
3. Truncate page content to fit within limits

## Models.dev Integration

**API Endpoint**: `https://models.dev/api.json`

**Response Structure** (nested by provider):
```json
{
  "openai": {
    "models": {
      "gpt-4o": {
        "id": "gpt-4o",
        "name": "GPT-4o",
        "limit": {
          "context": 128000,
          "output": 16384
        }
      }
    }
  }
}
```

**Cache**: Store in `models.json` next to the event history log file.

**Refresh**: On app launch, if cache older than 7 days. Non-blocking fetch in background.

**Fallback**: If unreachable, keep existing cache. If no cache exists, all models show as "unknown" (orange).

### Model Matching Algorithm

When looking up a user-entered model ID:

1. **Exact match**: Check if model ID exists exactly in database
2. **Prefix match**: User input is prefix of database ID (e.g., "gpt-4o" matches "gpt-4o-2024-05-13")
3. **Suffix match**: Database ID is prefix of user input (e.g., "gpt-4o-mini" in DB matches user's "gpt-4o-mini-2024-07-18")
4. **No match**: Return nil, show orange "unknown" state

```swift
func findModel(_ userModelId: String) -> ModelLimit? {
    let normalized = userModelId.lowercased()

    // 1. Exact match
    if let model = allModels[normalized] {
        return model
    }

    // 2. User input is prefix of DB model (user: "gpt-4o" → DB: "gpt-4o-2024-05-13")
    if let match = allModels.first(where: { $0.key.hasPrefix(normalized) }) {
        return match.value
    }

    // 3. DB model is prefix of user input (DB: "gpt-4o-mini" → user: "gpt-4o-mini-2024-07-18")
    if let match = allModels.first(where: { normalized.hasPrefix($0.key) }) {
        return match.value
    }

    return nil
}
```

## UI: Profile Form

### Token Limits Section

Add a help button (?) next to the "Model Configuration" section header. Clicking it opens a popover explaining token limits:

**Popover content**:
> **Understanding Token Limits**
>
> The **context window** is the total capacity for both input and output combined.
>
> Your input includes: system prompt, page content, chat history, and tool definitions.
> The output is the LLM's response.
>
> If input + output exceeds the context window, the request will fail or content will be truncated.
>
> **Example**: GPT-4o has 128K context and 16K max output. If you use 120K for input, only 8K remains for the response.

### Color-Coded Feedback

When a model is selected, look up limits from cached models.dev data:

- **Green**: Within known limits - "gpt-4o: 128K context, 16K output"
- **Orange**: Model not in database - "Unknown model. Verify limits with your provider."
- **Red**: Exceeds known limit - "Exceeds gpt-4o limit (128K context)"

Sliders default to model limits when a known model is selected. Users can adjust freely; red color indicates when values exceed known limits.

**Truncation info** (shown below sliders):
> "When page content exceeds available space, it will be truncated. Longer pages may lose content at the end."

## Implementation

1. **ModelLimitsService** - Fetch, cache (7 days), lookup model limits
2. **LLMProfile** - Already has `contextLimit` and `maxTokens`
3. **ProfileFormView** - Replace hardcoded limits with models.dev lookup, add help popover
4. **AIService** - Already truncates page content (implemented)
