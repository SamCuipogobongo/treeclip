import Foundation

/// How a commit should be pasted. Two strategies only: paste the content as-is,
/// or hand it off as a file and paste an `@path` reference (design §5).
///
/// Note: "bracketed paste" is intentionally NOT a strategy here — wrapping pasted
/// text so newlines don't execute is the *terminal's* job (it enables bracketed
/// paste mode itself). A normal paste into a modern terminal already gets that.
public enum PastePlan: Equatable, Sendable {
    case raw
    case handoffFile(kind: String, ext: String)
}

public struct AgentRouteConfig: Sendable {
    /// Bundle ids treated as agent terminals (Claude Code / Codex live here).
    public var terminalApps: Set<String>
    /// Text past either bound is handed off as a file instead of pasted inline —
    /// the core win: a 5000-line paste into an agent becomes an instant `@file`.
    public var maxInlineLines: Int
    public var maxInlineChars: Int

    public init(
        terminalApps: Set<String> = AgentRouteConfig.defaultTerminals,
        maxInlineLines: Int = 30,
        maxInlineChars: Int = 4_000
    ) {
        self.terminalApps = terminalApps
        self.maxInlineLines = maxInlineLines
        self.maxInlineChars = maxInlineChars
    }

    public static let defaultTerminals: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "com.microsoft.VSCode",             // integrated terminal (see §9 caveat)
        "com.todesktop.230313mzl4w4u92",    // Cursor
    ]
}

public enum AgentRouter {
    /// Decide the paste strategy. Pure: no I/O, fully unit-tested.
    public static func plan(
        frontApp: String?, kind: String, text: String?, forceRaw: Bool, config: AgentRouteConfig
    ) -> PastePlan {
        if forceRaw { return .raw }
        guard let app = frontApp, config.terminalApps.contains(app) else { return .raw }

        switch kind {
        case "image":
            return .handoffFile(kind: "image", ext: "png")
        case "text":
            let body = text ?? ""
            let lineCount = body.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            if lineCount > config.maxInlineLines || body.count > config.maxInlineChars {
                return .handoffFile(kind: "text", ext: "txt")
            }
            return .raw
        default:
            return .raw
        }
    }
}
