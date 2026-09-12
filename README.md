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
NO_OPEN_BROWSER=1 cursor-agent login

# 4. Use it
cd your-project
cursor-agent
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
cursor-agent worker start
```

This required rebuilding `pty.node` (from `node-pty`) and `better_sqlite3.node`
for Bionic — see `docs/04-worker-fixes.md`.

## After `cursor-agent update`

Updates replace the version directory, wiping our patches. Reapply them:

```bash
bash scripts/apply-patches.sh
```

This re-symlinks binaries, re-stubs preload, and rebuilds native addons against
the new version.

## Files

```
termux-cursor/
├── README.md                # This file
├── LICENSE                  # MIT
├── ACKNOWLEDGMENTS.md       # Credits to bruk, afnan, and others
├── scripts/
│   ├── install.sh           # Fresh install from scratch
│   └── apply-patches.sh     # Reapply after cursor-agent update
├── lib/
│   └── termux-preload.js    # Node.js preload (glibc spoof + stubs)
├── docs/
│   ├── 01-why-this-exists.md
│   ├── 02-how-preload-works.md
│   ├── 03-rebuilding-native-addons.md
│   ├── 04-worker-fixes.md
│   ├── 05-after-update.md
│   └── 06-troubleshooting.md
└── bin/
    └── cursor-agent         # Launcher (created by install.sh)
```

## Prerequisites

- Android **ARM64** (aarch64)
- [Termux](https://f-droid.org/en/packages/com.termux/) from F-Droid
- About 1.5 GB free space (for builds)
- A Cursor subscription (for API access)

## License

MIT for the glue code in this repo. Cursor Agent is proprietary software of
Anysphere / Cursor.
