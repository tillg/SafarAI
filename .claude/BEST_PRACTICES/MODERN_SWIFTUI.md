# Modern SwiftUI & Swift Best Practices

Quick reference for modern frameworks used in this project (iOS 17+).

## Swift Observation Framework

The `@Observable` macro (iOS 17+) replaces `ObservableObject` with a more efficient, compile-time approach. Apply `@Observable` to classes to make properties automatically observable. Views update only when properties they actually read change, improving performance. Use `@State` instead of `@StateObject`, `.environment()` instead of `.environmentObject()`, and `@Bindable` when you need bindings to observable properties.

**Key migration:** `ObservableObject` → `@Observable`, `@Published` → remove, `@StateObject` → `@State`, `@EnvironmentObject` → `@Environment(Type.self)`

**Documentation:**

- Search: `mcp__sosumi__searchAppleDocumentation query="Observable macro"`
- [Migrating from ObservableObject to @Observable](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)
- [Observation Framework](https://developer.apple.com/documentation/observation)

## CloudKit Sync Monitoring

Monitor CloudKit sync state using `NSPersistentCloudKitContainer.eventChangedNotification`. Subscribe to notifications and check for `.import` event type with `.succeeded` property to detect when initial CloudKit import completes. Events include `.setup`, `.import`, and `.export` types, each with properties like `succeeded`, `startDate`, `endDate`, and `error`.

**Documentation:**

- Search: `mcp__sosumi__searchAppleDocumentation query="NSPersistentCloudKitContainer notification"`
- Fetch: `mcp__sosumi__fetchAppleDocumentation path="/documentation/coredata/nspersistentcloudkitcontainer/event"`
- [Syncing a Core Data Store with CloudKit](https://developer.apple.com/documentation/coredata/syncing-a-core-data-store-with-cloudkit)

## SwiftData Models

SwiftData `@Model` classes are automatically `@Observable` in iOS 17+. No additional macro needed. Use `@Query` to fetch data reactively in SwiftUI views.

**Documentation:**

- Search: `mcp__sosumi__searchAppleDocumentation query="SwiftData model"`
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

## Using Sosumi MCP

This project uses Sosumi MCP server to access Apple documentation:

```bash
# Search Apple docs
mcp__sosumi__searchAppleDocumentation query="your search term"

# Fetch specific page
mcp__sosumi__fetchAppleDocumentation path="/documentation/path"
```
