import Foundation
import SwiftUI

struct LLMProfile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var baseURL: String
    var hasAPIKey: Bool
    var model: String
    var maxTokens: Int
    var color: String // Stored as string, converted to Color

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String,
        hasAPIKey: Bool = true,
        model: String,
        maxTokens: Int = 4096,
        color: String = "red"
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.hasAPIKey = hasAPIKey
        self.model = model
        self.maxTokens = maxTokens
        self.color = color
    }

    /// Get the display color for this profile
    var displayColor: Color {
        switch color.lowercased() {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "purple":
            return .purple
        case "pink":
            return .pink
        case "yellow":
            return .yellow
        default:
            return .gray
        }
    }

    /// Available color options for profiles
    static let availableColors: [String] = ["red", "green", "blue", "orange", "purple", "pink", "yellow", "gray"]

    /// Common provider presets
    static let presets: [Preset] = [
        Preset(name: "OpenAI", baseURL: "https://api.openai.com/v1"),
        Preset(name: "Groq", baseURL: "https://api.groq.com/openai/v1"),
        Preset(name: "Together", baseURL: "https://api.together.xyz/v1"),
        Preset(name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1"),
        Preset(name: "Local (LM Studio)", baseURL: "http://localhost:1234/v1"),
        Preset(name: "Local (Ollama)", baseURL: "http://localhost:11434/v1"),
        Preset(name: "Custom", baseURL: "")
    ]

    struct Preset: Identifiable, Hashable, Equatable {
        let id = UUID()
        let name: String
        let baseURL: String

        // Implement Hashable based on name and baseURL (not id, since id is random)
        func hash(into hasher: inout Hasher) {
            hasher.combine(name)
            hasher.combine(baseURL)
        }

        // Implement Equatable based on name and baseURL
        static func == (lhs: Preset, rhs: Preset) -> Bool {
            lhs.name == rhs.name && lhs.baseURL == rhs.baseURL
        }
    }
}

/// Represents a model available from a provider
struct LLMModel: Identifiable, Codable {
    let id: String
    let created: Int?
    let ownedBy: String?

    var displayName: String {
        id
    }
}

/// Response structure from /models endpoint
struct ModelsResponse: Codable {
    let data: [LLMModel]
}
