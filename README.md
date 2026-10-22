# cursor-termux

[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Termux%20ARM64-black.svg)](#prerequisites)
[![Agent](https://img.shields.io/badge/agent-2026.09.10--fd3934a-green.svg)](#what-works)

**Cursor Agent CLI on your phone** — native Termux (Android ARM64), no proot,
no container, no glibc chroot.

This repo was previously named
[termux-cursor](https://github.com/lester-01/termux-cursor); use
`cursor-termux` for new clones.

<p align="center">
  <img src="docs/images/cursor_running_on_android.jpg" alt="Cursor Agent about on Termux Android — logged in, Pro, android arm64" width="420" />
</p>

## What works

Tested on-device (see [`docs/10-device-spec.md`](docs/10-device-spec.md)):

| Feature | Status |
|---------|--------|
| **Interactive agent (TUI)** — chat in the terminal | Works |
| **Login / subscription** — Pro tier, models from Cursor | Works |
| **Resume chats** — continue prior sessions after restart | Works |
| **Worker mode** — phone as a Cursor cloud worker from [cursor.com](https://cursor.com) | Works |
| **`agent` + `cursor-agent`** — official dual launcher names | Works |
| **After upstream update** — re-patch with one script | Works |
| **Clean uninstall** — keep chats + login, or purge chats only | Works |

Under the hood we also ship: Bionic rebuilds of `node-pty` / SQLite addons,
JS stubs for proprietary glibc `.node` modules, glibc detection spoofing,
`os.tmpdir()` persist so resume doesn’t die on Android’s missing `/tmp`, and
an optional HTTP/2 bridge frame tracer for diagnosing slow plugin transfers.

## Quick Start

```bash
# 1. Prerequisites
pkg update && pkg install -y nodejs-lts curl git ripgrep clang make python binutils

# 2. Clone and install
git clone https://github.com/lester-01/cursor-termux.git
cd cursor-termux
bash scripts/install.sh

# 3. New shell, then login once (stored under ~/.config/cursor — survives reinstalls)
hash -r
NO_OPEN_BROWSER=1 agent login

# 4. Chat in any project
cd your-project
agent
```

Turn your phone into a **worker** (claim jobs from the Cursor website):

```bash
agent worker start
```

## Why this exists

Cursor Agent ships native addons built for **glibc**. Termux uses **Bionic**.
Those `.node` binaries crash with `dlopen failed`. This repo is the glue that
makes the official CLI runnable on Android anyway.

Installer highlights:

1. Downloads the official Cursor Agent tarball  
2. Symlinks Termux `node` / `ripgrep` over bundled glibc binaries  
3. Rebuilds open native addons for Bionic  
4. Stubs proprietary addons in JS  
5. Spoofs glibc detection for the loader  
6. Installs durable `agent` / `cursor-agent` launchers + PATH  

## After an Agent update

```bash
bash scripts/apply-patches.sh
```

## Uninstall

```bash
# Keep chats/plugins (~/.cursor) and CLI login (~/.config/cursor)
bash scripts/uninstall.sh

# Also remove ~/.cursor (backup first). Login stays in ~/.config/cursor.
mkdir -p ~/backups
tar -czf ~/backups/cursor-dotcursor-$(date +%Y%m%d).tar.gz -C "$HOME" .cursor
tar -czf ~/backups/cursor-config-$(date +%Y%m%d).tar.gz -C "$HOME" .config/cursor
bash scripts/uninstall.sh --purge-all
```

Manual cutover from another Termux wrapper:
[`scripts/fresh-install-playbook.sh`](scripts/fresh-install-playbook.sh).

## Known issues

- Large marketplace plugins (~tens of MB) can stall on slow links — see
  [`docs/07-plugin-transfer-hang.md`](docs/07-plugin-transfer-hang.md) and
  [`docs/08-bridge-frame-tracing.md`](docs/08-bridge-frame-tracing.md).
- More: [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md).

## Roadmap / TODO

- [ ] **CI** — daily upstream version check; optional build/release pipeline  
- [ ] **Cached Agent tarballs** — only if Cursor’s Terms of Service allow
      redistributing their binaries (undecided until reviewed)  
- [ ] Pin / install a specific Agent version from a verified artifact  

## Prerequisites

- Android **ARM64** (aarch64)  
- [Termux](https://f-droid.org/en/packages/com.termux/) from F-Droid  
- ~1.5 GB free for builds  
- A Cursor subscription  

## License

**MIT** for **this repository** (scripts, Termux preload, docs). Cursor Agent
itself remains proprietary to Anysphere / Cursor.
