import Foundation
import Observation

/// Model limit information from models.dev
struct ModelLimit: Codable, Equatable {
    let context: Int
    let output: Int
}

/// Lookup result for model limits
enum ModelLimitResult: Equatable {
    case known(context: Int, output: Int, modelId: String)
    case unknown

    var isKnown: Bool {
        if case .known = self { return true }
        return false
    }
}

@Observable
final class ModelLimitsService {
    private(set) var allModels: [String: ModelLimit] = [:]
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?

    private let cacheURL: URL
    private let apiURL = URL(string: "https://models.dev/api.json")!
    private let cacheDuration: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    init() {
        // Set up cache file path in the same directory as events log
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = appSupport.appendingPathComponent("SafarAI", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        cacheURL = appDir.appendingPathComponent("models.json")

        // Load cache on init
        loadCache()

        // Refresh if cache is stale (non-blocking)
        refreshIfNeeded()
    }

    /// Find model limits for a given model ID
    func findModel(_ userModelId: String) -> ModelLimitResult {
        let normalized = userModelId.lowercased()

        // 1. Exact match
        if let model = allModels[normalized] {
            return .known(context: model.context, output: model.output, modelId: normalized)
        }

        // 2. User input is prefix of DB model (user: "gpt-4o" → DB: "gpt-4o-2024-05-13")
        if let match = allModels.first(where: { $0.key.hasPrefix(normalized) }) {
            return .known(context: match.value.context, output: match.value.output, modelId: match.key)
        }

        // 3. DB model is prefix of user input (DB: "gpt-4o-mini" → user: "gpt-4o-mini-2024-07-18")
        if let match = allModels.first(where: { normalized.hasPrefix($0.key) }) {
            return .known(context: match.value.context, output: match.value.output, modelId: match.key)
        }

        return .unknown
    }

    /// Get context limit for a model, or nil if unknown
    func getContextLimit(_ modelId: String) -> Int? {
        switch findModel(modelId) {
        case .known(let context, _, _):
            return context
        case .unknown:
            return nil
        }
    }

    /// Get output limit for a model, or nil if unknown
    func getOutputLimit(_ modelId: String) -> Int? {
        switch findModel(modelId) {
        case .known(_, let output, _):
            return output
        case .unknown:
            return nil
        }
    }

    /// Force refresh from API
    func refresh() {
        Task {
            await fetchFromAPI()
        }
    }

    /// Refresh if cache is older than 7 days (background, non-blocking)
    private func refreshIfNeeded() {
        guard let lastRefresh = lastRefresh else {
            // No cache, fetch from API
            refresh()
            return
        }

        let cacheAge = Date().timeIntervalSince(lastRefresh)
        if cacheAge > cacheDuration {
            log("🔄 Model cache is \(Int(cacheAge / 86400)) days old, refreshing...")
            refresh()
        }
    }

    private func loadCache() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            log("📋 No models cache file found")
            return
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(ModelsCache.self, from: data)
            allModels = cache.models
            lastRefresh = cache.lastRefresh
            log("📋 Loaded \(allModels.count) models from cache (refreshed \(formatAge(cache.lastRefresh)))")
        } catch {
            logError("Failed to load models cache: \(error.localizedDescription)")
        }
    }

    private func saveCache() {
        let cache = ModelsCache(models: allModels, lastRefresh: Date())

        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL)
            lastRefresh = cache.lastRefresh
            log("💾 Saved \(allModels.count) models to cache")
        } catch {
            logError("Failed to save models cache: \(error.localizedDescription)")
        }
    }

    private func fetchFromAPI() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        log("🌐 Fetching model limits from models.dev...")

        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                logError("models.dev returned non-200 status")
                return
            }

            // Parse the nested response structure
            let apiResponse = try JSONDecoder().decode(ModelsDevResponse.self, from: data)

            // Flatten all models from all providers into single dictionary
            var flatModels: [String: ModelLimit] = [:]

            for (_, provider) in apiResponse {
                guard let models = provider.models else { continue }
                for (modelId, modelInfo) in models {
                    if let limit = modelInfo.limit,
                       let context = limit.context,
                       let output = limit.output {
                        flatModels[modelId.lowercased()] = ModelLimit(context: context, output: output)
                    }
                }
            }

            allModels = flatModels
            saveCache()

            log("✅ Fetched \(allModels.count) models from models.dev")

        } catch {
            logError("Failed to fetch from models.dev: \(error.localizedDescription)")
            // Keep existing cache if fetch fails
        }
    }

    private func formatAge(_ date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 60 {
            return "just now"
        } else if age < 3600 {
            return "\(Int(age / 60)) min ago"
        } else if age < 86400 {
            return "\(Int(age / 3600)) hours ago"
        } else {
            return "\(Int(age / 86400)) days ago"
        }
    }
}

// MARK: - Cache Structure

private struct ModelsCache: Codable {
    let models: [String: ModelLimit]
    let lastRefresh: Date
}

// MARK: - API Response Structure

/// Top-level response is a dictionary of providers
private typealias ModelsDevResponse = [String: ProviderInfo]

private struct ProviderInfo: Codable {
    let models: [String: ModelInfo]?
}

private struct ModelInfo: Codable {
    let id: String?
    let name: String?
    let limit: LimitInfo?
}

private struct LimitInfo: Codable {
    let context: Int?
    let output: Int?
}
