import Foundation

/// Persists `AppSettings` to UserDefaults as JSON, and maps them onto the
/// runtime config objects. Injectable defaults for testing.
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "appSettings"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return decoded
    }

    public func save(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}

public extension AppSettings {
    var storeConfig: Store.Config {
        .init(maxItems: maxItems, maxAgeDays: maxAgeDays == 0 ? nil : maxAgeDays)
    }

    var filterConfig: FilterConfig {
        FilterConfig(
            ignoredApps: Set(ignoredApps),
            ignoredTypes: Set(ignoredTypes),
            ignoreRegex: ignoreRegex.isEmpty ? nil : ignoreRegex
        )
    }

    var agentRouteConfig: AgentRouteConfig {
        AgentRouteConfig(
            terminalApps: Set(terminalApps),
            maxInlineLines: handoffMaxLines,
            maxInlineChars: handoffMaxChars
        )
    }
}
