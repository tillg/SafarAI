import SwiftUI
import MarkdownUI

struct MarkdownView: View {
    let markdown: String
    var textColor: Color = Color(nsColor: .labelColor)

    var body: some View {
        Markdown(markdown)
            .markdownTextStyle(\.text) {
                FontSize(.em(0.7))
                ForegroundColor(textColor)
            }
            .markdownTextStyle(\.code) {
                FontSize(.em(0.65))
                FontFamilyVariant(.monospaced)
                ForegroundColor(textColor)
                BackgroundColor(.clear)
            }
            .markdownTextStyle(\.strong) {
                FontSize(.em(0.7))
                ForegroundColor(textColor)
            }
            .markdownTextStyle(\.emphasis) {
                FontSize(.em(0.7))
                ForegroundColor(textColor)
            }
            .markdownTextStyle(\.link) {
                ForegroundColor(textColor == .white ? Color.cyan : .blue)
            }
            .textSelection(.enabled)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        MarkdownView(markdown: """
        # Heading 1

        This is **bold** and this is *italic*.

        ## Code Example

        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```

        ## List

        - Item 1
        - Item 2
        - Item 3

        [Link to Apple](https://apple.com)
        """)
    }
    .padding()
    .frame(width: 400)
}
