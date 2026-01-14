import SwiftUI

struct ToolsPopoverView: View {
    @Environment(ExtensionService.self) private var extensionService
    @Binding var isPresented: Bool

    @State private var isExecuting = false
    @State private var executingToolName: String?

    // Parameter input fields for tools that require them
    @State private var selectorInput = ""
    @State private var queryInput = ""
    @State private var urlInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Tools")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                Text("\(Tool.allTools.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(.capsule)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Tools list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Tool.allTools, id: \.function.name) { tool in
                        toolRow(for: tool)

                        if tool.function.name != Tool.allTools.last?.function.name {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 320)
        .overlay {
            // Loading overlay
            if isExecuting {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                        .opacity(0.9)

                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)

                        Text("Executing \(executingToolName ?? "tool")...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func toolRow(for tool: Tool) -> some View {
        let hasParams = !tool.function.parameters.required.isEmpty
        let paramName = tool.function.parameters.required.first

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.function.name)
                        .font(.caption)
                        .fontWeight(.medium)

                    Text(tool.function.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    executeTool(tool)
                } label: {
                    Text("Run")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isExecuting || (hasParams && inputValue(for: paramName ?? "").isEmpty))
            }

            // Parameter input field if required
            if hasParams, let paramName = paramName {
                HStack(spacing: 6) {
                    TextField(
                        placeholderText(for: paramName),
                        text: inputBinding(for: paramName)
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        if !inputValue(for: paramName).isEmpty {
                            executeTool(tool)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func placeholderText(for paramName: String) -> String {
        switch paramName {
        case "selector":
            return "CSS selector (e.g., img.logo)"
        case "query":
            return "Search text..."
        case "url":
            return "https://..."
        default:
            return paramName
        }
    }

    private func inputBinding(for paramName: String) -> Binding<String> {
        switch paramName {
        case "selector":
            return $selectorInput
        case "query":
            return $queryInput
        case "url":
            return $urlInput
        default:
            return $queryInput
        }
    }

    private func inputValue(for paramName: String) -> String {
        switch paramName {
        case "selector":
            return selectorInput
        case "query":
            return queryInput
        case "url":
            return urlInput
        default:
            return ""
        }
    }

    private func executeTool(_ tool: Tool) {
        isExecuting = true
        executingToolName = tool.function.name

        Task {
            // Build arguments JSON
            let arguments: String
            if let paramName = tool.function.parameters.required.first {
                let value = inputValue(for: paramName)
                arguments = "{\"\(paramName)\": \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\"}"
            } else {
                arguments = "{}"
            }

            // Create a ToolCall with generated UUID
            let toolCall = ToolCall(
                id: UUID().uuidString,
                type: "function",
                function: ToolCall.FunctionCall(
                    name: tool.function.name,
                    arguments: arguments
                )
            )

            // Execute using ToolExecutor
            let executor = ToolExecutor(extensionService: extensionService)
            _ = await executor.execute(toolCall)

            // Mark the most recent tool result event as expanded
            if let lastEvent = extensionService.events.last,
               lastEvent.type == .toolResult {
                extensionService.markEventForExpansion(lastEvent.id)
            }

            await MainActor.run {
                isExecuting = false
                executingToolName = nil
                isPresented = false

                // Clear input fields
                selectorInput = ""
                queryInput = ""
                urlInput = ""
            }
        }
    }
}

#Preview {
    ToolsPopoverView(isPresented: .constant(true))
        .environment(ExtensionService())
}
