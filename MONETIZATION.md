# Monetization sketch (open core)

| Layer | What | Price idea | Why people pay |
|---|---|---|---|
| Free, open source | MIT app code on GitHub; builds from source with one command; ships with one default character (Odysseus) | Free | Trust, word of mouth, contributors; shows taste |
| Convenience build | Signed and notarized `.app` (direct download), later Mac App Store | $2.99 one-time | No Xcode, no Gatekeeper warnings, auto-update; like Maccy, Rectangle, Ice |
| Character packs | New travelers with their own episodes and logbook: e.g. Sisyphus, Yugong (우공이산), Jingwei (정위전해), Journey to the West | $0.99-1.99 each, or $4.99 bundle | Collectible logbook (24 books per voyage), seasonal packs |
| Pro features (optional) | Multiple agents per edge, per-project colours, custom focus lengths and rituals, stats history, team status via local network | $4.99 one-time or part of a bundle | Power users with several Claude Code sessions |

Notes
- Keep the free build fully useful (timer, agent signals, hiding). Charge for convenience
  and delight, not for removing nags.
- Art stays outside the MIT license (`assets/LICENSE.md`) so packs can be sold while the code
  stays open. Premium packs live outside the public repo.
- Mac App Store needs sandboxing: the hook files would have to move into an App Group or a
  user-granted folder, and window names for capture detection may be limited. Selling
  direct (Paddle, Lemon Squeezy, Gumroad) first avoids that work.
- Apple Developer Program ($99/year) is needed for notarized direct downloads and the App Store.
