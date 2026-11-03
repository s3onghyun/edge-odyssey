import Testing
@testable import EdgeMotion

// The update notice (Update.swift): version order, the once-a-day check, what GitHub's answer means.

@Suite struct UpdateNotice {
    func v(_ s: String) -> SemVer { SemVer(s)! }

    @Test func versionsCompareAsNumbers() {
        #expect(v("0.10.0") > v("0.9.9"))           // not as text
        #expect(v("1.0.0") > v("0.99.99"))
        #expect(v("0.2.1") > v("0.2.0"))
        #expect(v("v0.3.0") == v("0.3.0"))          // tags carry a "v"
        #expect(v("0.3.0+build.7") == v("0.3.0"))   // build metadata does not count
        #expect(v("0.3.0").description == "0.3.0" && v("v1.2.3-rc.1").description == "1.2.3-rc.1")
    }

    @Test func prereleasesComeBeforeTheRelease() {
        #expect(v("1.0.0-rc.1") < v("1.0.0"))
        #expect(v("1.0.0-rc.2") < v("1.0.0-rc.10"))      // numeric identifiers as numbers
        #expect(v("1.0.0-alpha") < v("1.0.0-alpha.1"))   // fewer identifiers first
        #expect(v("1.0.0-1") < v("1.0.0-alpha"))         // numbers before words
        #expect(v("1.0.0-alpha") < v("1.0.0-beta"))
        #expect(v("0.9.0") < v("1.0.0-rc.1"))
    }

    /// A development build (`git describe`: commits after a tag) is newer than that tag, older than the next.
    @Test func developmentBuildsSortAfterTheirTag() {
        #expect(v("0.2.0-3-gabc1234") > v("0.2.0"))
        #expect(v("0.2.0-3-gabc1234") < v("0.2.1"))
        #expect(v("v0.2.0-12-g0123abcd-dirty") > v("0.2.0-3-gabc1234"))
        #expect(Update.offer(current: v("0.2.0-3-gabc1234"), latest: v("0.2.0"), skipped: nil) == nil)
        #expect(Update.offer(current: v("0.2.0-3-gabc1234"), latest: v("0.3.0"), skipped: nil) == v("0.3.0"))
        #expect(Update.offer(current: v("0.2.0-ci"), latest: v("0.2.0"), skipped: nil) == v("0.2.0"))   // a prerelease build
        #expect(v("1.0.0-rc-1") < v("1.0.0"))   // a hyphenated prerelease is not a describe tail
    }

    @Test func notVersions() {
        for s in ["", "dev", "1.2", "1.2.3.4", "1..3", "a.b.c", "1.2.x", "1.2.3-", "1.2.3-rc..1", "1.2.-3", "latest", "1.2.3-ünï"] {
            #expect(SemVer(s) == nil, "\(s)")
        }
    }

    @Test func atMostOnceADay() {
        let t = 1_793_600_000.0
        #expect(Update.isDue(now: instant(t), last: nil))                            // never asked
        #expect(!Update.isDue(now: instant(t + 60), last: instant(t)))
        #expect(!Update.isDue(now: instant(t + 86_399), last: instant(t)))
        #expect(Update.isDue(now: instant(t + 86_400), last: instant(t)))
        #expect(Update.isDue(now: instant(t - 3600), last: instant(t)))              // clock moved back: ask again
    }

    @Test func readsTheLatestRelease() {
        #expect(Update.parse(releaseJSON("v0.3.0")) == v("0.3.0"))
        #expect(Update.parse(releaseJSON("v0.3.0", draft: true)) == nil)
        #expect(Update.parse(releaseJSON("v0.4.0-rc.1", pre: true)) == nil)
        #expect(Update.parse(releaseJSON("nightly")) == nil)
        #expect(Update.parse(bytes("{\"message\":\"API rate limit exceeded\"}")) == nil)
        #expect(Update.parse(oversized()) == nil)
        #expect(Update.parse(releaseJSON("v0.3.0-2-gabc1234")) == nil)   // not a release tag
        // the page is built from the version, whatever html_url said
        #expect(Update.page(v("0.3.0")).absoluteString == "https://github.com/s3onghyun/edge-odyssey/releases/tag/v0.3.0")
    }

    /// The page above exists only if the release workflow tags `v<version>` from CHANGELOG's heading.
    @Test func releaseWorkflowTagsTheVersion() throws {
        let yml = try repoFile(".github/workflows/release.yml")
        #expect(yml.contains(#"version="${GITHUB_REF_NAME#v}""#))
        #expect(yml.contains(#"gh release create "v${VERSION}""#))
    }

    @Test func offersOnlyANewerUnskippedVersion() {
        #expect(Update.offer(current: v("0.2.0"), latest: v("0.3.0"), skipped: nil) == v("0.3.0"))
        #expect(Update.offer(current: v("0.2.0"), latest: v("0.3.0"), skipped: "0.3.0") == nil)
        #expect(Update.offer(current: v("0.2.0"), latest: v("0.3.1"), skipped: "0.3.0") == v("0.3.1"))   // a newer one shows again
        #expect(Update.offer(current: v("0.3.0"), latest: v("0.3.0"), skipped: nil) == nil)
        #expect(Update.offer(current: v("0.4.0"), latest: v("0.3.0"), skipped: nil) == nil)             // never offers a downgrade
        #expect(Update.offer(current: nil, latest: v("0.3.0"), skipped: nil) == nil)                     // swift run: no version
    }

    /// Nothing about the user goes out: no system language, no identifiers.
    @Test func sendsOnlyFixedHeaders() {
        #expect(Update.headers(v("0.2.0")) == ["User-Agent": "EdgeOdyssey/0.2.0", "Accept": "application/vnd.github+json", "Accept-Language": "en"])
        #expect(Update.latestAPI.absoluteString == "https://api.github.com/repos/s3onghyun/edge-odyssey/releases/latest")
    }
}
