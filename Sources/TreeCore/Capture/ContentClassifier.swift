import Foundation

/// Refines a captured item into a display/filter category. For non-text kinds
/// the category is just the kind; for text it detects link / code / color /
/// plain. Pure + Foundation-only (NSDataDetector for links), so it's unit-tested
/// and drives palette type icons and the type filter (roadmap Wave 2).
public enum ContentCategory: String, Sendable, CaseIterable {
    case plain, link, code, color, image, file
}

public enum ContentClassifier {
    public static func classify(kind: String, text: String?) -> ContentCategory {
        switch kind {
        case "image": return .image
        case "file": return .file
        default: break
        }
        guard let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .plain
        }
        if isHexColor(raw) { return .color }
        if isSingleLink(raw) { return .link }
        if looksLikeCode(raw) { return .code }
        return .plain
    }

    // #RGB / #RRGGBB / #RRGGBBAA (with or without leading #).
    static func isHexColor(_ s: String) -> Bool {
        let body = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard [3, 4, 6, 8].contains(body.count) else { return false }
        return body.allSatisfy(\.isHexDigit)
    }

    // The whole string is essentially one URL.
    static func isSingleLink(_ s: String) -> Bool {
        guard !s.contains(where: \.isWhitespace),
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return false }
        let range = NSRange(s.startIndex..., in: s)
        guard let match = detector.firstMatch(in: s, range: range) else { return false }
        return match.range == range     // the match spans the entire string
    }

    // Deliberately conservative heuristic — false "code" hurts more than a miss.
    static func looksLikeCode(_ s: String) -> Bool {
        let signals = ["{", "}", ";", "=>", "->", "def ", "function ", "class ",
                       "import ", "const ", "let ", "var ", "#include", "public ", "return "]
        let hits = signals.reduce(0) { $0 + (s.contains($1) ? 1 : 0) }
        let multiline = s.contains("\n")
        return hits >= 2 || (multiline && hits >= 1)
    }
}
