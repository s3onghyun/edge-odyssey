# Security policy

## Supported versions

Only the [latest release](https://github.com/s3onghyun/edge-odyssey/releases/latest) gets
security fixes. Please update before reporting.

## Reporting a vulnerability

Please report privately, not in a public issue:

- through GitHub's private reporting (*Security* tab › *Report a vulnerability*) when the
  repository shows it, or
- by email to s3onghyun.hong@gmail.com.

Include the Edge Odyssey and macOS versions, what an attacker could do, and steps to reproduce.
This is a one-person project, so replies are best effort; you will get an answer, and credit in
the changelog if you want it.

## Scope

In scope: the app, its Claude Code hook scripts (`hooks/`, installed into `~/.edge-odyssey`), the
local state folder and control channel, the OBS overlay served on `127.0.0.1`, and the release
pipeline (`.github/workflows/`, `scripts/`). Released builds are Developer ID signed and notarized
by Apple; see [docs/MAINTAINERS.md](docs/MAINTAINERS.md) for how releases are protected.
