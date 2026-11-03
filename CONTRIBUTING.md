# Contributing

Thanks for looking! This is a small one-person project, so small, focused changes are the
easiest to review.

## Good first contributions

- **Translations.** The Japanese and Simplified Chinese texts (in the app and in
  [`README.ja.md`](README.ja.md) / [`README.zh-CN.md`](README.zh-CN.md)) are AI-assisted. Every
  string in the app is one `L.t(en, ko, ja, zh)` call where it is used in `Sources/` (search for
  the English text); fix the wording and run `./test.sh`, which fails on a missing, empty or
  wrong-script translation. Not sure? Open a
  [translation issue](https://github.com/s3onghyun/edge-odyssey/issues/new?template=translation.yml).
- **Bug reports** with your macOS version, your Mac, and what you expected:
  [bug report](https://github.com/s3onghyun/edge-odyssey/issues/new?template=bug.yml).
- **Docs:** typos, unclear install steps.

## Code

- No Xcode project needed: `./build.sh` builds `build/Edge Odyssey.app`, `./test.sh` runs the
  tests, and both must pass. Set `EDGE_ODYSSEY_BUNDLE_ID` (for example
  `app.edgeodyssey.dev`) to build a copy that keeps its settings apart from your everyday one.
- Keep the app local-only: no analytics, and no new network requests without discussing them in
  an issue first.
- Motion should stay in the render server (Core Animation); the app wakes only at corners and
  state changes.

## Art

The code is MIT. The characters and everything under `assets/` are not (see
[`assets/LICENSE`](assets/LICENSE)), so please don't send new art or modified sprites as a pull
request; open an issue to discuss the idea instead. Episode ideas from the Odyssey are welcome.

## AI-assisted contributions

Welcome, as long as you have read and tested what you submit. This project itself is written with
AI coding assistants (see [`PROVENANCE.md`](PROVENANCE.md)).
