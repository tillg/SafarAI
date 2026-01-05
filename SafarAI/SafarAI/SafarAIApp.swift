import SwiftUI

@main
struct SafarAIApp: App {
    @State private var extensionService = ExtensionService()
    @State private var aiService = AIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(extensionService)
                .environment(aiService)
                .frame(minWidth: 400, idealWidth: 450, minHeight: 500, idealHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove "New Window" menu item
            }

            CommandMenu("SafarAI") {
                Button("Refresh Page Content") {
                    extensionService.requestPageContent()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Clear Conversation") {
                    // Will be handled by ContentView in future
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Settings...") {
                    // Will open settings window in future
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(aiService)
                .environment(extensionService)
        }
    }
}
