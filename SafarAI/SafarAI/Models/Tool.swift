import Foundation

// Tool definition for OpenAI function calling
struct Tool: Codable {
    let type: String
    let function: FunctionDefinition

    init(function: FunctionDefinition) {
        self.type = "function"
        self.function = function
    }

    struct FunctionDefinition: Codable {
        let name: String
        let description: String
        let parameters: Parameters

        struct Parameters: Codable {
            let type: String
            let properties: [String: Property]
            let required: [String]

            init(properties: [String: Property], required: [String]) {
                self.type = "object"
                self.properties = properties
                self.required = required
            }

            struct Property: Codable {
                let type: String
                let description: String
                let items: ItemsSchema?
                let `enum`: [String]?

                struct ItemsSchema: Codable {
                    let type: String
                }
            }
        }
    }
}

// Tool call from LLM response
struct ToolCall: Codable {
    let id: String
    let type: String
    let function: FunctionCall

    struct FunctionCall: Codable {
        let name: String
        let arguments: String // JSON string
    }
}

// Tool result to send back to LLM
struct ToolMessage: Codable {
    let role: String = "tool"
    let toolCallId: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case role
        case toolCallId = "tool_call_id"
        case content
    }
}

// Available tools
extension Tool {
    static let allTools: [Tool] = [
        getPageText,
        getTabs,
        getPageStructure,
        getImage,
        searchOnPage,
        getLinks,
        openInNewTab
    ]

    static let getPageText = Tool(function: FunctionDefinition(
        name: "getPageText",
        description: "Extract all text content from the current web page",
        parameters: FunctionDefinition.Parameters(
            properties: [:],
            required: []
        )
    ))

    static let getTabs = Tool(function: FunctionDefinition(
        name: "getTabs",
        description: "Get a list of all open browser tabs in the current window, including their titles, URLs, and which one is currently active",
        parameters: FunctionDefinition.Parameters(
            properties: [:],
            required: []
        )
    ))

    static let getPageStructure = Tool(function: FunctionDefinition(
        name: "getPageStructure",
        description: "Get the DOM structure of the current page including headings, sections, and main content areas",
        parameters: FunctionDefinition.Parameters(
            properties: [:],
            required: []
        )
    ))

    static let getImage = Tool(function: FunctionDefinition(
        name: "getImage",
        description: "Get a specific image from the page by CSS selector",
        parameters: FunctionDefinition.Parameters(
            properties: [
                "selector": FunctionDefinition.Parameters.Property(
                    type: "string",
                    description: "CSS selector for the image element (e.g., 'img.logo', '#hero-image')",
                    items: nil,
                    enum: nil
                )
            ],
            required: ["selector"]
        )
    ))

    static let searchOnPage = Tool(function: FunctionDefinition(
        name: "searchOnPage",
        description: "Search for text on the current page and return matching contexts",
        parameters: FunctionDefinition.Parameters(
            properties: [
                "query": FunctionDefinition.Parameters.Property(
                    type: "string",
                    description: "The text to search for on the page",
                    items: nil,
                    enum: nil
                )
            ],
            required: ["query"]
        )
    ))

    static let getLinks = Tool(function: FunctionDefinition(
        name: "getLinks",
        description: "Extract all links from the current page with their text and URLs",
        parameters: FunctionDefinition.Parameters(
            properties: [:],
            required: []
        )
    ))

    static let openInNewTab = Tool(function: FunctionDefinition(
        name: "openInNewTab",
        description: "Open a URL in a new browser tab",
        parameters: FunctionDefinition.Parameters(
            properties: [
                "url": FunctionDefinition.Parameters.Property(
                    type: "string",
                    description: "The URL to open in a new tab",
                    items: nil,
                    enum: nil
                )
            ],
            required: ["url"]
        )
    ))
}
