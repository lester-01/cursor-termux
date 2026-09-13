# Versioning strategy & release artifacts

## Why

Cursor Agent updates can break Termux patches (new native addons, layout
changes, Merkle/glibc detection). Users need a clear rollback story when that
happens.

## What is implemented today

Checked in: [`.github/workflows/daily-check.yml`](../.github/workflows/daily-check.yml).

It **can**:

- Run on a schedule (`0 6 * * *`) or `workflow_dispatch`
- Scrape an upstream version string from Cursor’s install script
- Download the arm64 agent tarball
- Attempt JS patches + a host-side `node-gyp` rebuild
- Upload a GitHub Actions artifact and attempt a `gh release` tarball

## Hard limits (do not oversell)

| Claim in older drafts | Reality |
|-----------------------|---------|
| “CI produces Termux-ready binaries” | **No.** Job runs on **Ubuntu x86_64**. Rebuilt `.node` files are not Bionic/Android ARM64 device builds. |
| “`versions-cache/` keeps last 3 forever” | **No.** That directory is **gitignored** and is **not** restored with `actions/cache`, so it is empty at the start of every run. |
| “Badge auto-updates” | **Not automated.** README badges are static unless you edit them. |
| “Ship full agent in git” | **Don’t.** Tree is ~**387 MB** installed / ~**131 MB** gzip on this device; also **proprietary** — use GitHub **Releases** only if Cursor’s terms allow redistribution, and prefer **on-device** `install.sh` as source of truth. |

**Reliable path today:** run `bash scripts/install.sh` (or `apply-patches.sh`) on the phone. Treat CI/Releases as experimental until a human downloads an artifact and verifies it on Termux.

## Recommended future CI (if you invest)

1. Keep daily **version detect** + notify (issue/discussion) when upstream moves.
2. Optionally upload the **unmodified** upstream tarball hash/URL for reproducibility (not a redistributed binary, if ToS is unclear).
3. For real Termux artifacts: build on **device** or a **Bionic/Android ARM64** runner, then `gh release upload` a tarball produced there.
4. Add `actions/cache` only if you intentionally want host-side scratch between runs — still not a device build.

## Launcher names

| Name | Role |
|------|------|
| `agent` | Primary launcher (symlink) |
| `cursor-agent` | Legacy name |
| `termux-cursor` | This repository |

## Rollback (device)

1. If you kept a known-good version directory under
   `~/.local/share/cursor-agent/versions/<ver>/`, point the launcher at it again
   (or reinstall that version with `install.sh` once the script supports pinning).
2. If a GitHub Release tarball was **human-verified on Termux**, extract into
   `versions/<ver>/` and run `bash scripts/apply-patches.sh`.
3. Repo owner for `gh` commands: `lester-01/termux-cursor`.

## Human-verified versions

When a version is confirmed on hardware, record it in
[`10-device-spec.md`](10-device-spec.md) and optionally bump the README agent badge.
