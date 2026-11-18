import Foundation

/// Where "Send an email instead" writes to. Empty until an address is published: then the
/// feedback dialog offers only the GitHub issue and says an email option comes later.
/// Setting this one constant turns the email choice on.
enum FeedbackContact {
    static let email = ""
}

/// The facts a feedback report carries, and nothing else: versions, the Mac model and the agent
/// signal's on/off and state. Typed so no path, user name, host name, repo or branch can get in.
struct FeedbackEnvironment {
    var appVersion: String
    var build: String?
    var macOS: OperatingSystemVersion
    var model: String?
    /// nil when there is nothing to report; otherwise whether agent signals are on, and their state.
    var agent: (enabled: Bool, state: AgentState)?
}

/// "Send feedback…": a prefilled GitHub issue or email that the user reads, edits and sends
/// themselves. The app opens a URL and nothing more: it never posts, collects or phones home.
enum Feedback {
    enum Choice: Equatable { case github, email }

    static let newIssue = "https://github.com/s3onghyun/edge-odyssey/issues/new"
    /// The body stays well under GitHub's URL limit even with every byte percent-encoded.
    static let maxBody = 2000

    /// The GitHub issue always; the email only once `FeedbackContact.email` is set.
    static func choices(email: String = FeedbackContact.email) -> [Choice] {
        email.isEmpty ? [.github] : [.github, .email]
    }

    static func title(in l: Lang? = nil) -> String {
        L.t("Feedback: (one line about it)", "의견: (한 줄 요약)", "フィードバック：（一行で要約）", "反馈：（一句话概括）", in: l)
    }

    /// A version-like value only: letters, digits, dots, commas, dashes, underscores, spaces and
    /// brackets, at most 40 characters. A slash, @, colon or anything else is dropped, so a path
    /// or `repo@branch` cannot pass even if one were handed in by mistake.
    static func clean(_ s: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,-_ ()")
        return String(String(s.filter { allowed.contains($0) }).prefix(40)).trimmingCharacters(in: .whitespaces)
    }

    static func environmentLines(_ e: FeedbackEnvironment) -> [String] {
        var app = "- Edge Odyssey: " + clean(e.appVersion)
        if let b = e.build.map(clean), !b.isEmpty, b != clean(e.appVersion) { app += " (build \(b))" }
        let v = e.macOS
        var lines = [app, "- macOS: \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"]
        if let m = e.model.map(clean), !m.isEmpty { lines.append("- Mac: " + m) }
        if let a = e.agent {
            lines.append("- Agent hooks (Claude Code, Codex): signals \(a.enabled ? "on" : "off"), state \(a.state.rawValue)")
        }
        return lines
    }

    /// What happened / what you expected, then the environment block.
    static func body(_ e: FeedbackEnvironment, in l: Lang? = nil) -> String {
        let text = [
            L.t("What happened?", "무슨 일이 있었나요?", "何が起きましたか？", "发生了什么？", in: l),
            "",
            "",
            L.t("What did you expect?", "어떻게 되길 기대했나요?", "どうなると思っていましたか？", "你原本期望怎样？", in: l),
            "",
            "",
            L.t("Environment (filled in by the app; edit or delete freely)", "환경 (앱이 채운 내용이에요. 고치거나 지워도 돼요)",
                "環境（アプリが記入。自由に編集・削除できます）", "环境（由应用填写，可随意修改或删除）", in: l),
        ] + environmentLines(e)
        return String(text.joined(separator: "\n").prefix(maxBody))
    }

    /// RFC 3986 unreserved characters stay; everything else, `+`, `&`, `=` and newlines included, is encoded.
    static func encode(_ s: String) -> String {
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    static func issueURL(_ e: FeedbackEnvironment, in l: Lang? = nil) -> URL {
        URL(string: newIssue + "?title=" + encode(title(in: l)) + "&body=" + encode(body(e, in: l)))!
    }

    /// nil while no address is set. Mail clients expect CRLF line breaks (RFC 6068).
    static func mailURL(_ e: FeedbackEnvironment, email: String = FeedbackContact.email, in l: Lang? = nil) -> URL? {
        guard !email.isEmpty else { return nil }
        let body = body(e, in: l).replacingOccurrences(of: "\n", with: "\r\n")
        return URL(string: "mailto:" + encode(email).replacingOccurrences(of: "%40", with: "@")
                   + "?subject=" + encode(title(in: l)) + "&body=" + encode(body))
    }
}
