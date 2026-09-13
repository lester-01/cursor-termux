# Reference device specification

Device used for the latest end-to-end fresh install of this repo
(install → patches → smoke → login → usage).

## Tested device (latest fresh install)

| Field | Value |
|-------|-------|
| **Manufacturer** | Xiaomi |
| **Model** | `2303CRA44A` (Redmi Pad SE) |
| **Product name** | `ocean_global` |
| **Android version** | 14 |
| **API level (SDK)** | 34 |
| **Kernel** | `4.19.191-g6215d3010025` |
| **Kernel build date** | Wed Feb 19 13:30:52 CST 2025 |
| **Architecture** | aarch64 (ARM64) |
| **Termux** | F-Droid |
| **Node.js** | v24.18.0 (`nodejs-lts`) |
| **Agent version** | `2026.09.10-fd3934a` |
| **Install date** | 2026-09-13 |

## Why this matters

Cursor Agent ships native binaries for `linux/arm64` (glibc). Termux uses
Bionic. Patches in this repo bridge that gap, but **kernel version, Android API
level, and available syscalls** still affect whether rebuilt addons
(`node-pty`, `better-sqlite3`, `sqlite3`) compile and run.

Older kernels (e.g. &lt; 4.19) or 32-bit ARM (`armv7l`) are **not** tested.

## Reporting issues

If `install.sh` or `apply-patches.sh` fails on your device, open a bug with
[`.github/ISSUE_TEMPLATE/bug-report.md`](../.github/ISSUE_TEMPLATE/bug-report.md)
and paste the **full** device-info command output from that template.

## Previously tested devices

| Date | Model | Android | Kernel | Outcome | Notes |
|------|-------|---------|--------|---------|-------|
| 2026-09-13 | Redmi Pad SE (`2303CRA44A`) | 14 | 4.19.191 | Working | Fresh install via this repo’s installer |
