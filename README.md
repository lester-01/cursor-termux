# termux-cursor

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
# (legacy name also works: cursor-agent)

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

See `docs/` for deep dives into each issue.

## Worker Mode

Cursor's worker mode also works:

```bash
agent worker start
```

This required rebuilding `pty.node` (from `node-pty`) and `better_sqlite3.node`
for Bionic — see `docs/04-worker-fixes.md`.

## After `agent` / `cursor-agent update`

Updates replace the version directory, wiping our patches. Reapply them:

```bash
bash scripts/apply-patches.sh
```

This re-symlinks binaries, re-stubs preload, and rebuilds native addons against
the new version.

## Uninstall

```bash
# Keep ~/.cursor (chats, auth, plugins)
bash scripts/uninstall.sh

# Also delete ~/.cursor (backup first if you care about chats)
mkdir -p ~/backups
tar -czf ~/backups/cursor-dotcursor-$(date +%Y%m%d).tar.gz -C "$HOME" .cursor
bash scripts/uninstall.sh --purge-all
```

If you previously installed another Termux wrapper (npm package, etc.), remove
that package yourself — uninstall only clears the shared install paths.

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
│   └── uninstall.sh         # Remove install; --purge-all drops ~/.cursor
├── lib/
│   └── termux-preload.js    # Node.js preload (glibc spoof + stubs + opt-in tracer)
├── docs/
│   ├── 01–06 …              # Install / preload / natives / troubleshooting
│   ├── 07-plugin-transfer-hang.md
│   ├── 08-bridge-frame-tracing.md
│   └── evidence/plugin-hang/
└── ~/.local/bin/{agent,cursor-agent}  # Created by install.sh
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
