# Maintainer notes

Why CI and releases work the way they do. The step-by-step release procedure, the secrets and the
phase-2 error table are in [release.md](release.md); this page does not repeat them.

## The principle: a safe system makes contributions easy

Outside pull requests should be easy to accept. That only works when a pull request cannot reach
anything that matters: the signing keys, the release, or users' Macs. So the safety lives in the
workflows, not in trusting each contributor:

- CI (`.github/workflows/ci.yml`) runs on `push` and `pull_request`, never `pull_request_target`,
  with `permissions: contents: read` and `persist-credentials: false`. A fork's run gets no
  secrets and a read-only token, so its code cannot sign, publish or push. It runs `./test.sh`,
  `./build.sh`, and checks that the executable is universal and its signature is valid.
- The repository's default workflow token is read-only, and workflows cannot approve pull
  requests.
- Workflow runs from first-time contributors wait for approval. Read the diff before approving,
  especially changes to `.github/`, `scripts/`, `build.sh`, `test.sh`, `Package.swift` and
  `hooks/` (the hook scripts run on users' Macs).
- Every Action is pinned to a full commit SHA with its version in a comment. Dependabot proposes
  weekly updates for them; check the release notes of a major bump before merging. Prefer no new
  third-party Actions.
- The release workflow never runs on pull requests. It starts only on a `v*` tag push or a manual
  run, which both need write access, so keep write access to the maintainer. There is no tag
  ruleset or branch protection today; do not describe them as present.

## Releases: notarized or nothing

- Every published build is Developer ID signed, notarized by Apple and stapled. Without the
  signing secret (a fork, for example) phase 1 builds an ad-hoc app, prints
  `Notarization skipped` and keeps it only as a 7-day artifact; phase 2 accepts only
  `edge-odyssey-signed-*` artifacts, so an unnotarized build is never published.
- Two phases. Phase 1 (tag push) tests, builds, signs and submits to Apple **without waiting**, and
  keeps the exact submitted zip, its `.sha256` and the submission id as a 90-day artifact. Phase 2
  (by hand, `-f run_id=<phase-1 run id>`, once Apple says `Accepted`) checks that zip against the
  submission, staples that same app, verifies it with `stapler` and `spctl`, attests provenance and
  publishes.
- Apple can take hours. Do not re-run phase 1 to wait: each run builds and submits a new app, and a
  late `Accepted` then belongs to an app that no longer exists. Check the submission from a Mac
  ([release.md](release.md#check-a-submission-from-a-mac)) and run phase 2 when it is accepted.
  Never move a pushed tag; phase 2 refuses a tag that no longer points at the commit phase 1 built.
- Least privilege per job: the workflow default is `contents: read`; only the phase-2 `notarized`
  job gets `id-token`/`attestations` for provenance, and `contents: write` exists only in the
  final `publish` job, which holds no Apple secrets. The `.p12` is used in phase 1 only.
- After publishing, verify the downloaded asset on a Mac (sha256, `gh attestation verify`,
  `spctl` must say `source=Notarized Developer ID`), then bump the cask in
  [s3onghyun/homebrew-tap](https://github.com/s3onghyun/homebrew-tap). The archive keeps the name
  `Edge-Odyssey-X.Y.Z-arm64.zip` because the cask downloads it; the app inside is universal.

## Updates: a notice, not a self-updater

The app downloads and installs nothing. `Sources/Update.swift` makes one GET to GitHub's
latest-release API at most once a day, and the notice opens a release page URL built from the
version number, never a URL taken from the API answer. If a self-updater is ever added, it must
verify before replacing: the release's SHA-256, a valid code signature with the same signing
identifier and the same **team ID** as the running app, notarization, and exactly the offered
version. Keep the signing team stable; a team change makes such an updater refuse the update.

## Commits and identity

Commit under an identity linked to your GitHub account (a noreply address is fine), so authorship
is clear. Never commit secrets, `.p12`/`.p8` files or local settings. Contributors disclose
material AI assistance in the pull request template
([CONTRIBUTING.md](../CONTRIBUTING.md#ai-assisted-contributions)).
