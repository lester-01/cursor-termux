#!/data/data/com.termux/files/usr/bin/bash
# termux-cursor: Remove Cursor Agent install from Termux
# Usage:
#   bash scripts/uninstall.sh              # keep ~/.cursor + ~/.config/cursor
#   bash scripts/uninstall.sh --purge-all  # also delete ~/.cursor (not login)
set -euo pipefail

HOME="${HOME:-/data/data/com.termux/files/home}"
INSTALL_ROOT="${HOME}/.local/share/cursor-agent"
BIN_DIR="${HOME}/.local/bin"
LAUNCHER="${BIN_DIR}/cursor-agent"
TMPDIR="${TMPDIR:-${PREFIX:-/data/data/com.termux/files/usr}/tmp}"

BLUE=$'\033[0;34m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

step() { printf '%s->%s %s\n' "$BLUE" "$NC" "$*"; }
ok()   { printf '%sok%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '%serror%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

PURGE_ALL=0
for arg in "$@"; do
  case "$arg" in
    --purge-all) PURGE_ALL=1 ;;
    -h|--help)
      cat <<EOF
Usage: bash scripts/uninstall.sh [--purge-all]

Removes the Termux Cursor Agent install:
  - ~/.local/share/cursor-agent
  - ~/.local/bin/cursor-agent and ~/.local/bin/agent
  - termux-cursor bashrc PATH block
  - \$TMPDIR/cursor-agent-persist-*

Default: keeps ~/.cursor (chats/plugins) and ~/.config/cursor (CLI login).
  --purge-all   also deletes ~/.cursor (not ~/.config/cursor/auth.json)

If you previously installed another Termux wrapper (npm package, etc.),
uninstall that yourself — this script only removes the shared install paths.
EOF
      exit 0
      ;;
    *)
      die "Unknown option: $arg (try --help)"
      ;;
  esac
done

step "Stopping agent processes (best effort)..."
pkill -f "${INSTALL_ROOT}/versions/.*/index.js" 2>/dev/null || true
pkill -f "/\.local/bin/cursor-agent" 2>/dev/null || true
pkill -f "/\.local/bin/agent" 2>/dev/null || true
sleep 1

step "Removing install tree and launchers..."
rm -rf "$INSTALL_ROOT"
rm -f "$LAUNCHER" "${BIN_DIR}/agent"
ok "Removed $INSTALL_ROOT"
ok "Removed $LAUNCHER and ${BIN_DIR}/agent"

step "Removing persist dirs under TMPDIR..."
rm -rf "${TMPDIR}"/cursor-agent-persist-* 2>/dev/null || true
ok "Cleared ${TMPDIR}/cursor-agent-persist-*"

if [[ -f "${HOME}/.bashrc" ]] && grep -q '# --- cursor-termux ---' "${HOME}/.bashrc" 2>/dev/null; then
  step "Removing bashrc PATH block..."
  awk '
    $0=="# --- cursor-termux ---" {skip=1; next}
    $0=="# --- end cursor-termux ---" {skip=0; next}
    !skip {print}
  ' "${HOME}/.bashrc" > "${HOME}/.bashrc.tmp" && mv "${HOME}/.bashrc.tmp" "${HOME}/.bashrc"
  ok "bashrc block removed"
fi

if [[ "$PURGE_ALL" -eq 1 ]]; then
  step "Purging ~/.cursor (--purge-all)..."
  if [[ -e "${HOME}/.cursor" ]]; then
    rm -rf "${HOME}/.cursor"
    ok "Removed ${HOME}/.cursor"
  else
    warn "~/.cursor already absent"
  fi
else
  warn "Kept ${HOME}/.cursor (chats/plugins). Use --purge-all to delete it."
  warn "Login stays in ${HOME}/.config/cursor (not removed by this script)."
  warn "Tip: tar -czf ~/backups/cursor-dotcursor-\$(date +%Y%m%d).tar.gz -C \"\$HOME\" .cursor"
fi

cat <<MSG

$(ok "Uninstall complete.")

  hash -r

To reinstall from this repo:
  bash scripts/install.sh

MSG
