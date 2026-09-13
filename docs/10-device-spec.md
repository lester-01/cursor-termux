# Reference Device Specification

This document records the device on which this repo's `install.sh` was last
tested end-to-end (fresh install → patch → smoke → login → usage).

## Tested Device (latest fresh install)

| Field | Value |
|-------|-------|
| **Manufacturer** | `Xiaomi` |
| **Model** | `2303CRA44A` (Redmi Pad SE) |
| **Product name** | `ocean_global` |
| **Android version** | `14` |
| **API level (SDK)** | `34` |
| **Kernel** | `4.19.191-g6215d3010025` |
| **Kernel build date** | `Wed Feb 19 13:30:52 CST 2025` |
| **Architecture** | `aarch64` (ARM64) |
| **Termux** | F-Droid build |
| **Node.js** | `$(node -v)` (LTS via `nodejs-lts`) |
| **Install date** | `$(date +%Y-%m-%d)` |

## Why this matters

Cursor Agent ships native binaries for `linux/arm64` (glibc). Termux uses
Bionic (Android's libc). The patches in this repo compensate for that gap,
but **kernel version, Android API level, and available syscalls** can affect
whether rebuilt native addons (`node-pty`, `better-sqlite3`, `sqlite3`)
compile and run correctly.

Older kernels (e.g. < 4.19) or 32-bit ARM (`armv7l`) are **not** tested and
may require additional work.

## Reporting issues — what to include

If `install.sh` or `apply-patches.sh` does not work on your device, open a
bug report using the template at
`.github/ISSUE_TEMPLATE/bug-report.md`.  The template asks for the same
fields above — please run every command and paste the **full** output.

## Previously tested devices

| Date | Model | Android | Kernel | Outcome | Notes |
|------|-------|---------|--------|---------|-------|
| $(date +%Y-%m-%d) | Redmi Pad SE (2303CRA44A) | 14 | 4.19.191 | ✅ Working | Fresh install with --purge-all |
