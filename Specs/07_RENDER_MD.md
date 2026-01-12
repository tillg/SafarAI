# Markdown Rendering for Chat Messages

## Feature Description

LLM responses in SafarAI's chat interface should support rich Markdown formatting to properly display:
- Code blocks with syntax highlighting
- Formatted text (bold, italic, links, strikethrough)
- Structured content (headings, lists, blockquotes, tables)

This enhances readability and allows the AI to present information in a well-structured format, particularly for technical content and code examples.

## Architecture

**Modular Design**: Create a dedicated `MarkdownView` component that takes a Markdown string and renders it. This view should be:
- Reusable across different message types
- Independently styled/themed
- Separate from chat message layout logic

**Integration Points**:
1. Chat message renderer should detect Markdown content and use `MarkdownView` instead of plain text rendering
2. Event history link popups should use the same `MarkdownView` component to display content consistently

## Implementation

**Approach**: Use the **MarkdownUI** third-party library for full GitHub-flavored Markdown support with native SwiftUI rendering.

**Decisions**:
- Default theming (system dark/light mode support)
- Links open in Safari
- Naive implementation first, optimize later if needed
- Image rendering: use whatever MarkdownUI provides by default
- Code copy buttons: deferred to later iteration

## Open Questions

1. **Syntax highlighting library**: Which libraries work with MarkdownUI? Must support: Python, Java, JavaScript, TypeScript, Go, Rust, Swift