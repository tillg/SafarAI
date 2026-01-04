# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SafarAI is a Safari Web Extension for macOS that integrates AI capabilities directly into the browser. The extension provides a chat interface alongside web content, allowing users to:
- Summarize and ask questions about the current page
- Have discussions that combine page content with external resources (MCP servers, web browsing, other LLMs)
- Choose from multiple LLM backends (OpenAI, OpenAI-compatible APIs, local macOS LLMs)

## Architecture

**UI Layout**: The extension displays a chat box on the left side of the browser, positioned next to the page content. This side-by-side layout allows for natural interaction between the AI and the web page content.

**Safari Web Extension Structure**: Safari Web Extensions on macOS consist of:
- **App Extension**: The Safari extension bundle containing the web extension resources
- **Containing App**: A macOS app that hosts the extension (required for distribution)
- **Content Scripts**: JavaScript that runs in the context of web pages to access DOM content
- **Background Scripts**: Service workers that handle extension logic and API calls
- **Popup/UI**: Extension UI components (in this case, the chat interface)

**LLM Integration**: The extension supports pluggable LLM backends:
1. OpenAI API (default, user provides API key)
2. OpenAI-compatible APIs from other providers
3. Local macOS LLM capabilities

## Development Environment

Safari Web Extensions for macOS are developed using:
- **Xcode** for the containing macOS app and extension bundle
- **Swift/SwiftUI** for native macOS UI components
- **JavaScript** for web extension logic (content scripts, background scripts)
- **HTML/CSS** for extension UI pages

## Key Development Commands

This project is in early setup phase. Once the Xcode project is created, typical commands will include:

**Building**:
```bash
xcodebuild -scheme SafarAI -configuration Debug
```

**Running**:
- Open the project in Xcode and run the containing app
- Enable unsigned extensions in Safari: Develop > Allow Unsigned Extensions
- Enable the extension in Safari Preferences > Extensions

**Testing**:
Safari Web Extensions can be tested by:
1. Running the containing app in Xcode
2. Opening Safari and navigating to test pages
3. Using Safari's Web Inspector to debug extension scripts

## Safari Extension Specifics

**Manifest**: Safari Web Extensions use a manifest.json file (similar to Chrome extensions but with Safari-specific considerations).

**Permissions**: Will need permissions for:
- `activeTab` or `tabs` for accessing page content
- `storage` for storing API keys and preferences
- Host permissions for any external APIs

**Content Security Policy**: Safari enforces CSP restrictions on extension resources. Remote code execution is not allowed; all code must be bundled with the extension.

**Native Messaging**: For deeper macOS integration or access to local LLMs, may use native messaging to communicate between the web extension and native Swift code.

## Current Status

The project is in the specification phase. See `Specs/01_SETUP.md` for the initial setup requirements and design goals.
