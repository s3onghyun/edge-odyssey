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
- **Focus mode.** When you want the time front and centre: Control-Option-Command-F opens a
  calm full-screen view with a large countdown, a track around it that fills as time passes,
  and Odysseus at three times the size sailing round it, over a dimmed public-domain photo of
  the sea, a coast, the Aegean from orbit or the night sky (or your own). Made for a second or vertical monitor.
- **Pomodoro, timer or stopwatch.** Besides focus-and-break sessions, a plain countdown of any
  length (presets from 1 minute to an hour) and a stopwatch. Scroll over the time to change it:
  a minute per notch, Shift for five, Option for ten seconds.
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
| Start focus / Pause / Resume / Skip / Stop | The timer. The menu bar counts down to the second (`12:50`); scroll over it to change the time (below) |
| Timer | **Pomodoro**, **Countdown timer** or **Stopwatch** (below); the countdown's length (1, 3, 5, 10, 15, 30, 60 min or custom); focus 15/25/45/50/90 min or custom (1-240), break 5/10/15 min or custom (1-60), a long break (15 min) every 2-6 sessions, and what happens when time is up (below). A new length applies from the next session |
| Focus mode | Control-Option-Command-F, from anywhere: the full-screen focus view (below). Again to close |
| Focus mode on | With more than one display: which one focus mode opens on (remembered) |
| Focus mode background | Off, a different photo each session (default), one photo, or **your own folder**; slow drift on or off |
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

### Timer and stopwatch

<p align="center"><img src="assets/screenshots/timer-background.gif" width="300" alt="Focus mode over a dim sunset photo: a countdown timer set by steps to 12:00 and down to 6:40, then run until Time's up with the gold glow"></p>
<p align="center"><sub>A countdown set in steps (as with the scroll wheel), run at 40x speed in focus mode over a sunset photo.</sub></p>

*Timer* picks what the menu-bar and focus-mode clock is:

- **Pomodoro** (default): focus, then a break, a long break every few sessions.
- **Countdown timer**: one countdown of any length, 10 seconds to 24 hours: a preset, *Custom…*
  (`10` for minutes, `1:30`, `1:15:00`) or scrolling. Odysseus sails round once over its length.
  At 0:00 the edge glows gold, the sound and notification come as at the end of a focus, he
  rests a moment on Ithaca, and the timer is ready for the next run. No break follows.
- **Stopwatch**: counts up from 0:00 until you stop it. Odysseus sails one lap of the edge per
  hour and starts the next; the trail stays teal, since nothing is running out.

Switching mode stops what is running. **Changing the time:** scroll over the time in the menu
bar or anywhere in focus mode (mouse wheel or trackpad; up adds, down takes away), or press the
arrow keys in focus mode (Up/Right add, Down/Left take away). One step is a minute, **Shift**
five minutes, **Option** ten seconds. When nothing runs it sets the next session's length
(Pomodoro focus lengths stay whole minutes) and is remembered; while one runs it moves what is
left of that session only.

### Focus mode

<p align="center">
  <img src="assets/screenshots/focus-mode.gif" width="270" alt="Focus mode in a vertical window: a large countdown, Odysseus sailing round the track as it fills, then Ithaca">
  <img src="assets/screenshots/focus-mode.png" width="270" alt="Focus mode full screen on a vertical display in the light appearance">
</p>
<p align="center"><sub>One lap at 40x speed in a vertical window, and full screen on a vertical display.</sub></p>

*Focus mode* (Control-Option-Command-F, or the menu) opens a full-screen view on the display
you last used for it, or the one you are working on. The remaining time sits in the middle in
large digits; the track around it is the progress bar (teal, coral near the end, lavender
draining during a break), and a 3x Odysseus voyages round it at an even pace, so halfway round
is halfway through. Episodes, Ithaca and Calypso's island play at the same size, and Claude
Code signals still show on the track (the gold swell, the Sirens, the storm).

- **Keys:** Space starts, pauses or resumes; S skips to the break (or ends it); Esc exits;
  arrows or scrolling change the time (above).
  Moving the pointer shows Start/Pause, Skip and Exit buttons. Once the window is in front, a
  click on the background also exits.
- **Where:** *Focus mode on* picks the display. It is an ordinary full-screen window, so you
  can switch Spaces, leave full screen and resize it, or close it.
- While focus mode is open it replaces the edge on its display (other displays keep their
  border); the light or dark look follows macOS.
- **Background:** a photo of rough seas, a rocky coast, the Aegean from orbit, a sunset or the night sky behind the
  voyage, softened and dimmed so the time stays readable, with a slow drift. *Focus mode
  background* turns it off, keeps one, or uses **your own folder** of JPEG, PNG or HEIC photos
  (read on your Mac only). The seven photos that ship with the app are public domain (works of
  NASA, NOAA and the National Park Service); where each comes from is in
  [`assets/backgrounds/PROVENANCE.md`](assets/backgrounds/PROVENANCE.md).
- While the screen is shared or recorded (and on Control-Option-Command-H) the countdown, track
  and photo are hidden and only the plain background shows; the window is also left out of
  screenshots and recordings.

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
screen recordings, and the whole edge (and focus mode's content) hides while the macOS screen-capture indicator is on
(Zoom, Meet, QuickTime and so on). Local files: `~/.edge-odyssey/` (hook states, logbook) and
the app's preferences (`app.edgeodyssey`).

## Command line

```sh
APP="/Applications/Edge Odyssey.app/Contents/MacOS/EdgeOdyssey"
"$APP" --speed 75 --autostart     # demo: 25 minutes in 20 seconds
"$APP" --ctl start|pause|resume|stop|skip|logbook|welcome|hide|show|quit
"$APP" --ctl focus-mode:on|off|toggle   # or focus-display:<display name>
"$APP" --ctl mode:pomodoro|timer|stopwatch
"$APP" --ctl timer:10|1:30|1:00:00       # countdown length (switches to the timer)
"$APP" --ctl adjust:60|-300              # like scrolling: seconds to add or take away
"$APP" --ctl background:off|cycle|<file name>   # or background-folder:<path>, drift:on|off
```

Flags (one run only, not saved): `--display main|all|follow|<index>|<name>`, `--style border|traveler`, `--pace even|physical`,
`--thickness 2..4`, `--last5`, `--focus <min>`, `--rest <min>`, `--mode pomodoro|timer|stopwatch`,
`--timer <length>`, `--background off|cycle|<file name>`, `--no-lotus`, `--char <id>`,
`--state-dir <dir>`, `-v` (log to stderr). For demos and tests: `--focus-mode` (open it at launch),
`--focus-frame x,y,w,h` (a window instead of full screen), `--appearance dark|light`.

## Development

```sh
./build.sh      # the app, with swiftc from the Command Line Tools
./test.sh       # motion-math tests (Swift Testing): exact timing, no jumps on re-apply, sprite timing, focus-mode layout, timer modes and time adjustment
```

| Path | License | What |
|---|---|---|
| `Sources/` | MIT | The app (AppKit, SwiftUI windows, Core Animation) |
| `Tests/`, `Package.swift`, `test.sh` | MIT | Motion-math tests |
| `hooks/` | MIT | Claude Code hook and status-line scripts, settings snippet |
| `tools/` | MIT | Art generators (`make_odysseus.py`, `make_icon.py`), sheet builder, `svg2png.swift` |
| `assets/` | All rights reserved, personal-use grant: [`assets/LICENSE`](assets/LICENSE) | Characters, icon, screenshots, sketches, sounds |
| `assets/backgrounds/` | Public domain (US government works): [`PROVENANCE.md`](assets/backgrounds/PROVENANCE.md) | Focus mode photos |

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
