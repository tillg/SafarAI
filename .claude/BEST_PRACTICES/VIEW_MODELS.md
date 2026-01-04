# SwiftUI in 2025: Forget MVVM


**Core Principle:** SwiftUI views don't need ViewModels. Views are designed to be lightweight structs that directly express state.

**Why Avoid ViewModels:**
- SwiftUI views are structs, not classes - designed to be disposable and frequently recreated
- ViewModels fight against SwiftUI's fundamental design philosophy
- They add unnecessary complexity, indirection, and objects to keep in sync
- Apple's own frameworks (SwiftData, @Query) are designed to work directly with views

**Recommended Architecture:**
- **Models:** Data structures and business logic
- **Services:** Network clients, databases, utilities (injected via `@Environment`)
- **Views:** Pure state representations using `@State`, `@Environment`, `@Observable`, and `@Binding`

**Practical Patterns:**
- Define view state using enums directly within the view
- Use `@Environment` for dependency injection instead of manual ViewModel injection
- Leverage `.task(id:)` and `.onChange()` modifiers for side effects and state management
- Use SwiftData's `@Query` and `modelContext` directly in views - don't wrap in ViewModels
- Split large views into smaller subviews, each managing its own state
- Test services and business logic thoroughly; keep views simple enough that bugs are obvious

**Testing Strategy:**
- Unit test your services, network clients, and business logic
- Use SwiftUI Previews for visual testing
- Use ViewInspector or UI automation for view testing if needed
- Don't overcomplicate testing of simple view state expressions

**When Views Grow:** Split into smaller composed subviews, not ViewModels. Use `@State` and `@Binding` for data flow between parent and child views.
