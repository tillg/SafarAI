# Async Inside Task in Swift: The Clean, Correct, and Modern Way (Most Devs Get This Wrong)


**Core Principle:** `Task {}` creates asynchronous work but does NOT automatically run in the background - it inherits the current actor context (usually `MainActor` in SwiftUI).

**Key Rules:**
- **Always use `await`** when calling async functions inside `Task {}`
- `Task {}` inherits actor context (often runs on main thread in SwiftUI)
- `Task.detached {}` runs in isolated context, separate from current actor

**When to Use Task:**
- Starting async work from synchronous contexts (button actions, `onAppear`, UIKit callbacks)
- Bridging from non-async code to async code

**Correct Pattern:**
```swift
Task {
    await viewModel.loadData()  // ✅ Correct - uses await
}
```

**Common Mistakes:**
```swift
Task {
    viewModel.loadData()  // ❌ Wrong - missing await causes race conditions
}

Task {
    heavyWork()  // ❌ Wrong - still blocks MainActor if view is @MainActor
}
```

**Task.detached - Use Sparingly:**
- Only use when you need to escape current actor context for heavy computation
- Does NOT inherit actor, runs in isolated context
- Must use `MainActor.run {}` to update UI from detached task

**Task.detached Pattern:**
```swift
Task.detached {
    let result = heavyComputation()  // Runs off main thread
    await MainActor.run {
        viewModel.data = result  // ✅ Safe UI update
    }
}
```

**SwiftUI Pattern:**
```swift
.onAppear {
    Task {
        await viewModel.loadData()
    }
}
```

**Memory Aid:** Task is the bridge from sync → async. Always await inside it.
