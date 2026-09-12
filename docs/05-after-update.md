# After `cursor-agent update`

When Cursor releases a new version, `cursor-agent update` downloads the latest
tarball into a *new version directory* (e.g., `versions/2026.10.01-abc1234/`).
This new directory has **fresh glibc binaries** — all our patches are gone.

## What Gets Lost

After an update, the following need to be reapplied:

| Item | Lost? | Reapply via |
|---|---|---|
| Bundled `node` symlink | ✅ Yes | `apply-patches.sh` |
| Bundled `rg` symlink | ✅ Yes | `apply-patches.sh` |
| `pty.node` (Bionic rebuild) | ✅ Yes | `apply-patches.sh` |
| `better_sqlite3.node` (Bionic rebuild) | ✅ Yes | `apply-patches.sh` |
| `node_sqlite3.node` (Bionic rebuild) | ✅ Yes | `apply-patches.sh` |
| Merkle patch (index.js) | ✅ Yes | `apply-patches.sh` |
| Preload script | ❌ No (persists) | Already in place |
| Launcher script | ❌ No (but path may be stale) | `apply-patches.sh` |
| bashrc PATH entry | ❌ No | Already in place |
| glibc `.so` stubs in `$PREFIX/lib` | ❌ No | Already in place |

## How to Reapply

```bash
cd termux-cursor
bash scripts/apply-patches.sh
```

This script:
1. Detects the latest version directory
2. Re-symlinks `node` and `rg` to Termux binaries
3. Rebuilds `node-pty`, `better-sqlite3`, and `sqlite3` for Bionic
4. Re-patches the Merkle stub in `index.js`
5. Updates the launcher script with the new version path
6. Refreshes the preload file

## The Launcher's Role

The launcher (`~/.local/bin/cursor-agent`) finds the latest version directory
dynamically:

```bash
VERSION_DIR="$(ls -1d "${ROOT}"/* 2>/dev/null | sort | tail -n 1)"
```

So even if you forget to run `apply-patches.sh`, the launcher will start the
*new* version — but it will likely crash due to missing glibc-compatible
binaries. Always run the patch script after updating.

## What If the Update Changes the Preload API?

If Cursor changes how their loader works (e.g., new native addon names, new
glibc detection methods), the preload script may need updating. Check the
error message and compare with the docs in this repo to identify what changed.
