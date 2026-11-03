<p align="center"><img src="assets/icon/AppIcon-256.png" width="128" alt="Edge Odyssey icon: Odysseus under sail"></p>

# Edge Odyssey

A thin, click-through focus timer that lives on the edge of your Mac's screen. Odysseus rows
along the bottom, climbs the right side, hangs from the top and slides down the left as your
focus session passes, and the edge glows softly when Claude Code needs you.

[한국어 README](README.ko.md)

<p align="center"><img src="assets/screenshots/voyage.gif" width="480" alt="Odysseus rowing, climbing, hanging and sliding around the screen edge"></p>
<p align="center"><sub>One 25-minute lap at 75x speed, the camera following Odysseus.</sub></p>

- **Pomodoro on the edge.** 25 minutes of focus, 5 minutes of break, every fourth break is
  long. Where Odysseus is on the edge is how much of the session has passed (he moves at an
  even pace, so halfway round is halfway through); the trail behind him is the progress bar,
  and he arrives home exactly when time is up.
- **Physical on every edge.** Rowing on the floor, grip-and-pull climbing (cliffs, an olive
  tree, the mast), hanging and swaying from the top or riding a zipline, a gravity slide down
  a waterfall, a squash on landing. These are looks only; *Mode > Speed: Physical* also makes
  him slow on the climb and fast on the slide, so his place no longer reads as time.
- **Episodes from the Odyssey.** The Cyclops, Aeolus' bag of winds, Circe's piglets,
  Charybdis and Athena's owl visit different laps and fill a 24-book logbook.
- **Claude Code signals (optional).** Quiet blue edge while it works, the Sirens and one soft
  gold swell when it is waiting for you, Poseidon's storm near the 5-hour usage limit.
- **Out of your way.** A 2-4 px border, never takes a click, hides in full-screen apps and
  while the screen is shared or recorded, and on Control-Option-Command-H.
- **Smooth and light.** All motion runs in the macOS render server; the app wakes only at
  corners and state changes (about 0.1% CPU).

## Install

Edge Odyssey needs macOS 13 or later on an Apple-silicon Mac. Download the current
`Edge-Odyssey-<version>-arm64.zip` and its matching `.sha256` file from the
[Releases page](https://github.com/s3onghyun/edge-odyssey/releases). (This first public
release is Apple-silicon only; a universal build is not available yet.)

Verify the download before installing:

```sh
cd ~/Downloads
shasum -a 256 -c Edge-Odyssey-<version>-arm64.zip.sha256
ditto -x -k "Edge-Odyssey-<version>-arm64.zip" .
mv "Edge Odyssey.app" /Applications/
```

The app is ad-hoc signed but **not notarized yet**. On the first launch, Control-click
**Edge Odyssey** in Applications, choose **Open**, then choose **Open** again. If macOS still
blocks it, open **System Settings → Privacy & Security** and select **Open Anyway**. Notarization
will be added in a later release.

### Build from source

To build your own copy, install the Xcode Command Line Tools (`xcode-select --install`); no
Xcode project is required.

```sh
git clone <this repo> && cd edge-odyssey
./build.sh                                   # -> build/Edge Odyssey.app
cp -R "build/Edge Odyssey.app" /Applications/
open "/Applications/Edge Odyssey.app"
```

The first launch opens a three-page welcome guide. After that, Edge Odyssey lives in the
menu bar (the dashed circle).

<p align="center"><img src="assets/screenshots/welcome.png" width="720" alt="Welcome guide, pages 1 and 2"></p>

## Menu

| Item | What it does |
|---|---|
| Start focus / Pause / Resume / Skip / Stop | The timer. The menu bar counts down to the second (`12:50`) |
| Timer | Focus 15/25/45/50/90 min or custom (1-240), break 5/10/15 min or custom (1-60), a long break (15 min) every 2-6 sessions, and what happens when time is up (below). A new length applies from the next session |
| Mode | Odysseus voyage (border + traveler) or a thin border only; Speed: Even (default) or Physical |
| Show on | Main display, all displays (Odysseus follows the display you work on), follow me, or one named display |
| Border | 2, 3 or 4 px |
| Only show in the last 5 minutes | Keeps the edge empty until the end of a focus session (Claude Code calls still show) |
| Logbook… | The 24 books of the Odyssey you have collected |
| Settings | Claude Code signals, doze while a game/video/social app is in front, hide while sharing, count down in seconds (turn off for whole minutes, `13m`), **Launch at login** (off until you turn it on), Welcome guide |
| Hide now | Control-Option-Command-H, from anywhere |

Settings are remembered between launches.

### When time is up

- **End of a focus session:** Odysseus arrives home at the bottom-left corner exactly on time and
  lands on Ithaca (or on Calypso's island for a long break). The edge glows gold once, and the
  border turns lavender and starts draining for the break. A macOS notification says
  "Ithaca! Take a 5-minute break" (on by default; the first one asks for permission). With
  *Timer > Sound* on (off by default) a short harp phrase plays as he arrives. The break starts
  on its own.
- **End of a break:** the border goes away, a "Break's over" notification appears, and the
  timer **waits for you** to start the next focus from the menu. Turn on *Timer > Start the next
  focus after a break* if you want it to start by itself. With sound on, a low harp call says
  it's time to set sail again.
- *Timer > Sound*: **Harp** (two short phrases written for this app), **Glass** (the macOS
  system sound) or **Off** (default), and a low or medium volume. Picking one plays it once.
- Notifications follow macOS Focus / Do Not Disturb, so they stay silent while that is on.

<p align="center"><img src="assets/screenshots/logbook.png" width="720" alt="Logbook window with found and uncharted books"></p>

## Claude Code signals

In the welcome guide (or Settings > Welcome guide), **Copy hook snippet** puts two small
scripts in `~/.edge-odyssey/hooks/` and copies a settings snippet to the clipboard. Paste it
into `~/.claude/settings.json` yourself, merged with any `"hooks"` you already have. Edge
Odyssey never edits that file. If you already have a `statusLine`, keep it and set
`EDGE_ODYSSEY_STATUSLINE_NEXT` to your old command so both keep working.

The same files are in [`hooks/`](hooks/) if you prefer to install them by hand.

The hooks write one tiny file per session to `~/.edge-odyssey/sessions/` (`working`,
`waiting` or `limit` plus a timestamp); the status line writes `~/.edge-odyssey/usage`. The app
watches the folder (no polling). Nothing leaves your Mac.

| Claude Code event | Edge |
|---|---|
| UserPromptSubmit, PreToolUse, PostToolUse | working: quiet blue (only when no timer runs) |
| Notification (permission, idle, elicitation, agent needs input), Stop | waiting: the Sirens, one gold swell |
| StopFailure (rate_limit), or 5-hour usage >= 85% | limit: amber, Poseidon's storm |
| SessionEnd | session removed |

## Privacy

No network access, no analytics. The overlay windows are excluded from screenshots and
screen recordings, and the whole edge hides while the macOS screen-capture indicator is on
(Zoom, Meet, QuickTime and so on). Local files: `~/.edge-odyssey/` (hook states, logbook) and
the app's preferences (`app.edgeodyssey`).

## Command line

```sh
APP="/Applications/Edge Odyssey.app/Contents/MacOS/EdgeOdyssey"
"$APP" --speed 75 --autostart     # demo: 25 minutes in 20 seconds
"$APP" --ctl start|pause|resume|stop|skip|logbook|welcome|hide|show|quit
```

Flags (one run only, not saved): `--display main|all|follow|<index>|<name>`, `--style border|traveler`, `--pace even|physical`,
`--thickness 2..4`, `--last5`, `--focus <min>`, `--rest <min>`, `--no-lotus`, `--char <id>`,
`--state-dir <dir>`, `-v` (log to stderr).

## Development

```sh
./build.sh      # the app, with swiftc from the Command Line Tools
./test.sh       # motion-math tests (Swift Testing): exact timing, no jumps on re-apply, sprite timing
```

| Path | License | What |
|---|---|---|
| `Sources/` | MIT | The app (AppKit, SwiftUI windows, Core Animation) |
| `Tests/`, `Package.swift`, `test.sh` | MIT | Motion-math tests |
| `hooks/` | MIT | Claude Code hook and status-line scripts, settings snippet |
| `tools/` | MIT | Art generators (`make_odysseus.py`, `make_icon.py`), sheet builder, `svg2png.swift` |
| `assets/` | All rights reserved, personal-use grant: [`assets/LICENSE`](assets/LICENSE) | Characters, icon, screenshots, sketches, sounds |

The code is MIT ([`LICENSE`](LICENSE)). The art is not: you may use it in your own builds of
this repository, but not redistribute it or make derivative characters. Forks are welcome
with their own art. See [`PROVENANCE.md`](PROVENANCE.md) for how the art was made.

### Character format

A character is either a `.sprite` text grid (pixel art: palette + frames) or a folder with
`character.txt` and SVG frames (vector). Animations the app looks for: `walk` (bottom edge),
`climb` / `climb-*` (right edge), `cling` / `zip` (top edge), `slide` (left edge), `idle`,
`sirens`, `storm`, `rest`, `ithaca`, `doze`, `ram`, and episode props `ep-*`. Missing ones fall
back to `walk` or `idle`, so a new character can start with a single walk cycle.

See [`CHANGELOG.md`](CHANGELOG.md) for what changed.
