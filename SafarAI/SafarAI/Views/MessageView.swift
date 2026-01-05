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

                Text(message.content)
                    .padding(10)
                    .background(backgroundColor)
                    .foregroundStyle(textColor)
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
    VStack {
        MessageView(message: Message(role: .user, content: "Hello, how are you?"))
        MessageView(message: Message(role: .assistant, content: "I'm doing well, thanks for asking!"))
    }
    .padding()
}
