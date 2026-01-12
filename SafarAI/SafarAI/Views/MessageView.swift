import SwiftUI

struct MessageView: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .user ? "You" : "AI")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Both user and AI messages render as Markdown
                MarkdownView(markdown: message.content, textColor: textColor)
                    .padding(10)
                    .background(backgroundColor)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .frame(maxWidth: 300, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer()
            }
        }
    }

    private var backgroundColor: Color {
        message.role == .user ? .blue : Color(nsColor: .controlBackgroundColor)
    }

    private var textColor: Color {
        message.role == .user ? .white : Color(nsColor: .labelColor)
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageView(message: Message(role: .user, content: "How do I use **bold** and `code` in Markdown?"))

        MessageView(message: Message(role: .assistant, content: """
        Here's how to use Markdown formatting:

        ## Text Formatting
        - **Bold**: Use `**text**`
        - *Italic*: Use `*text*`
        - `Code`: Use backticks

        ## Code Blocks
        ```swift
        let greeting = "Hello!"
        print(greeting)
        ```

        [Learn more](https://www.markdownguide.org)
        """))

        MessageView(message: Message(role: .user, content: "Thanks!"))
    }
    .padding()
    .frame(width: 400)
}
