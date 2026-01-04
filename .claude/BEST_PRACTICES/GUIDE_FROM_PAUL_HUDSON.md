# Common Issues in AI-Generated Swift Code

AI-generated Swift code often contains outdated patterns, deprecated APIs, and accessibility issues. This guide helps identify and fix these problems to ensure modern, maintainable SwiftUI code.

## UI Styling & Modifiers

### 1. Use `foregroundStyle()` instead of `foregroundColor()`

Replace deprecated `foregroundColor()` with `foregroundStyle()`:

```swift
// ❌ Deprecated
Text("Hello").foregroundColor(.red)

// ✅ Modern
Text("Hello").foregroundStyle(.red)
```

`foregroundStyle()` supports advanced features like gradients while maintaining the same character count.

### 2. Use `clipShape()` instead of `cornerRadius()`

Replace deprecated `cornerRadius()` with `clipShape(.rect(cornerRadius:))`:

```swift
// ❌ Deprecated
RoundedRectangle(cornerRadius: 10)

// ✅ Modern
.clipShape(.rect(cornerRadius: 10))
```

The modern API offers advanced features like uneven rounded rectangles.

### 3. Avoid deprecated `onChange()` variants

Do not use the 1-parameter `onChange()` variant:

```swift
// ❌ Unsafe and deprecated
.onChange(of: value) { doSomething() }

// ✅ Safe options
.onChange(of: value) { oldValue, newValue in doSomething() }
.onChange(of: value, doSomething)
```

### 4. Replace `tabItem()` with new Tab API

Use the modern Tab API for type-safe tab selection:

```swift
// ❌ Old API
.tabItem { Label("Home", systemImage: "house") }

// ✅ Modern Tab API
Tab("Home", systemImage: "house") { HomeView() }
```

This enables iOS 26 search tab design and type-safe selection.

## Accessibility & Interaction

### 5. Replace `onTapGesture()` with Button

Use actual Button views instead of `onTapGesture()` for better accessibility:

```swift
// ❌ Poor accessibility
Text("Tap me").onTapGesture { doSomething() }

// ✅ Better for VoiceOver and eye tracking
Button("Tap me") { doSomething() }
```

Exception: Only use `onTapGesture()` when you need tap location or tap count.

### 6. Use inline Button API with system images

Create buttons with the modern inline API:

```swift
// ❌ Verbose
Button(action: save) {
    Label("Save", systemImage: "plus")
}

// ✅ Concise and accessible
Button("Save", systemImage: "plus", action: save)
```

Avoid using just an image without a label—it's problematic for VoiceOver users.

## State Management & Architecture

### 7. Use `@Observable` instead of `ObservableObject`

Replace `ObservableObject` with the `@Observable` macro:

```swift
// ❌ Old pattern
class ViewModel: ObservableObject {
    @Published var count = 0
}

// ✅ Modern pattern
@Observable
class ViewModel {
    var count = 0
}
```

Exception: Keep `ObservableObject` if you specifically need the Combine publisher.

### 8. Split computed properties into separate views

Extract computed properties into separate SwiftUI views for better performance:

```swift
// ❌ Computed property (poor @Observable performance)
var header: some View {
    Text("Header")
}

// ✅ Separate view (benefits from @Observable invalidation)
struct HeaderView: View {
    var body: some View {
        Text("Header")
    }
}
```

## SwiftData & CloudKit

### 9. Avoid `@Attribute(.unique)` with CloudKit

Be careful with unique attributes in SwiftData models:

```swift
// ❌ Does not work with CloudKit
@Attribute(.unique) var identifier: String

// ✅ Handle uniqueness in your code
var identifier: String
```

## Typography & Dynamic Type

### 10. Use Dynamic Type fonts instead of fixed sizes

Replace fixed font sizes with Dynamic Type:

```swift
// ❌ Fixed size (poor accessibility)
.font(.system(size: 18))

// ✅ Dynamic Type
.font(.body)

// ✅ iOS 26+ scaled fonts
.font(.body.scaled(by: 1.5))
```

### 11. Use semantic font weights correctly

Be aware that `fontWeight(.bold)` and `bold()` can produce different results:

```swift
// Different results
Text("Hello").fontWeight(.bold)
Text("Hello").bold()
```

Avoid overusing `fontWeight()` modifier—prefer semantic styles.

## Navigation

### 12. Use modern navigation APIs

Replace old navigation patterns with modern alternatives:

```swift
// ❌ Deprecated
NavigationView { /* content */ }

// ✅ Modern
NavigationStack { /* content */ }

// ❌ Old inline destination
NavigationLink(destination: DetailView()) { Text("Go") }

// ✅ Modern destination modifier
NavigationLink("Go", value: item)
    .navigationDestination(for: Item.self) { DetailView($0) }
```

Exception: Only use `NavigationView` if you need to support iOS 15.

## Collection Views

### 13. Remove unnecessary Array initialization in ForEach

Simplify enumerated ForEach:

```swift
// ❌ Unnecessary Array initializer
ForEach(Array(items.enumerated()), id: \.element.id) { /* ... */ }

// ✅ Direct enumeration
ForEach(items.enumerated(), id: \.element.id) { /* ... */ }
```

## Async & Concurrency

### 14. Use modern Task.sleep API

Replace nanosecond-based sleep with duration-based API:

```swift
// ❌ Old API
try await Task.sleep(nanoseconds: 1_000_000_000)

// ✅ Modern API
try await Task.sleep(for: .seconds(1))
```

### 15. Avoid overusing DispatchQueue.main.async

Replace DispatchQueue with modern concurrency:

```swift
// ❌ Old pattern
DispatchQueue.main.async { updateUI() }

// ✅ Modern pattern
await MainActor.run { updateUI() }

// ✅ Or use @MainActor isolation
@MainActor
func updateUI() { /* ... */ }
```

### 16. Main actor isolation is default in new projects

Don't add unnecessary `@MainActor` annotations:

```swift
// ❌ Redundant in new projects
@MainActor
struct ContentView: View { /* ... */ }

// ✅ Already isolated by default
struct ContentView: View { /* ... */ }
```

## File System & Formatting

### 17. Use URL.documentsDirectory

Replace verbose document directory code:

```swift
// ❌ Verbose
FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

// ✅ Concise
URL.documentsDirectory
```

### 18. Use type-safe number formatting

Replace C-style format strings with type-safe formatters:

```swift
// ❌ C-style formatting
Text(String(format: "%.2f", abs(myNumber)))

// ✅ Type-safe formatting
Text(abs(myNumber), format: .number.precision(.fractionLength(2)))
```

## Rendering & Layout

### 19. Use ImageRenderer for SwiftUI views

Replace UIGraphicsImageRenderer with SwiftUI's ImageRenderer:

```swift
// ❌ UIKit approach
let renderer = UIGraphicsImageRenderer(size: size)

// ✅ SwiftUI approach
let renderer = ImageRenderer(content: myView)
```

### 20. Minimize GeometryReader usage

Consider alternatives to GeometryReader:

```swift
// ❌ Overused GeometryReader
GeometryReader { geometry in
    Text("Hello")
        .frame(width: geometry.size.width)
}

// ✅ Modern alternatives
Text("Hello")
    .visualEffect { content, proxy in /* ... */ }
    .containerRelativeFrame(.horizontal)
```

Use `visualEffect()` and `containerRelativeFrame()` instead of fixed frame sizes.

## Code Organization

### 21. Keep types in separate files

Avoid placing multiple types in a single file:

```swift
// ❌ Poor organization (longer build times)
// AllModels.swift containing 10+ types

// ✅ Better organization
// User.swift
// Order.swift
// Product.swift
```

---

*These patterns help ensure modern, maintainable, and accessible SwiftUI code.*