import Foundation

/// The Claude Code settings snippet the app copies for the user to paste.
enum HookSnippet {
    static let defaultHooksPath = "$HOME/.edge-odyssey/hooks/"

    /// Points the snippet's hook commands at a custom state folder. The path is quoted for the
    /// shell first, then escaped for the JSON string it lands in, so any path keeps the snippet
    /// valid JSON and the command runs with exactly that path.
    static func rewrite(_ snippet: String, stateDir: String) -> String {
        let dir = "'" + stateDir.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = "EDGE_ODYSSEY_STATE_DIR=\(dir) \(dir)/hooks/"
        return snippet.replacingOccurrences(of: defaultHooksPath, with: jsonEscaped(command))
    }

    /// `s` as it appears between the quotes of a JSON string.
    static func jsonEscaped(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where u.value < 0x20: out += String(format: "\\u%04x", u.value)
            default: out.unicodeScalars.append(u)
            }
        }
        return out
    }
}
