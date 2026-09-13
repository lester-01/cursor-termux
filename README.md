# termux-cursor

[![CI](https://img.shields.io/badge/CI-daily--check-blue)](.github/workflows/daily-check.yml)
[![Latest](https://img.shields.io/badge/latest-2026.09.02--c22c1a3-green)]()
[![Cached](https://img.shields.io/badge/cached-3-brightgreen)]()
[![Verified](https://img.shields.io/badge/verified-pending-gold)]()
[![License](https://img.shields.io/badge/license-MIT-purple)](LICENSE)

Run **Cursor Agent CLI** natively on **Termux (Android ARM64)** — no proot, no
container, no glibc shenanigans.

## Quick Start

```bash
# 1. Install prerequisites
pkg update && pkg install -y nodejs-lts curl git ripgrep clang make python binutils

# 2. Clone and install
git clone https://github.com/prinxlexter/termux-cursor.git
cd termux-cursor
bash scripts/install.sh

# 3. Start a new shell, then login
hash -r
NO_OPEN_BROWSER=1 agent login

# 4. Use it
cd your-project
agent
```

## What This Solves

Cursor Agent ships as a Node.js bundle with several **native addons** (`.node`
files) compiled against **glibc**. Termux uses **Bionic** (Android's libc).
These two are incompatible — the glibc binaries crash with `dlopen failed`.

This installer:

1. **Downloads** the official Cursor Agent CLI tarball
2. **Symlinks** Termux's `node` and `ripgrep` over the bundled glibc ones
3. **Rebuilds** native addons (`node-pty`, `better-sqlite3`, `sqlite3`) from
   source for Bionic
4. **Stubs** proprietary addons (`file-service`, `merkle`, `tree-sitter`) with
   JS replacements
5. **Spoofs** glibc detection so the agent loader takes the correct path
6. **Installs** a durable launcher + bashrc integration

## Worker Mode

Cursor's worker mode also works:

```bash
agent worker start
```

This required rebuilding `pty.node` (from `node-pty`) and `better_sqlite3.node`
for Bionic — see [`docs/04-worker-fixes.md`](docs/04-worker-fixes.md).

## After `agent` / `cursor-agent update`

Updates replace the version directory, wiping our patches. Reapply them:

```bash
bash scripts/apply-patches.sh
```

## Fresh install (manual cutover)

Step-by-step (backup → drop bruk/npm wrappers → uninstall → install → checks):
see [`scripts/fresh-install-playbook.sh`](scripts/fresh-install-playbook.sh)
(commented; you run the commands).

## CI & Version Caching

A [daily GitHub Action](.github/workflows/daily-check.yml) checks for upstream
Cursor Agent updates at 06:00 UTC. When a new version is found:

1. Downloads and patches the tarball
2. Smoke-tests the result
3. Uploads the patched version as a release artifact (keeps last **3** versions)

This means even if an update breaks our patcher, users can fall back to a
**last-known-working version** from the Releases page.

See [`docs/09-versioning-and-artifacts.md`](docs/09-versioning-and-artifacts.md)
for the full strategy.

## Uninstall

```bash
# Keep ~/.cursor (chats, auth, plugins)
bash scripts/uninstall.sh

# Also delete ~/.cursor (backup first!)
mkdir -p ~/backups
tar -czf ~/backups/cursor-dotcursor-$(date +%Y%m%d).tar.gz -C "$HOME" .cursor
bash scripts/uninstall.sh --purge-all
```

## Reporting Issues

If something doesn't work on your device, please open a bug report using the
[template](.github/ISSUE_TEMPLATE/bug-report.md). It asks for **device
specifications** (make, model, Android version, kernel) which are essential for
diagnosis.

The reference device this repo was tested on is documented in
[`docs/10-device-spec.md`](docs/10-device-spec.md) — if your device differs,
we need those details to help.

## Known issues

- Large marketplace plugins (~tens of MB) can hang on slow links — see
  [`docs/07-plugin-transfer-hang.md`](docs/07-plugin-transfer-hang.md) and
  optional bridge tracing in [`docs/08-bridge-frame-tracing.md`](docs/08-bridge-frame-tracing.md).
- More: [`docs/06-troubleshooting.md`](docs/06-troubleshooting.md).

## Files

```
termux-cursor/
├── README.md                # This file
├── LICENSE                  # MIT (this repo only)
├── ACKNOWLEDGMENTS.md       # Credits to bruk, afnan, and others
├── scripts/
│   ├── install.sh           # Fresh install from scratch
│   ├── apply-patches.sh     # Reapply after agent update
│   ├── uninstall.sh         # Remove install; --purge-all drops ~/.cursor
│   └── fresh-install-playbook.sh  # Manual cutover guide
├── lib/
│   └── termux-preload.js    # Node.js preload (glibc spoof + stubs + tracer)
├── docs/
│   ├── 01-why-this-exists.md
│   ├── 02-how-preload-works.md
│   ├── 03-rebuilding-native-addons.md
│   ├── 04-worker-fixes.md
│   ├── 05-after-update.md
│   ├── 06-troubleshooting.md
│   ├── 07-plugin-transfer-hang.md
│   ├── 08-bridge-frame-tracing.md
│   ├── 09-versioning-and-artifacts.md   # ← NEW: CI + caching strategy
│   ├── 10-device-spec.md                 # ← NEW: reference device details
│   └── evidence/
├── .github/
│   ├── workflows/
│   │   └── daily-check.yml              # ← NEW: automated version check
│   └── ISSUE_TEMPLATE/
│       └── bug-report.md                # ← NEW: structured bug reports
├── bin/                   # (reserved)
└── artifacts/             # Historical preload snapshots
```

## Prerequisites

- Android **ARM64** (aarch64)
- [Termux](https://f-droid.org/en/packages/com.termux/) from F-Droid
- About 1.5 GB free space (for builds)
- A Cursor subscription (for API access)

## License

**MIT** covers **this repository only** (install scripts, Termux preload stubs,
docs, and evidence notes). It does **not** relicense Cursor Agent itself —
Cursor Agent remains proprietary software of Anysphere / Cursor.
