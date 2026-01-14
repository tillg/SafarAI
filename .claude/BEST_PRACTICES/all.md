# SafarAI Best Practices Summary

Consolidated guide for Swift/SwiftUI development. Use this to review code quality.

---

## Architecture

### No ViewModels
SwiftUI views are lightweight structs—don't fight this with ViewModels.

**Use instead:**
- **Models:** Data structures + business logic
- **Services:** Network, database, utilities (inject via `@Environment`)
- **Views:** State expressions using `@State`, `@Environment`, `@Observable`, `@Binding`

**Patterns:**
- Define view state with enums inside the view
- Use `.task(id:)` and `.onChange()` for side effects
- Use SwiftData `@Query` directly in views
- Split large views into subviews, not ViewModels

### Navigation
Navigation is state. Use `NavigationStack` with explicit path management.

```swift
enum AppRoute: Hashable {
    case detail(id: String)
    case settings
}

@State private var navigationPath: [AppRoute] = []

NavigationStack(path: $navigationPath) {
    HomeView()
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .detail(let id): DetailView(id: id)
            case .settings: SettingsView()
            }
        }
}
```

**Do:**
- Routes are lean enums (pass IDs, not objects)
- Single `navigationDestination` with switch routing
- Use Environment for navigationPath in nested views

**Don't:**
- Use `NavigationView` (deprecated)
- Pass heavy objects in route cases
- Store view instances in navigation state

---

## Modern SwiftUI APIs (iOS 17+)

### Observation Framework
Replace `ObservableObject` with `@Observable`:

```swift
// ❌ Old
class ViewModel: ObservableObject {
    @Published var count = 0
}

// ✅ Modern
@Observable
class ViewModel {
    var count = 0
}
```

**Migration:** `@StateObject` → `@State`, `@EnvironmentObject` → `@Environment(Type.self)`

### Deprecated Modifiers

| Deprecated | Modern |
|------------|--------|
| `.foregroundColor(.red)` | `.foregroundStyle(.red)` |
| `.cornerRadius(10)` | `.clipShape(.rect(cornerRadius: 10))` |
| `NavigationView` | `NavigationStack` |
| `NavigationLink(destination:)` | `NavigationLink(value:)` + `.navigationDestination` |
| `.onChange(of:) { action }` | `.onChange(of:) { old, new in }` |
| `.tabItem { }` | `Tab("Name", systemImage:) { }` |

### Typography
Use Dynamic Type, not fixed sizes:

```swift
// ❌ Fixed
.font(.system(size: 18))

// ✅ Dynamic
.font(.body)
```

### Accessibility
Use `Button` instead of `onTapGesture` for VoiceOver support:

```swift
// ❌ Poor accessibility
Text("Tap").onTapGesture { action() }

// ✅ Accessible
Button("Tap", action: action)

// ✅ With icon
Button("Save", systemImage: "plus", action: save)
```

### Layout
Minimize `GeometryReader`. Prefer:
- `.containerRelativeFrame(.horizontal)`
- `.visualEffect { content, proxy in }`

### Formatting
```swift
// ❌ C-style
String(format: "%.2f", value)

// ✅ Type-safe
Text(value, format: .number.precision(.fractionLength(2)))

// ❌ Verbose
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

// ✅ Concise
URL.documentsDirectory
```

---

## Async/Concurrency

### Task Basics
`Task {}` inherits actor context (usually MainActor in SwiftUI). Always use `await`:

```swift
// ✅ Correct
Task {
    await viewModel.loadData()
}

// ❌ Missing await
Task {
    viewModel.loadData()  // Race condition!
}
```

### Task.detached
Use sparingly—only for heavy computation off main thread:

```swift
Task.detached {
    let result = heavyWork()
    await MainActor.run {
        viewModel.data = result
    }
}
```

### Modern Concurrency
```swift
// ❌ Old
DispatchQueue.main.async { updateUI() }
try await Task.sleep(nanoseconds: 1_000_000_000)

// ✅ Modern
await MainActor.run { updateUI() }
try await Task.sleep(for: .seconds(1))
```

Note: Views are `@MainActor` by default in new projects—don't add redundant annotations.

---

## SwiftData & CloudKit

### CloudKit Configuration

**Required setup:**
1. Enable iCloud + CloudKit in Xcode capabilities
2. Enable Background Modes → Remote notifications
3. Add network entitlement for macOS: `com.apple.security.network.client`

```swift
let config = ModelConfiguration(
    url: storeURL,
    cloudKitDatabase: .private("iCloud.com.company.App")
)
```

### Data Model Rules
- ✅ All relationships must be **optional**
- ✅ All fields should have defaults
- ❌ No `@Attribute(.unique)` with CloudKit
- ❌ No ordered relationships
- ⚠️ Avoid `@Attribute(.externalStorage)` if possible

### Schema Changes
**Safe (auto-migrated):** New optional properties, new entities, default value changes

**Breaking (requires data deletion):** Adding/removing `.externalStorage`, changing optionality, renaming

### Sync Behavior
- Exports happen on app background/quit (system-controlled)
- Imports happen on launch and remote notification
- Failed events followed by success = normal behavior
- Simulators don't receive CloudKit notifications

---

## Code Organization

### File Structure
One type per file (faster builds):

```swift
// ❌ AllModels.swift with 10+ types
// ✅ User.swift, Order.swift, Product.swift
```

### View Performance
Extract computed properties into subviews for better `@Observable` invalidation:

```swift
// ❌ Computed property
var header: some View { Text("Header") }

// ✅ Separate view
struct HeaderView: View {
    var body: some View { Text("Header") }
}
```

---

## Quick Checklist

- [ ] Using `@Observable` instead of `ObservableObject`?
- [ ] Using `NavigationStack` instead of `NavigationView`?
- [ ] Using `.foregroundStyle()` instead of `.foregroundColor()`?
- [ ] Using `.clipShape()` instead of `.cornerRadius()`?
- [ ] Using `Button` instead of `onTapGesture` for interactive elements?
- [ ] Using Dynamic Type fonts?
- [ ] Using `await` inside all `Task {}` blocks?
- [ ] CloudKit relationships are optional?
- [ ] No `@Attribute(.unique)` with CloudKit sync?
- [ ] One type per file?
