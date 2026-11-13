import Foundation

/// A URL-scheme request expressed as the existing menu-control commands it should invoke.
/// Keeping this separate from AppKit makes the public interface easy to test.
enum URLScheme {
    enum Result: Equatable {
        case controls([String])
        case ignored(String)
    }

    static func route(_ rawURL: String) -> Result {
        guard let url = URL(string: rawURL) else { return .ignored("malformed URL") }
        guard url.scheme?.lowercased() == "edge-odyssey" else { return .ignored("wrong scheme") }
        let command = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        guard !command.isEmpty else { return .ignored("missing command") }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(items.map { ($0.name.lowercased(), $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        switch command {
        case "start":
            guard Set(values.keys).isSubset(of: ["minutes", "label"]) else { return .ignored("unknown start parameter") }
            var controls: [String] = []
            if let raw = values["minutes"] {
                guard let value = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else {
                    return .ignored("invalid minutes")
                }
                let minutes = min(max(value.rounded(), Durations.focusRange.lowerBound), Durations.focusRange.upperBound)
                controls.append("focus:\(Int(minutes))")
            }
            if let label = values["label"], !label.isEmpty { controls.append("label:\(label)") }
            return .controls(controls + ["start"])
        case "pause", "resume", "stop", "rest", "extend", "skip", "hide", "show", "settings", "logbook", "history":
            return .controls([command])
        case "finish": return .controls(["stop"])
        case "focus", "focus-mode": return .controls(["focus-mode"])
        default: return .ignored("unknown command \(command)")
        }
    }
}
