# Versioning Strategy & Release Artifacts

## Why

Cursor Agent updates can break our Termux patches (new native addon, changed
module layout, updated Merkle/glibc detection). When that happens, users are
left without a working agent until we push a fix.

This document describes how we **keep last-known-working versions** so users
always have a fallback, and how CI automates the detection → patch → publish
pipeline.

## Lifecycle of a version

```
Upstream release
      │
      ▼
CI detects new version (daily cron @ 06:00 UTC)
      │
      ▼
CI downloads → applies patches → smoke tests
      │
      ├── ✅ PASS → publish as GitHub Release + cache (up to 3 versions)
      │
      └── ❌ FAIL → human reviews, may mark previous version as
                     "✅ human-verified" (gold badge)
```

## Cached versions

The repo's CI caches **at most 3 most recent** patched versions in the
`versions-cache/` directory (GitHub Actions workspace). Each version is also
uploaded as a **release artifact** on GitHub Releases.

| Artifact | Format | Retention |
|----------|--------|-----------|
| CI workflow artifact | Directory of `index.js` + `*.node` + stubs | 90 days (GitHub max) |
| GitHub Release tarball | `termux-cursor-<YYYY.MM.DD-commit>.tar.gz` | Permanent |

## Badges

We use shields.io-style badges in the README:

| Badge | Meaning |
|-------|---------|
| ![CI](https://img.shields.io/badge/CI-daily--check-blue) | Workflow status (pass/fail) |
| ![Latest](https://img.shields.io/badge/latest-YYYY.MM.DD--sha-green) | Most recent patched version |
| ![Cached](https://img.shields.io/badge/cached-3-brightgreen) | Number of cached versions |
| ![Verified](https://img.shields.io/badge/verified-YYYY.MM.DD--sha-gold) | Human-reviewed working version |
| ![Broken](https://img.shields.io/badge/latest-YYYY.MM.DD--sha-red) | Latest CI build failed |

These are updated by the CI workflow after each run (or manually for the
"human-verified" badge).

## Human-verified badge

When a human has confirmed a specific version works on a real device, the
badge is updated manually (via a PR or direct push). The device details for
that verification are recorded in `docs/10-device-spec.md`.

## Binary naming

| Name | Type | Created by |
|------|------|------------|
| `agent` | Primary launcher | `install.sh` / `apply-patches.sh` |
| `cursor-agent` | Legacy symlink → `agent` | `install.sh` / `apply-patches.sh` |
| `termux-cursor` | Repo / project name | — |

The npm ecosystem already has:
- `cursor-termux` (Afnanksalal) — upstream original
- `bruk-cursor-termux` (Bruk) — fork with tree-sitter stubs

To avoid collision, this repo uses **`termux-cursor`** as its package/brand
name (matching the GitHub repo). If published to npm it would be
`@prinxlexter/termux-cursor` or scoped similarly.

## Release naming convention

```
termux-cursor-<YYYY.MM.DD-commit>.tar.gz
```

Example: `termux-cursor-2026.09.10-fd3934a.tar.gz`

## Rollback procedure

1. List available releases:
   ```bash
   gh release list --repo prinxlexter/termux-cursor
   ```
2. Download the last known working version:
   ```bash
   gh release download v2026.09.02-c22c1a3 --repo prinxlexter/termux-cursor
   tar -xzf termux-cursor-2026.09.02-c22c1a3.tar.gz \
     -C ~/.local/share/cursor-agent/versions/2026.09.02-c22c1a3/
   bash scripts/apply-patches.sh
   ```
3. Or re-run the playbook using the cached artifact directly.
