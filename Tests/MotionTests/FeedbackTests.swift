import Foundation
import Testing
@testable import EdgeMotion

// "Send feedback…" (Feedback.swift): what the prefilled issue or email says, how it is encoded,
// and that it carries versions only.

@Suite struct FeedbackReport {
    let env = FeedbackEnvironment(appVersion: "0.6.3", build: "42",
                                  macOS: OperatingSystemVersion(majorVersion: 15, minorVersion: 4, patchVersion: 1),
                                  agent: (enabled: true, state: .waiting))

    /// The query value named `name`, decoded.
    func query(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }

    @Test func bodyHasTheTemplateAndTheEnvironment() {
        let body = Feedback.body(env, in: .en)
        #expect(body.contains("What happened?"))
        #expect(body.contains("What did you expect?"))
        #expect(body.contains("- Edge Odyssey: 0.6.3 (build 42)"))
        #expect(body.contains("- macOS: 15.4.1"))
        #expect(body.contains("- Agent hooks (Claude Code, Codex): signals on, state waiting"))
        #expect(body.utf8.count < Feedback.maxBody)
    }

    @Test func optionalLinesAreLeftOut() {
        var e = env
        e.build = "0.6.3"   // same as the version: not repeated
        e.agent = nil
        let body = Feedback.body(e, in: .en)
        #expect(body.contains("- Edge Odyssey: 0.6.3\n"))
        #expect(!body.contains("build"))
        #expect(!body.contains("Agent"))
    }

    @Test func everyLanguageHasItsOwnTemplate() {
        for l in Lang.allCases {
            let body = Feedback.body(env, in: l)
            #expect(body.contains("- macOS: 15.4.1"), "\(l)")
            if l != .en { #expect(!body.contains("What happened?"), "\(l)") }
            #expect(!Feedback.title(in: l).isEmpty)
        }
    }

    /// Versions and facts only: no path, user name, host name, repo or branch, even if a
    /// caller hands one in where a version belongs.
    @Test func carriesNoPersonalData() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let user = NSUserName(), host = ProcessInfo.processInfo.hostName
        var hostile = env
        hostile.appVersion = "0.6.3 /Users/alice/work/secret-repo"
        hostile.build = "fix-auth@my-repo"
        for l in Lang.allCases {
            let plain = Feedback.body(env, in: l)
            if user.count > 3 { #expect(!plain.contains(user), "\(l)") }
            if host.count > 6 { #expect(!plain.contains(host), "\(l)") }
            for e in [env, hostile] {
                let body = Feedback.body(e, in: l)
                for bad in ["/", "@", "~", "\\", "secret-repo/", "fix-auth@", home] { #expect(!body.contains(bad), "\(l): \(bad) in \(body)") }
                for line in Feedback.environmentLines(e) {
                    #expect(line.allSatisfy { ($0.isASCII && ($0.isLetter || $0.isNumber)) || " .,-_():".contains($0) }, "\(line)")
                }
            }
        }
        #expect(Feedback.clean("/Users/alice") == "Usersalice")
        #expect(Feedback.clean("repo@branch") == "repobranch")
        #expect(Feedback.clean(String(repeating: "9", count: 100)).count == 40)
    }

    @Test func issueURLIsEncoded() throws {
        let url = Feedback.issueURL(env, in: .ko)
        let s = url.absoluteString
        #expect(s.hasPrefix("https://github.com/s3onghyun/edge-odyssey/issues/new?title="))
        #expect(!s.contains(" ") && !s.contains("\n") && !s.contains("+"))
        #expect(s.contains("%0A"))                         // newlines
        #expect(s.contains("%2C") && s.contains("%3A"))      // reserved characters too
        #expect(query(url, "title") == Feedback.title(in: .ko))
        #expect(query(url, "body") == Feedback.body(env, in: .ko))
        #expect(s.utf8.count < 8000)                       // GitHub's URL limit
        #expect(Feedback.encode("a+b&c=d e/ü") == "a%2Bb%26c%3Dd%20e%2F%C3%BC")
    }

    @Test func emailIsHiddenUntilAnAddressIsSet() {
        #expect(Feedback.choices(email: "") == [.github])
        #expect(Feedback.mailURL(env, email: "", in: .en) == nil)
    }

    @Test func publishedAddressOffersEmail() throws {
        #expect(Feedback.choices() == [.github, .email])
        let url = try #require(Feedback.mailURL(env, in: .en))
        #expect(url.absoluteString.hasPrefix("mailto:s3onghyun.hong@gmail.com?subject="))
    }

    @Test func emailOpensAPrefilledDraft() throws {
        #expect(Feedback.choices(email: "help@example.com") == [.github, .email])
        let url = try #require(Feedback.mailURL(env, email: "help@example.com", in: .ja))
        let s = url.absoluteString
        #expect(s.hasPrefix("mailto:help@example.com?subject="))
        #expect(s.contains("%0D%0A"))                      // CRLF line breaks (RFC 6068)
        #expect(!s.contains(" ") && !s.contains("+"))
        #expect(query(url, "subject") == Feedback.title(in: .ja))
        #expect(query(url, "body") == Feedback.body(env, in: .ja).replacingOccurrences(of: "\n", with: "\r\n"))
    }
}
