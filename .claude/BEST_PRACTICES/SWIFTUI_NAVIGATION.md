# SwiftUI NavigationStack Best Practices

## Core Principle
Navigation is state. Use NavigationStack with explicit path management instead of NavigationView.

## Three-Layer Architecture
1. **Navigation Model** — Enum defining all routes (state layer)
2. **Navigation View** — navigationDestination with switch/router (presentation layer)
3. **Destination Views** — Standalone views (feature layer)

## Implementation Pattern

```swift
enum AppRoute: Hashable {
    case detail(id: String)
    case settings
}

@main
struct App: App {
    @State private var navigationPath: [AppRoute] = []

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .detail(let id): DetailView(id: id)
                        case .settings: SettingsView()
                        }
                    }
            }
        }
    }
}
```

## Checklist

✅ **Use NavigationStack** with explicit `@State private var navigationPath: [AppRoute] = []`
✅ **Routes are lean enums** — Pass IDs, not objects; load data in destination views
✅ **Single navigationDestination** with switch statement routing all AppRoute cases
✅ **Use Environment** to access navigationPath in nested views (avoid prop drilling)
✅ **Support deep linking** by prepopulating navigationPath on app launch
✅ **No NavigationView** — Stick to NavigationStack only

## Don't

❌ Pass heavy objects in route enum cases
❌ Mix NavigationStack and NavigationView
❌ Store view instances in navigation state
❌ Hardcode destination views outside navigationDestination
