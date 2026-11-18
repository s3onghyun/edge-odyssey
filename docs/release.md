# Releasing: Developer ID signing and notarization

`.github/workflows/release.yml` builds a release in **two phases**. Apple usually notarizes in
minutes, but for this team it can take hours. Waiting inside one job would mean every re-run
builds, signs and submits a new app, so a late `Accepted` would have no app left to staple. The
workflow therefore keeps the submitted app and staples that same app once Apple has finished.

| Phase | When | What it does | Publishes |
|---|---|---|---|
| 1 (submit) | push of a `vX.Y.Z` tag, or `-f tag=vX.Y.Z` | checks `## X.Y.Z (unreleased)` in `CHANGELOG.md` → `./test.sh` → `./build.sh` (universal) → Developer ID signature → `notarytool submit` (no waiting) → keeps the signed zip, its `.sha256` and `submission.json` (submission id) as the 90-day artifact `edge-odyssey-signed-X.Y.Z` | nothing |
| 2 (publish) | by hand, `-f run_id=<phase-1 run id>`, once Apple says `Accepted` | downloads that artifact → checks its sha256 → `notarytool info` → staples the same app → `stapler validate`, `spctl` → `Edge-Odyssey-X.Y.Z-arm64.zip` and `.sha256` → build provenance attestation → GitHub Release (notes from `CHANGELOG.md` behind `.github/release-header.md`) | Release |

If Apple is still `In Progress`, phase 2 fails and changes nothing; run the same command again
later. The phase-1 artifact lasts 90 days.

The release archive keeps its long-standing name `Edge-Odyssey-X.Y.Z-arm64.zip` because the
Homebrew cask downloads it; the app inside is universal (arm64 and x86_64).

Without the signing secret (`APPLE_DEVELOPER_ID_P12`), for example in a fork, phase 1 builds the
old ad-hoc signed app, prints **`Notarization skipped`** and keeps it as the 7-day artifact
`edge-odyssey-adhoc-X.Y.Z`. Phase 2 accepts only `edge-odyssey-signed-*` artifacts, so an
unnotarized build is never published.

## Release 0.7.0 (commands)

```sh
R=s3onghyun/edge-odyssey

# Phase 1: an annotated tag on the merge commit of main starts it
git switch main && git pull --ff-only
git tag -a v0.7.0 -m "Edge Odyssey 0.7.0" && git push origin v0.7.0

# Find the phase-1 run. Its summary shows the submission id and the exact phase-2 command
gh run list -R "$R" -w release.yml -L 5
gh run view <run id> -R "$R" --log | grep -E 'Notarization (submitted|skipped)'
#   must print "Notarization submitted: <submission id>", never "Notarization skipped"

# Wait for Apple (see "Check a submission from a Mac"). Once it says Accepted:
gh workflow run release.yml -R "$R" --ref main -f run_id=<phase-1 run id>
gh run list -R "$R" -w release.yml -L 1   # watch phase 2

# After publishing: check the downloaded asset on a Mac
cd "$(mktemp -d)"
gh release download v0.7.0 -R "$R" -p 'Edge-Odyssey-0.7.0-arm64.zip*'
shasum -a 256 -c Edge-Odyssey-0.7.0-arm64.zip.sha256
gh attestation verify Edge-Odyssey-0.7.0-arm64.zip -R "$R"
ditto -x -k Edge-Odyssey-0.7.0-arm64.zip .
xcrun stapler validate "Edge Odyssey.app"
spctl -a -vv -t exec "Edge Odyssey.app"     # source=Notarized Developer ID
```

For a later release, replace `0.7.0`. Always run phase 2 with `--ref main` (the phase-2 jobs live
in the default branch's workflow), and only after phase 1 has finished.

Then bump the cask in [s3onghyun/homebrew-tap](https://github.com/s3onghyun/homebrew-tap)
(`Casks/edge-odyssey.rb`): `version`, and `sha256` from the release's `.sha256` file.

| Phase 2 result | Meaning | Next |
|---|---|---|
| success, summary `Published vX.Y.Z` | the Release exists | bump the cask |
| failure, `Notarization still in progress` | Apple is still working; nothing was published or changed | run the same command later (or re-run that phase-2 run) |
| failure, `Notarization Invalid` plus the notarization log (JSON) | Apple rejected it | fix the log's `issues`, then a new patch version from phase 1 |
| failure, `The signed zip does not match submission.json` | the artifact is not what phase 1 left | do not publish; find out why, then phase 1 again (below) |
| failure, `Tag vX.Y.Z points at …, but phase 1 built …` | the tag moved after phase 1 | move it back, or run phase 1 again for that tag |
| failure, `needs exactly one edge-odyssey-signed-X.Y.Z artifact` | wrong run id, phase 1 failed or skipped notarization, or 90 days passed | check the run id; otherwise phase 1 again |
| failure, `release … already exists` | already published | nothing |

`-f submission_id=<id>` makes phase 2 check another submission instead of the one recorded in the
artifact. Stapling looks the ticket up by the app's code hash, not by the submission id, so this
only succeeds when the same app was accepted under that other submission; otherwise `stapler` or
`spctl` fails and nothing is published.

### Phase 1 again for an existing tag

Re-running a tag-push run on GitHub runs the old workflow stored in that tag. To redo phase 1 for
an existing tag, run the default branch's workflow with `tag`; the source comes from the tag and
`scripts/notarize-app.sh` from this workflow's commit:

```sh
gh workflow run release.yml -R s3onghyun/edge-odyssey --ref main -f tag=v0.6.2
```

This signs and submits again, so use the new run's id for phase 2. Never move a pushed tag.

## What `scripts/notarize-app.sh` does

`submit` (phase 1, needs every signing secret):

1. Creates a keychain for this run only and imports the `.p12` (the runner's login keychain is not
   used). It is deleted on exit, together with the decoded keys.
2. Signs `build/Edge Odyssey.app` with the "Developer ID Application" certificate whose team is
   `APPLE_TEAM_ID`: `codesign --force --options runtime --timestamp`. The hardened runtime and
   secure timestamp are what notarization requires. The app needs no entitlements (notifications,
   the login item and sounds work under the hardened runtime). The identifier stays the bundle id
   `app.edgeodyssey`.
3. Checks the signature, its team and that the executable is universal, zips the app to
   `build/notary/Edge-Odyssey-X.Y.Z-signed.zip` with its `.sha256`, and submits exactly that zip
   with `xcrun notarytool submit` (no `--wait`).
4. Writes `build/notary/submission.json` (submission id, version, zip name, zip sha256, built
   commit, time) and prints `Notarization submitted: <id>`.

`finish [<submission id>]` (phase 2, no `.p12`; only the team ID and notarization credentials):

1. Checks the zip in `build/notary/` against `submission.json` and its `.sha256`.
2. `xcrun notarytool info <id>` (a transient failure is retried up to three times). `In Progress`
   exits 75; `Invalid` prints `notarytool log` for the validated UUID and exits 1.
3. `Accepted`: unzips to `build/Edge Odyssey.app`, checks its team, then `xcrun stapler staple` →
   `stapler validate` → `codesign --verify --deep --strict` → `spctl --assess`, which must say
   `source=Notarized Developer ID`.
4. Zips the stapled app to `build/Edge-Odyssey-X.Y.Z-arm64.zip` with its `.sha256`.

Secrets only reach the steps that need them, as environment variables, and are never printed. The
`.p12` is used in phase 1 only; `contents: write` (creating the Release) exists only in the final
publish job, which holds no Apple secrets. The release workflow never runs on pull requests.

## Repository secrets

Settings → Secrets and variables → Actions → Repository secrets. Only the names belong here.

| Name | Required | Content |
|---|---|---|
| `APPLE_DEVELOPER_ID_P12` | yes (the switch) | base64 of the exported Developer ID Application certificate + private key (`.p12`) |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | yes | the password the `.p12` was exported with |
| `APPLE_TEAM_ID` | yes | team ID (10 uppercase letters or digits) |
| `APPLE_API_KEY_ID` | credentials A (used here) | App Store Connect API key ID |
| `APPLE_API_ISSUER_ID` | credentials A | that key's issuer ID |
| `APPLE_API_KEY_P8` | credentials A | base64 of `AuthKey_<key id>.p8` |
| `APPLE_ID` | credentials B | Apple account email |
| `APPLE_APP_SPECIFIC_PASSWORD` | credentials B | that account's app-specific password |

Set A or B. If any A value is set, A is used. To set one without it landing in the shell history:

```sh
base64 -i DeveloperID.p12 | gh secret set APPLE_DEVELOPER_ID_P12 -R s3onghyun/edge-odyssey
gh secret set APPLE_DEVELOPER_ID_P12_PASSWORD -R s3onghyun/edge-odyssey   # prompts for the value
```

The Developer ID certificate is valid for five years. Thanks to the secure timestamp, published
releases keep opening after it expires. When it is renewed, replace `APPLE_DEVELOPER_ID_P12` and
its password.

## Check a submission from a Mac

The phase-1 summary and log (`Notarization submitted: <id>`) carry the submission id. With the API
key kept outside the repository:

```sh
xcrun notarytool info <id> --key ~/keys/AuthKey_XXXXXXXXXX.p8 --key-id <key id> --issuer <issuer id>
xcrun notarytool log  <id> --key ~/keys/AuthKey_XXXXXXXXXX.p8 --key-id <key id> --issuer <issuer id>
xcrun notarytool history  --key ~/keys/AuthKey_XXXXXXXXXX.p8 --key-id <key id> --issuer <issuer id>
```

`xcrun notarytool store-credentials edge-odyssey --key … --key-id … --issuer …` once, then
`xcrun notarytool info <id> --keychain-profile edge-odyssey`, shortens this. Checking every few
hours is enough. Run phase 2 when the status is `Accepted`.

## Notes on the first notarized release (0.6.2)

- The app has no self-updater: the update notice only opens the release page, so moving from an
  ad-hoc build to a Developer ID build needs nothing special. Homebrew users get it with
  `brew upgrade --cask edge-odyssey`.
- After 0.6.2 is published, remove the "not notarized" caveat from the tap's
  `Casks/edge-odyssey.rb` in the same bump.
