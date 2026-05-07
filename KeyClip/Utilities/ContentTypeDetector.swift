import AppKit
import Foundation

enum ContentTypeDetector {
    static func detect(content: String, pasteboard: NSPasteboard? = nil) -> ContentType {
        if hasRichTextType(pasteboard) {
            return .richText
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if isLink(trimmed) {
            return .link
        }

        if matchesFullString(trimmed, pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$") {
            return .email
        }

        if isPhoneNumber(trimmed) {
            return .phone
        }

        if isColor(trimmed) {
            return .color
        }

        if isEmojiOnly(trimmed) {
            return .emoji
        }

        if isCode(content) {
            return .code
        }

        return .text
    }

    private static func hasRichTextType(_ pasteboard: NSPasteboard?) -> Bool {
        guard let types = pasteboard?.types else { return false }
        return types.contains(.rtf) || types.contains(.html)
    }

    private static func isLink(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard string.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }

        let lowercased = string.lowercased()
        let hasAllowedScheme = lowercased.hasPrefix("http://")
            || lowercased.hasPrefix("https://")
            || lowercased.hasPrefix("ftp://")
            || lowercased.hasPrefix("file://")
            || lowercased.hasPrefix("mailto:")

        guard hasAllowedScheme else { return false }
        return URL(string: string) != nil
    }

    private static func isPhoneNumber(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        ) else {
            return false
        }

        let range = NSRange(location: 0, length: string.utf16.count)
        return detector
            .matches(in: string, options: [], range: range)
            .contains { $0.range.location == 0 && $0.range.length == range.length }
    }

    private static func isColor(_ string: String) -> Bool {
        let colorPattern = "^(?:#[0-9A-Fa-f]{3,8}|rgb\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*\\)|rgba\\(\\s*[\\d.]+\\s*,\\s*[\\d.]+\\s*,\\s*[\\d.]+\\s*,\\s*[\\d.]+\\s*\\)|hsl\\(\\s*[\\d.]+\\s*,\\s*[\\d.%]+\\s*,\\s*[\\d.%]+\\s*\\)|hsla\\(\\s*[\\d.]+\\s*,\\s*[\\d.%]+\\s*,\\s*[\\d.%]+\\s*,\\s*[\\d.]+\\s*\\))$"
        return matchesFullString(string, pattern: colorPattern, options: [.caseInsensitive])
    }

    private static func isEmojiOnly(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed.unicodeScalars.count <= 80 else { return false }
        var hasEmojiScalar = false
        for scalar in trimmed.unicodeScalars {
            if scalar.properties.isEmojiPresentation
                || (scalar.properties.isEmoji && scalar.value > 0x238C) {
                hasEmojiScalar = true
                continue
            }
            if scalar.value == 0x200D || scalar.value == 0xFE0F || scalar == " " {
                continue
            }
            return false
        }
        return hasEmojiScalar
    }

    private static func isCode(_ content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return false }
        guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return false
        }

        return lines.contains { lineHasCodeSignal($0) }
    }

    private static func lineHasCodeSignal(_ line: String) -> Bool {
        if line.hasPrefix("  ") || line.hasPrefix("\t") {
            return true
        }

        if matchesBracketPair(in: line) {
            return true
        }

        let operatorTokens = [";", "=>", "->", "==", "!=", "::", "<-"]
        if operatorTokens.contains(where: { line.contains($0) }) {
            return true
        }

        let keywordTokens = ["def", "func", "class", "import", "return", "const", "let"]
        return keywordTokens.contains { containsKeywordToken($0, in: line) }
    }

    private static func matchesBracketPair(in line: String) -> Bool {
        matches(line, pattern: "\\{[^\\n]*\\}|\\([^\\n]*\\)")
    }

    private static func containsKeywordToken(_ keyword: String, in line: String) -> Bool {
        var searchStart = line.startIndex

        while let range = line.range(of: keyword, range: searchStart..<line.endIndex) {
            let startsAtBoundary = range.lowerBound == line.startIndex
                || isTokenBoundary(line[line.index(before: range.lowerBound)])
            let endsAtBoundary = range.upperBound == line.endIndex
                || isTokenBoundary(line[range.upperBound])

            if startsAtBoundary && endsAtBoundary {
                return true
            }

            searchStart = range.upperBound
        }

        return false
    }

    private static func isTokenBoundary(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy {
            !CharacterSet.alphanumerics.contains($0) && $0 != "_"
        }
    }

    private static func matchesFullString(
        _ string: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        guard !string.isEmpty else { return false }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }

        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range)?.range == range
    }

    private static func matches(_ string: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }

        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}
