import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case local = "Local Model"

    var displayName: String {
        rawValue
    }
}
