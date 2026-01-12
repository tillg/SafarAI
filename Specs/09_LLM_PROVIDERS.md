# LLM Providers

Currently we only use a fixed model from OpenAI. Extend this to support multiple LLM providers via user-configurable profiles.

## LLM Profile Structure

Each profile contains:
- **Provider**: OpenAI (and compatible), Anthropic, Apple on Device, Ollama
- **API Key**: If needed (stored per profile, same location as current key storage)
- **Model**: Dynamically fetched from provider on settings load, user selects from dropdown
- **Max Tokens**: Maximum tokens for response generation (user configurable per profile)
- **Color**: Optional Apple system color for visual safety indication (e.g., red border = public API)
- **Profile selector**: Dropdown in chat header for quick switching (global across Safari instance)

## Visual Changes

**Profile Indicator**
- Colored border around the text entry view (not full window)
- Chat header shows active profile name and colored accent

**AI Response Bubbles**
- Title: "AI (OpenAI/GPT-4)" instead of just "AI"
- Background: Light gray, full width of chat window
- User bubbles remain blue

## Architecture

**Provider Abstraction**
- Common Swift protocol for all LLM providers
- Normalize different API formats (OpenAI, Anthropic, Apple on-device, Ollama)

**API Call Location**
- All LLM calls handled in native Swift layer (better keychain integration + Apple on-device API access)
- API keys stored per profile using existing storage mechanism

**Streaming Implementation**
- Each provider needs custom stream handler (OpenAI and Anthropic use different SSE formats)
- **Location**: Swift layer, per-provider classes conforming to common streaming protocol
- **Flow**: Swift receives provider-specific SSE → normalizes to common message format → sends to extension UI

## UI Components

**Settings Panel**
- SwiftUI List with NavigationLink for profile management
- Add/edit/delete profiles
- Color picker with preview

**Profile Selector**
- Dropdown in chat header for quick switching
- Shows current profile name and model

**Error Handling**
- Missing API key: Inline warning in chat + link to settings
- Invalid key: Toast notification + temporarily disable profile
- Model unavailable: Fallback to provider default + show error message to user

**Visual Feedback**
- Profile switch: Toast notification "Switched to [Profile Name]"
- Model name: Truncate long names, full name in tooltip