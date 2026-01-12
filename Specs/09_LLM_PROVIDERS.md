# LLM Providers

Currently we only use a fixed model from OpenAI. Extend this to support multiple OpenAI-compatible API providers via user-configurable profiles.

**Scope**: OpenAI-compatible APIs only (same API format, tools, streaming). Examples: OpenAI, Groq, Together.ai, OpenRouter, local LLMs via LM Studio/Ollama.

---

## LLM Profile Structure

Each profile contains:
- **Profile Name**: User-friendly name (e.g., "OpenAI GPT-4", "Local Llama", "Groq Fast")
- **Base URL**: API endpoint (e.g., `https://api.openai.com/v1`, `https://api.groq.com/openai/v1`, `http://localhost:1234/v1`)
- **API Key**: Optional (not needed for local endpoints, stored per profile in keychain)
- **Model**: Selected from dropdown, populated by calling `/models` endpoint
- **Max Tokens**: Maximum tokens for response (default: 4096, user configurable)
- **Color**: Optional visual indicator (e.g., red=public API, green=local, blue=custom)

### 💭 Comments

**Base URL is required**: This is the key feature that enables multiple providers. Default to OpenAI's URL for first profile.

**Model fetching**: Call `GET {baseURL}/models` on settings load. Cache results. Provide "Refresh" button. Handle failures gracefully (allow manual model entry as fallback).

**API key optional**: Local endpoints often don't need auth. Make field optional, show "No API key required" hint.

**Profile validation**: Test connection with a lightweight request before saving (maybe just `/models`)? Till: Yes

**Profile persistence**: Store as JSON array in UserDefaults or App Group (for cross-window sync). Structure:
```json
[
  {
    "id": "uuid",
    "name": "OpenAI GPT-4",
    "baseURL": "https://api.openai.com/v1",
    "hasAPIKey": true,
    "model": "gpt-4-turbo",
    "maxTokens": 4096,
    "color": "red"
  }
]
```
API keys stored separately in keychain with profile ID as key.
Till: Stored the same way as the current settings are stored.

---

## Visual Changes

**Profile Indicator in Chat**
- Colored accent bar on left side of text input (3px wide, full height)
- Profile name + model shown in chat header (e.g., "<Profile name> - <Model name>")

**AI Response Bubbles**
- "AI [<Profile name> - <Model name>]"
- Background: Light gray, full width (current design already does this)
- User bubbles: Blue, unchanged

**Profile Selector**
- Dropdown/picker in chat header (next to connection indicator)
- Shows: Profile name + model name (truncated if needed)
- Click to switch profiles

### 💭 Comments

**Accent bar vs border**: Colored left border on input is less distracting than full border. Only visible when typing.

**Profile name in header**: Should be clickable to open profile selector. Show tooltip with full model name on hover.

**Mid-conversation switching**: When switching profiles, keep message history. New messages use new profile. Show system message: "Switched to [Profile Name]".

---

## Architecture

**Simplified Provider Abstraction**
Since all providers are OpenAI-compatible, we just need:
- One HTTP client for OpenAI format
- Configurable base URL
- Same tool format, same streaming format

**Refactor AIService.swift**
```swift
@Observable
final class AIService {
    var activeProfile: LLMProfile
    var profiles: [LLMProfile] = []

    private let httpClient: OpenAIClient

    func chat(messages: [Message], tools: [Tool]?) async -> AsyncStream<String> {
        return httpClient.streamChat(
            baseURL: activeProfile.baseURL,
            apiKey: activeProfile.apiKey,
            model: activeProfile.model,
            messages: messages,
            tools: tools,
            maxTokens: activeProfile.maxTokens
        )
    }

    func fetchModels(for profile: LLMProfile) async throws -> [String] {
        return try await httpClient.listModels(
            baseURL: profile.baseURL,
            apiKey: profile.apiKey
        )
    }
}
```

**No protocol needed**: Since everything is OpenAI-compatible, no abstraction layer. Just make base URL configurable.

**Tool calling**: Works the same across all providers (OpenAI format). No normalization needed.

**Streaming**: All providers use OpenAI SSE format. Same parser works everywhere.

**Error handling**: OpenAI error format. All compatible providers should return similar errors. Map HTTP status codes:
- 401 → Invalid API key
- 429 → Rate limited
- 404 → Model not found
- 5xx → Provider error

### 💭 Comments

**Much simpler**: No protocol, no per-provider implementations, no format translation. Just HTTP client with configurable URL.

**Validation**: Test that provider is truly OpenAI-compatible by calling `/models` during setup. If it fails or returns unexpected format, show error.

**Local endpoint discovery**: Could add "Scan local network" feature to find LM Studio/Ollama instances (they usually run on :1234 or :11434).

---

## UI Components

**Settings Panel: Profile Management**
- New section in SettingsView: "LLM Profiles"
- List of profiles with edit/delete actions
- "Add Profile" button opens form:
  - Profile name (text field)
  - Base URL (text field with common presets dropdown)
  - API key (secure field, optional)
  - Test Connection button
  - Color picker
  - Model dropdown (populated after connection test)
  - Max tokens slider/field

**Profile Selector in Chat Header**
- Menu/picker showing all profiles
- Current profile highlighted
- Click to switch immediately

**First-Run Experience**
- If no profiles configured, show onboarding:
  - "Welcome! Let's set up your first AI provider"
  - Quick setup with OpenAI (just needs API key)
  - Or "Add custom provider" for others

**Error Handling**
- Missing API key: "API key required. [Open Settings]"
- Invalid key: "Authentication failed. Check API key in settings."
- Model unavailable: "Model not found. [Refresh Models]"
- Network error: "Can't reach API at {baseURL}. Check connection."

### 💭 Comments

**Presets for base URL**: Dropdown with common providers:
- OpenAI: `https://api.openai.com/v1`
- Groq: `https://api.groq.com/openai/v1`
- Together: `https://api.together.xyz/v1`
- OpenRouter: `https://openrouter.ai/api/v1`
- Local (LM Studio): `http://localhost:1234/v1`
- Local (Ollama): `http://localhost:11434/v1`
- Custom: (manual entry)

**Test connection**: Essential UX. Shows:
- ✓ Connection successful
- ✓ Found 12 models
- ✗ Connection failed: [error message]

**Model refresh**: Should be automatic when base URL or API key changes. Manual refresh button as backup.

---

## Migration Path

**From current implementation**:
1. Create default profile from existing settings:
   - Name: "OpenAI"
   - Base URL: `https://api.openai.com/v1`
   - API key: Copy from current storage
   - Model: Copy from current selection
   - Color: Red (default)

2. Set as active profile

3. Add "Manage Profiles" button to settings

4. Keep backward compatibility: If no profiles exist, create default from legacy settings

---

## 📋 Summary

**Key Simplifications**:
- ✅ One API format (OpenAI-compatible)
- ✅ No protocol/abstraction layer needed
- ✅ Same tool calling format
- ✅ Same streaming format
- ✅ Much simpler implementation

**Critical Features**:
1. ✅ Configurable base URL (enables any OpenAI-compatible provider)
2. ✅ Optional API key (supports local endpoints)
3. ✅ Model fetching from `/models` endpoint
4. ✅ Profile persistence and switching
5. ✅ Visual indicators (color, accent bar)

**Implementation Order**:
1. Add LLMProfile model
2. Update AIService to use configurable base URL
3. Add profile management UI in settings
4. Add profile selector in chat header
5. Add visual indicators (color, accent)
6. Test with multiple providers (OpenAI, Groq, local)

**Estimated Effort**: 2-3 days (much simpler than multi-protocol approach)
