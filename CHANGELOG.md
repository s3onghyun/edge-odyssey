# Changelog

## 0.8.0 (unreleased)

- The state folder (`~/.edge-odyssey`, or your `--state-dir`) and every file in it are now readable
  by your account only (folders 0700, files 0600). The hooks and the app create them that way, and
  the app tightens a folder or file an older version left readable to others the next time it
  starts or writes. Use **Copy hook snippet** in the welcome guide again to get the updated
  scripts.
- The agent hook reads `session_id` and `cwd` only from the top level of the hook's JSON (with
  `python3`, falling back to the first match), so a same-named field inside a tool's input or output
  no longer counts, and control characters are dropped from the folder, repo and branch it records.
- The app reads only small regular files from the state folder, never through a symlink, so a
  stray large file, pipe or link there can't stall it.
- The copied hook settings for a custom `--state-dir` stay valid JSON whatever characters the path
  holds.
- **Browser-source overlay (OBS)** (*General*, next to Stream mode, in the menu and in Settings; off
  by default). For streams that show a camera scene rather than the screen: the app serves a
  transparent page at `http://127.0.0.1:47213/overlay` for OBS's Browser source (or any browser)
  with the progress line along the frame edge, Odysseus, the phase (in the app's language)
  and the session, as `Focus · 18:32 · 2/4`. It updates live over server-sent events (`/events`,
  once a second and on every change) and reconnects by itself
  after OBS reloads or the app restarts. Settings shows the URL with *Copy* and *Port…*.
  The server listens on 127.0.0.1 only, serves only `/overlay` and `/events`, answers GET only, never
  takes commands, sends nothing cacheable, rejects any Host but `127.0.0.1:<port>`, and names no paths, users or
  hosts; turning it off closes every connection. README: *OBS browser source* has the steps.
- **Agent narration** for streams. With the Claude Code signals on, Stream mode's HUD shows a second
  chip under the session chip, and the browser-source overlay a chip beside the phase, saying what
  the agent is doing: `⛵ Claude rowing…` (working), `🎶 Sirens: Claude needs you` (waiting for you),
  `⛈ Near the usage limit` (near the limit), nothing while idle, in the app's language. It follows
  the edge's own agent signal (including staying quiet during a break), fades in and out, and shows
  even when no timer runs. Only the state is shown, never the repo, branch, folder, session or
  prompt. **Narrate agent state** (*General*, under the Claude Code signals, in the menu and in
  Settings; on by default) turns it off and leaves the edge signals as they are. Also
  `--ctl narrate:on|off`. The overlay's `/events` snapshot gains `agent` (idle, working, waiting
  or limit) and `narration`.

## 0.7.0 (2026-11-18)

- **Send feedback…** in the menu, next to *Quit*. It opens a GitHub issue prefilled with a short
  template and the app version, macOS version and the agent signal's state (on/off and
  working/waiting), in the app's language. Nothing else goes in: no paths, names, repos or branches.
  Nothing is sent by the app; you read, edit and submit the issue yourself. People without GitHub
  can pick *Send an email instead*, which opens the same prefilled draft in their mail app,
  addressed to s3onghyun.hong@gmail.com.
- **Stream mode** (*General › Stream mode*, in the menu and in Settings; off by default). For people
  who record or stream their screen: the edge and focus mode show up in screenshots, recordings and
  screen shares, they no longer hide while the screen is captured, and a small session HUD sits in
  the bottom-right corner: `Focus · 18:32 · 2/4` shows the phase (Focus, Break, Long break, or
  Arrived, Timer, Stopwatch), the time and, in Pomodoro, the session of the long-break cycle,
  ticking every second. The HUD shows for the whole session even with *Only show in the last 5 minutes* on;
  the edge still waits for the last five minutes. While Stream mode is on, *Hide while the screen
  is shared or recorded* is greyed out with the reason; turning Stream mode off brings back exactly
  the old behaviour and your previous choice. Also `--ctl stream-mode:on|off`; `--capture-visible`
  still shows the windows in captures on its own.
- The README's Privacy section now says the app hides from capture by default and shows itself only
  in Stream mode.
## 0.6.2 (2026-11-18)

- **Opens on the first try.** Edge Odyssey is now signed with a Developer ID, notarized by Apple
  and stapled, so first launch no longer needs *System Settings › Privacy & Security › Open
  Anyway*, offline too. `spctl -a -vv -t exec "/Applications/Edge Odyssey.app"` prints
  `source=Notarized Developer ID`.
- Updating from 0.6.1 works as before: the update notice opens this release page to replace the
  app, or run `brew upgrade --cask edge-odyssey`. Nothing else in the app changes.
- Releases are built in two phases (sign and submit, then staple and publish once Apple accepts)
  and an unnotarized build is never published; see [`docs/release.md`](https://github.com/s3onghyun/edge-odyssey/blob/main/docs/release.md).

## 0.6.1

- **0.6.0 was tagged but never released.** 0.6.1 fixes agent hooks so a non-Git folder or detached
  HEAD still writes its state file cleanly.
- **Control your focus from a launcher, hand work to Codex or Claude Code, then see the branch in your history.**
  URL and CLI controls start or stop a voyage from Raycast, Alfred, Shortcuts and scripts; waiting
  agents stay quiet through a break and call you back afterward; empty labels become the active
  agent's `repo@branch`.
- **Control from anywhere.** `edge-odyssey://start?minutes=50&label=fix-auth`, `pause`, `resume`,
  `stop` and other menu actions now work from Raycast, Alfred, Shortcuts, Git hooks and Claude
  Code; `scripts/edge-odyssey` is the tiny shell wrapper for calling them.
- **Daily Pomodoro session goals.** Set an optional goal of 4, 6, 8, or a custom 1–24 completed
  focus sessions in *Timer*. Progress appears as `n/N` in the menu and focus-mode footer, resets
  at local midnight (or with *Reset today's count*), and sends a notification when reached. Once
  reached, it also stops auto-starting another focus while preserving long-break behaviour.
- **A second character: the Developer voyager** (*Settings › On screen › Character*, or the
  menu's *Character*). A present-day coder in a hoodie and headphones types on a laptop in a small
  dinghy, sailing a "terminal sea" of block waves and prompt glyphs. The boat sails every edge
  and turns at the corners instead of climbing, and the Odyssey's encounters stay with Odysseus,
  who remains the default. The choice is saved. Drawn as code in `tools/make_dev_voyager.py`.

## 0.4.0

- **Universal Mac build.** Edge Odyssey now runs on macOS 13+ Macs with either Apple silicon or
  Intel processors. Release archive names stay unchanged so existing Homebrew installs continue
  to update normally.
- **A Settings window** (*Settings…*, ⌘, in the menu): every option of the menu in one window,
  grouped as Timer, When time is up, On screen, Focus mode and General, in all four languages.
  It stays open, so changing several settings no longer means reopening the menu each time;
  each change applies at once and is saved under the same key as the menu's. The menu keeps
  its quick actions and options; its old *Settings* submenu is now *General*.
- Fixed: picking a break length in *Timer › Break* did nothing in 0.3.0 (the arrival's
  *Start break* command had taken the same name).

## 0.3.0 (unreleased)

- **Ready to share.** The README opens with a short pitch, badges, a one-paragraph install and
  language links, and has full [简体中文](README.zh-CN.md) and [日本語](README.ja.md) versions
  (AI-assisted; corrections welcome). A new hero GIF shows the whole screen with a magnifier
  following Odysseus round one lap to Ithaca, recorded from the app's own windows; the demo
  backdrop no longer prints a caption into recordings.
- **First launch on macOS 15 and later:** the install steps now lead with *System Settings ›
  Privacy & Security › Open Anyway* (Control-click › Open is gone since macOS 15) in every
  README. Build-from-source uses the real clone URL.
- `LICENSE` is the plain MIT text, so GitHub detects it; which files it covers, and the separate
  license for the art, are now in the README and `assets/LICENSE`.
- [`CONTRIBUTING.md`](CONTRIBUTING.md), issue forms for bugs and translations, and a 1280x640
  social preview card drawn by `tools/make_social.py` (`docs/social-preview.png`).
- Release notes start with what the app is, how to install it and what it sends over the
  network, before the changes.
- **The arrival explains itself and always ends.** The badge reads `⚓ Arrived +0:42` (was
  "Done"), with a tooltip. Clicking it opens a menu that starts with one line ("Ithaca! 25-min
  focus done — start the break to stop the clock") and three large choices: *☕ Start break*,
  *+5 min more focus*, *Finish*. The first arrival shows a one-time bubble under the badge. If
  nobody answers, the break starts by itself after 3 minutes (new *Timer > If I don't answer at
  Ithaca*: 1, 3, 5, 10 minutes or keep waiting), and the overtime stops at 60 minutes regardless:
  the clock goes idle. The arrival notification says the same. The wait's length and cap live in
  `ArrivalWait` and are tested.
- **Colour pass, palette "Aegean night"** (picked from three options in
  [`assets/screenshots/palette-options.png`](assets/screenshots/palette-options.png)): navy ink, a
  muted sea teal for focus, one warm-brass accent for a session's last fifth and the arrival,
  slate for breaks, slate blue for Claude Code, rust for the usage storm; light and dark variants
  everywhere (edge, dial, focus mode, menu bar, history chart), following the system appearance.
  Values live in `Tones`, and a test holds every text pair to WCAG AA (4.5:1) and every hue to
  3:1 against the page, the dial face and the hub. Before/after:
  [`assets/screenshots/colour-before-after.png`](assets/screenshots/colour-before-after.png).
- Focus mode has a **Time-Timer-style dial**: a 60-minute face read clockwise from twelve, the
  time left as a wedge (teal, coral for the session's last fifth, lavender on a break), gold
  detents at 15, 25, 45 and 50 minutes and a sailboat handle at the wedge's edge, with the
  countdown in its hub. Set it with the wheel or trackpad as before (a minute a notch, Shift five,
  Option ten seconds; a "+1m" note shows by the boat), by dragging round it or clicking the face
  (no wrapping past twelve), or with the preset chips beneath it while idle. Detents hold the
  wheel for two notches, catch a drag within ¾ of a minute and tap a Force Touch trackpad
  (`NSHapticFeedbackManager`). VoiceOver reads it as an adjustable slider; the arrow keys still
  work. The stopwatch keeps the large digits. Dial math (angle ↔ minutes, snapping, detents,
  wheel steps, the wedge) lives in `Dial` and is tested.
- The menu-bar icon is a **progress ring** while a clock runs: teal filling during a focus, coral
  (with semibold digits) in its last five minutes, lavender emptying during a break; the gold
  arrival badge is unchanged.
- **Typography pass.** One `Typography` scale for every screen (focus mode, the dial, the menu
  bar, the logbook, the welcome guide, the history): SF Pro for text, SF Pro Rounded for the
  countdown, titles, numerals and badges, monospaced digits wherever a number changes, and a
  little tracking (tighter on big digits, looser on small print). System fonts only.
  Before/after: [`assets/screenshots/type-specimen.png`](assets/screenshots/type-specimen.png).
- The end of a focus is now unmistakable, and it waits for you. Odysseus reaches Ithaca, a
  laurel-gold wave runs twice round the edge from the harbor and ripples and sparkles spread there
  (Core Animation only, one-shot, nothing left running). Then the session **stays arrived**: the
  border stays gold and the menu bar shows a gold `⚓ Done +m:ss` counting the time since, until
  you pick *Start break* or *5 more minutes* (menu, focus mode Space/S, or the notification's
  buttons). *Timer > Start the break by itself when a focus ends* (off) brings back the old
  behaviour. The finished focus goes into the history at arrival, so waiting doesn't count.
- Arrival has its own colour, laurel gold `#E8C35A` with an anchor, apart from the gold swell of
  Claude Code waiting.
- The harp now plays by default at low volume; the welcome guide has a switch and *Listen*.
  Saved choices (including *Off*) are kept.
- End notifications are time-sensitive, ask for sound as well as alerts, carry *Start break* and
  *+5 min* actions, and are removed once you move on. With the app's own sound off, the
  notification brings the system sound, so the end is never silent unless you silence it in
  System Settings.
- Fixed: a notification banner on screen counted as a window covering the display and hid the
  edge (Notification Center hosts banners in a clear, display-sized window).
- `--ctl rest`, `extend`, `autorest:on|off`.

## 0.2.0 (unreleased)

First public downloadable build, for Apple silicon Macs running macOS 13 or later.

- Languages: *Settings › Language* offers System, English, 한국어, 日本語 and 简体中文, applied at
  once (menu, open windows, focus mode, notifications) without a restart. *System* matches the whole
  preferred-language list, and Traditional Chinese is not shown Simplified. Every string, the 24
  book titles of the logbook, the photo names and the notifications are translated; dates, weekdays
  and durations follow the chosen language. The bundle declares `CFBundleLocalizations`, so the
  app is listed under *Language & Region › Applications*. A test reads every `L.t(en, ko, ja, zh)`
  call in `Sources/` and fails on a missing, empty or wrong-script translation or an English string
  passed straight to the UI; `--lang pseudo` stretches every string to check for truncation.
  Japanese and Chinese are AI-assisted translations.
- Update notice: once a day, one HTTPS GET to GitHub's latest-release API (fixed headers, no
  cookies, no cache, no telemetry). A newer version adds a release-page row and *Skip this version*
  to the top of the menu and posts one notification for that version. *Settings › Check for updates
  once a day* turns it off, *Check now* asks at once. Nothing is downloaded or installed by the app.
  This is the app's only network access.

- Downloadable, ad-hoc-signed release archives with SHA-256 checksums. The app is not yet
  notarized; first launch requires the standard Gatekeeper override.
- Focus mode (opt-in): Control-Option-Command-F or *Focus mode* in the menu opens a calm
  full-screen view on the chosen display (remembered; *Focus mode on* when there are several):
  a large countdown in the middle, a screen-shaped track around it that fills as time passes,
  and Odysseus at 3x voyaging round it at an even pace, with the episodes, Ithaca and Calypso's
  island at the same size and Claude Code signals still on the track. Space starts, pauses or
  resumes, S skips, Esc or a click exits; buttons appear while the pointer moves. Light and dark
  follow macOS. It replaces the edge on its own display, is left out of screenshots and
  recordings, and blanks its content while the screen is shared. CPU at real speed: about 0.7%
  of one core in focus mode vs 0.5% for the edge on the same machine.

- Timer modes (*Timer* menu): **Pomodoro** (as before), a plain **countdown timer** of any
  length (presets 1-60 min, *Custom…* as `10`, `1:30` or `1:15:00`, 10 s to 24 h) that ends with
  the same gold glow, sound and notification and no break, and a **stopwatch** that counts up,
  Odysseus sailing one lap per hour. Both work on the edge and in focus mode; the choice and the
  timer length are remembered. Switching mode stops what is running.
- Change the time by scrolling over the menu-bar time or anywhere in focus mode (mouse wheel or
  trackpad), or with the arrow keys in focus mode: a minute per step, Shift five minutes, Option
  ten seconds. Idle, it sets the next session's length; running, it moves what is left.
- Focus mode backgrounds: seven public-domain photographs (NASA, NOAA, National Park Service):
  rough seas, a rocky coast, sea cliffs, the Aegean from orbit, a sunset and the night sky
  (sources in `assets/backgrounds/PROVENANCE.md`),
  softened and dimmed under the voyage with a slow drift. *Focus mode background*: off, a
  different photo each session (default), one photo, or your own folder; drift on or off.
- Focus history, kept only on this Mac (`~/.edge-odyssey/history.jsonl`, one JSON line per run):
  every focus, timer and stopwatch run with start, end, mode, time on the clock, whether it ran
  to the end and an optional one-line label (*Label this session…*); runs stopped in their
  first minute and breaks are left out. Today's total, sessions and leagues sailed under the
  menu header and at the foot of focus mode; *History…* shows a 7/30-day chart against a daily
  goal (4 h by default), the latest runs, CSV export and Clear History. Runs over midnight are
  split between the days; days follow the Mac's time zone.
- Command line: `--mode`, `--timer`, `--background`; `--ctl mode:…`, `timer:…`, `adjust:<seconds>`,
  `background:…`, `background-folder:…`, `drift:on|off`.

## 0.1.0

The first build meant for daily use.

- Renamed from the working name Edgeling to **Edge Odyssey**: `Edge Odyssey.app`, bundle id
  `dev.edgeodyssey.app`, state folder `~/.edge-odyssey`, hooks `edge-odyssey-*.sh`.
- App icon: Odysseus under sail at dawn, framed by the screen-edge trail (vector source in
  `assets/icon/`, generated by `tools/make_icon.py`).
- Smaller menu: Mode, Show on, Border, Only show in the last 5 minutes, Logbook, Settings, Hide now.
- Settings are remembered between launches; command-line flags still override them for one run.
  Displays are remembered by name.
- First-run welcome guide (three pages) with a one-click **Copy hook snippet**. It installs the
  hook scripts into `~/.edge-odyssey/hooks` and copies the settings snippet; `~/.claude/settings.json`
  is never edited by the app.
- Logbook window: the 24 books of the Odyssey, with the scene art for the ones you have found.
- Launch at login (SMAppService), off until you turn it on.
- The menu bar and the menu header count down to the second (`12:50`, `1:00:00` from an hour
  up) instead of rounded minutes (`13m`). Settings > *Count down in seconds* switches back to
  whole minutes. The text ticks once a second only while a session runs (not when idle or
  paused) and never redraws the edge animation.
- Timer menu: focus 15/25/45/50/90 min or custom, break 5/10/15 min or custom, a long break
  every 2-6 sessions; remembered, applied from the next session.
- End of a focus session: besides arriving at Ithaca / Calypso's island, a one-time gold glow
  along the edge, a notification (on by default) and an optional soft sound (off by default).
  The sound is chosen in *Timer > Sound*: **Harp** (default sound set; an original phrase
  in the Dorian mode, rising D-F-A-D on arrival and a low D-A twice when a break ends),
  **Glass** (macOS system sound) or **Off** (still the default), at low or medium volume.
  A saved on/off setting from earlier builds turns into Harp.
  End of a break: a notification, then it waits for you; *Start the next focus after a break*
  (off by default) starts it by itself.
- Odysseus travels at an even pace by default: his place on the edge is the elapsed share of
  the session on any screen shape (halfway round = halfway through, also on a vertical
  display). Rowing, climbing, hanging and sliding keep their poses, sways, slips and bounce as
  looks only. *Mode > Speed: Physical* brings back the per-edge speeds (slow climb, fast
  slide); saved as `pace`, `--pace physical` for one run. Everyone starts on Even.
- `--ctl` commands only reach copies with the same bundle id, so a test build can't control or
  quit your everyday copy.
- Motion-math tests (`./test.sh`, Swift Testing): exact arrival time, corners as keyframes,
  no jump when a scene is re-applied, sprite frames on display refreshes, deterministic episodes.

### From the prototype

- Smooth motion fix: re-applying a scene (agent state change, wake, display change) no longer
  restarts sway, grip and gust animations, and a display change no longer fades the edge.
  Frame rate follows the fastest moving point instead of a fixed 15 fps.
- Odysseus vector character with per-edge poses, episodes (Cyclops, Aeolus, Circe,
  Charybdis, Athena's owl), Sirens and storm states for Claude Code, Lotus-eaters doze,
  hiding in full screen and while the screen is captured, global hide hotkey.
