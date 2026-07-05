import Foundation

/// User-configurable preferences, persisted as one JSON blob. Decoding uses
/// `decodeIfPresent` so adding a field in a later version keeps existing saved
/// settings instead of resetting them.
public struct AppSettings: Codable, Sendable, Equatable {
    public var maxItems: Int
    public var maxAgeDays: Int               // 0 = never expire (avoids the
                                             // Optional-in-Codable round-trip trap)
    public var checkInterval: Double
    public var ignoredApps: [String]
    public var ignoredTypes: [String]
    public var ignoreRegex: String
    public var terminalApps: [String]
    public var handoffMaxLines: Int
    public var handoffMaxChars: Int
    public var launchAtLogin: Bool

    public init(
        maxItems: Int = 1000,
        maxAgeDays: Int = 90,
        checkInterval: Double = 0.5,
        ignoredApps: [String] = [],
        ignoredTypes: [String] = AppSettings.defaultIgnoredTypes,
        ignoreRegex: String = "",
        terminalApps: [String] = AppSettings.defaultTerminalApps,
        handoffMaxLines: Int = 30,
        handoffMaxChars: Int = 4_000,
        launchAtLogin: Bool = false
    ) {
        self.maxItems = maxItems
        self.maxAgeDays = maxAgeDays
        self.checkInterval = checkInterval
        self.ignoredApps = ignoredApps
        self.ignoredTypes = ignoredTypes
        self.ignoreRegex = ignoreRegex
        self.terminalApps = terminalApps
        self.handoffMaxLines = handoffMaxLines
        self.handoffMaxChars = handoffMaxChars
        self.launchAtLogin = launchAtLogin
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        maxItems = try c.decodeIfPresent(Int.self, forKey: .maxItems) ?? d.maxItems
        maxAgeDays = try c.decodeIfPresent(Int.self, forKey: .maxAgeDays) ?? d.maxAgeDays
        checkInterval = try c.decodeIfPresent(Double.self, forKey: .checkInterval) ?? d.checkInterval
        ignoredApps = try c.decodeIfPresent([String].self, forKey: .ignoredApps) ?? d.ignoredApps
        ignoredTypes = try c.decodeIfPresent([String].self, forKey: .ignoredTypes) ?? d.ignoredTypes
        ignoreRegex = try c.decodeIfPresent(String.self, forKey: .ignoreRegex) ?? d.ignoreRegex
        terminalApps = try c.decodeIfPresent([String].self, forKey: .terminalApps) ?? d.terminalApps
        handoffMaxLines = try c.decodeIfPresent(Int.self, forKey: .handoffMaxLines) ?? d.handoffMaxLines
        handoffMaxChars = try c.decodeIfPresent(Int.self, forKey: .handoffMaxChars) ?? d.handoffMaxChars
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    }

    public static let defaultTerminalApps = Array(AgentRouteConfig.defaultTerminals).sorted()
    public static let defaultIgnoredTypes = [
        "org.nspasteboard.ConcealedType",
        "com.agilebits.onepassword",
        "com.typeit4me.clipping",
    ]
}
