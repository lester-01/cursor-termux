#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# termux-cursor — fresh install playbook (manual)
# =============================================================================
# This is NOT an automated installer. Read it, then run the commands yourself
# (copy/paste block by block). If something breaks, point another LLM at this
# repo + this file.
#
# State layout (Termux):
#   ~/.config/cursor/auth.json  — CLI login (survives agent reinstall)
#   ~/.cursor/                  — chats, plugins, project metadata
#   ~/.local/share/cursor-agent — binaries / preload (what install/uninstall own)
#
# Goal: remove bruk / other Termux wrappers, install THIS repo’s build, verify.
# Default uninstall keeps ~/.cursor and does NOT touch ~/.config/cursor — so
# you usually will NOT need to log in again after reinstall.
# =============================================================================

set -euo pipefail

# --- 0) Where you are --------------------------------------------------------
# cd ~/projects/termux-cursor

# --- 1) Backup chats + login -------------------------------------------------
# mkdir -p ~/backups
# tar -czf ~/backups/cursor-dotcursor-$(date +%Y%m%d).tar.gz -C "$HOME" .cursor
# tar -czf ~/backups/cursor-config-$(date +%Y%m%d).tar.gz -C "$HOME" .config/cursor
# ls -lh ~/backups/cursor-*.tar.gz

# --- 2) Remove foreign Termux wrappers (npm) ---------------------------------
# Live machine had: bruk-cursor-termux (global). Afnan’s package name is
# cursor-termux — uninstall if present; ignore errors if not installed.
# npm uninstall -g bruk-cursor-termux
# npm uninstall -g cursor-termux
# hash -r
# command -v bct bruk-cursor-termux || echo "npm wrappers gone (or not on PATH)"

# --- 3) Remove shared Cursor Agent install paths -----------------------------
# Keeps ~/.cursor and ~/.config/cursor. Removes ~/.local/share/cursor-agent,
# launchers, bashrc block, and $TMPDIR/cursor-agent-persist-*.
# bash scripts/uninstall.sh
#
# ONLY if you also want to wipe chats/plugins under ~/.cursor (restore tar later).
# Note: --purge-all still leaves ~/.config/cursor (login) alone.
# bash scripts/uninstall.sh --purge-all
# tar -xzf ~/backups/cursor-dotcursor-YYYYMMDD.tar.gz -C "$HOME"

# --- 4) Install this repo ----------------------------------------------------
# bash scripts/install.sh
# hash -r

# --- 5) Confirm (feature matrix) ---------------------------------------------
# command -v agent cursor-agent
# agent --help >/dev/null && echo "agent --help OK"
# cursor-agent --help >/dev/null && echo "cursor-agent --help OK"
# agent about
# agent status   # expect Logged in …
# cmp -s lib/termux-preload.js "$HOME/.local/share/cursor-agent/termux-preload.js" \
#   && echo "preload matches repo" || echo "PRELOAD MISMATCH"
# # Persist patch: must use os.tmpdir(), not hardcoded /tmp
# rg -n 'tmpdir\(\)|cursor-agent-persist|/tmp' \
#   "$HOME/.local/share/cursor-agent/versions/"*/index.js | head -20
# # Optional: gated frame tracer (off by default)
# # CURSOR_TRACE_FRAMES=true agent about
# # ls -la "${TMPDIR:-/tmp}/bridge-trace.log" 2>/dev/null || true
# # One interactive turn (login usually already present via ~/.config/cursor):
# # cd /path/to/some/project && agent

# --- 6) If login is needed ---------------------------------------------------
# NO_OPEN_BROWSER=1 agent login

# --- Rollback hints (for you or another LLM) ---------------------------------
# - Chats/plugins: restore cursor-dotcursor-*.tar.gz into $HOME
# - Login: restore cursor-config-*.tar.gz (or re-run agent login)
# - Agent binaries: re-run bash scripts/install.sh from this repo
# - Old bruk: npm install -g bruk-cursor-termux  (last resort; prefer this repo)
# - Docs: README.md, docs/06-troubleshooting.md, docs/07-plugin-transfer-hang.md

echo "This file is a commented playbook only."
echo "Open it, uncomment/copy the steps, run them yourself."
echo "Nothing was changed by invoking: $0"
