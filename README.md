# Edgeling (working name)

A thin, click-through screen-edge timer for macOS. Odysseus sails, climbs, hangs and slides
around the edge of your screen as your focus session passes, and the edge glows softly
when Claude Code needs you.

- Pomodoro (25/5, every fourth break is long): the traveler's position is the elapsed share
  of the session; the trail behind him is the progress bar.
- Claude Code signals: working = quiet blue edge, waiting for you = one soft gold swell and
  the Sirens scene, near the 5-hour limit = amber edge and Poseidon's storm.
- Stays out of the way: 2-4 px border, never takes clicks, hides in full-screen apps, while
  the screen is captured or shared, and on a global hotkey (Control-Option-Command-H).
- Episodes from the Odyssey vary each lap and fill a 24-book logbook (menu bar).

## Build and run

Needs only the Xcode Command Line Tools (no Xcode project).

```sh
./build.sh && open build/Edgeling.app        # menu bar: the dashed circle
```

Fast demo (25 minutes in 20 seconds, starts at once):

```sh
./build/Edgeling.app/Contents/MacOS/Edgeling --speed 75 --autostart
```

Useful flags: `--display main|all|follow|<index>`, `--char odysseus-vector|odysseus-pixel`,
`--thickness 2..4`, `--last5`, `--no-lotus`, `--state-dir <dir>`, `-v` (log to stderr).
Control a running copy: `Edgeling --ctl start|pause|resume|stop|skip|display:all|hide|show|quit`.

## Claude Code hooks

1. Copy `hooks/edgeling-hook.sh` and `hooks/edgeling-statusline.sh` to `~/.edgeling/hooks/`.
2. Merge `hooks/claude-settings-snippet.json` into your `~/.claude/settings.json` by hand
   (the app never edits it). If you already have a `statusLine`, set
   `EDGELING_STATUSLINE_NEXT` to your old command so both keep working.

The hooks write one tiny file per session to `~/.edgeling/sessions/` ("working" / "waiting" /
"limit" plus a timestamp); the status line writes `~/.edgeling/usage`. The app watches the
folder (no polling). Nothing leaves your Mac.

| Claude Code event | State |
|---|---|
| UserPromptSubmit, PreToolUse, PostToolUse | working |
| Notification (permission_prompt, idle_prompt, elicitation_dialog, agent_needs_input), Stop | waiting |
| StopFailure (rate_limit), or `rate_limits.five_hour.used_percentage` >= 85 | limit |
| SessionEnd | session removed |

## Layout

| Path | License | What |
|---|---|---|
| `Sources/` | MIT | the app (AppKit + Core Animation, ~1,500 lines) |
| `hooks/` | MIT | Claude Code hook and status-line scripts, settings snippet |
| `tools/` | MIT | art generators (`make_odysseus.py`), sheet builder, `svg2png.swift` |
| `assets/` | All rights reserved, see `assets/LICENSE.md` | characters, sketches, previews |

## Character format

A character is either a `.sprite` text grid (pixel art: palette + frames) or a folder with
`character.txt` and SVG frames (vector). Animations the app looks for: `walk` (bottom edge),
`climb` / `climb-*` (right edge), `cling` / `zip` (top edge), `slide` (left edge), `idle`,
`sirens`, `storm`, `rest`, `ithaca`, `doze`, `ram`, and episode props `ep-*`. Missing ones fall
back to `walk` or `idle`, so a new character can start with a single walk cycle.
