import Foundation
import SwiftHTMLtoMarkdown

class MarkdownConverter {
    func convert(html: String) -> String? {
        do {
            var document = BasicHTML(rawHTML: html)
            try document.parse()
            return try document.asMarkdown()
        } catch {
            logError("Markdown conversion failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func convertToMarkdown(html: String, fallbackText: String) -> String {
        if let markdown = convert(html: html) {
            log("✅ Converted HTML to Markdown (\(html.count) → \(markdown.count) chars)")
            return markdown
        } else {
            log("⚠️ Markdown conversion failed, using plain text fallback")
            return fallbackText
        }
    }
}
