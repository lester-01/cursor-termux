#!/usr/bin/env bash
set -euo pipefail

# This script downloads the official Cursor Agent installer, programmatically
# modifies it for Android/Termux compatibility, and then executes it.
# It uses `sed` and temporary files to inject logic, making it resilient to
# version changes in the official installer.

# --- Helper Functions ---
step() { echo -e "\033[0;34m▸\033[0m $1"; }
ok() { echo -e "\033[0;32m✓\033[0m $1"; }
err() { echo -e "\033[0;31m✗\033[0m $1" >&2; }
warn() { echo -e "\033[0;33m! $1\033[0m" >&2; }

# --- Main Execution ---
main() {
    # --- Code Blocks for Injection ---
    local ANDROID_DETECT_BLOCK
    ANDROID_DETECT_BLOCK=$(cat <<'EOF'
# Android/Termux detection
IS_ANDROID=false
if command -v getprop > /dev/null 2>&1 || [[ "${ANDROID_ROOT-}" ]] || [[ "${PREFIX-}" == /data/data/* ]]; then
  IS_ANDROID=true
fi
EOF
)

    local DYNAMIC_DOWNLOAD_BLOCK
    DYNAMIC_DOWNLOAD_BLOCK=$(cat <<'EOF'
# Prefer android build if vendor provides it
DOWNLOAD_OS="$OS"
if $IS_ANDROID; then
  # Check if an Android-specific build exists for this version
  if curl -sfI "https://downloads.cursor.com/lab/${VER}/android/${ARCH}/agent-cli-package.tar.gz" > /dev/null; then
    DOWNLOAD_OS="android"
  else
    # Fallback to linux if no android build is found
    DOWNLOAD_OS="linux"
  fi
fi
DOWNLOAD_URL="https://downloads.cursor.com/lab/${VER}/${DOWNLOAD_OS}/${ARCH}/agent-cli-package.tar.gz"
EOF
)

    local ANDROID_FIXES_BLOCK
    ANDROID_FIXES_BLOCK=$(cat <<'EOF'

# ============ Android/Termux post-install fixes ============
if $IS_ANDROID; then
  echo
  echo -e "${BOLD}Android/Termux post-install fixes${NC}"

  # 1) Ensure Node points to Termux node (glibc node cannot run)
  print_step "Patching Node runtime..."
  if ! command -v node > /dev/null 2>&1; then
    print_error "Node.js not found in PATH. Install it (e.g. pkg install nodejs)."
    exit 1
  fi
  SYS_NODE="$(command -v node)"
  rm -f "$FINAL_DIR/node"
  ln -s "$SYS_NODE" "$FINAL_DIR/node"
  print_success "node → $SYS_NODE"

  # 2) Replace bundled ripgrep (rg) if present (glibc builds won't run)
  if [[ -e "$FINAL_DIR/rg" ]]; then
    print_step "Replacing bundled rg (ripgrep)..."
    if command -v rg > /dev/null 2>&1; then
      rm -f "$FINAL_DIR/rg"
      ln -s "$(command -v rg)" "$FINAL_DIR/rg"
      print_success "rg → $(command -v rg)"
    else
      print_error "ripgrep (rg) not found. Install it (e.g. pkg install ripgrep)."
    fi
  fi

  # 3) Rebuild sqlite3 native addon for bionic
  echo
  print_step "Rebuilding sqlite3 native addon for Android/bionic..."

  need_bins=(clang make python pkg-config npm)
  missing=()
  for b in "${need_bins[@]}"; do command -v "$b" > /dev/null 2>&1 || missing+=("$b"); done
  if [[ ${#missing[@]} -gt 0 ]]; then
    print_error "Missing build tools: ${missing[*]}"
    echo -e "${YELLOW}Install them (e.g. 'pkg install ...' or 'pacman -S ...'):\npacman -S --needed clang make python pkgconf npm sqlite${NC}"
    exit 1
  fi

  cd "$FINAL_DIR" || { print_error "Could not enter directory '$FINAL_DIR'"; exit 1; }

  unset LINK || true
  J=$(($(getconf _NPROCESSORS_ONLN 2> /dev/null || echo 1)))
  rm -f build/node_sqlite3.node || true
  npm ci --ignore-scripts > /dev/null 2>&1 || true
  npm i sqlite3 --ignore-scripts

  if [[ -d node_modules/sqlite3 ]]; then
    print_step "Patching gyp files..."
    find node_modules/sqlite3 -type f \( -name '*.gyp' -o -name '*.gypi' \) -print0 | xargs -0 sed -i -E \
      -e 's/\bOS\s*==\s*"android"/OS=="never"/g' \
      -e 's/\btarget_os\s*==\s*"android"/target_os=="never"/g' \
      -e '/android_ndk_path/d' \
      -e '/ANDROID_/d'
    print_success "Patched gyp"
  else
    print_error "sqlite3 sources not found under node_modules."
    exit 1
  fi

  print_step "Building sqlite3 addon (this can take a minute)..."
  npx node-gyp configure -C node_modules/sqlite3 -- -DOS=linux -Dtarget_os=linux -Dandroid_ndk_path=/nonexistent
  make -C node_modules/sqlite3/build -j "$J" V=1 LINK=clang++

  if [[ -f node_modules/sqlite3/build/Release/node_sqlite3.node ]]; then
    mkdir -p "$FINAL_DIR/build"
    install -m0755 node_modules/sqlite3/build/Release/node_sqlite3.node build/node_sqlite3.node
    print_success "sqlite3 addon rebuilt"
  else
    print_error "Failed to produce node_sqlite3.node"
    exit 1
  fi

  node -e "require('$FINAL_DIR/build/node_sqlite3.node');"
  print_success "sqlite3 addon loads under Termux Node"

  cd - > /dev/null
fi
EOF
)

    # --- Script Logic ---
    local installer; installer=$(mktemp)
    local android_detect_file; android_detect_file=$(mktemp)
    local dynamic_download_file; dynamic_download_file=$(mktemp)
    local android_fixes_file; android_fixes_file=$(mktemp)

    # Add all temp files to the trap for cleanup
    # shellcheck disable=SC2064
    trap "rm -f '$installer' '$android_detect_file' '$dynamic_download_file' '$android_fixes_file'" EXIT

    # Write code blocks to temp files to prevent shell expansion issues
    echo "${ANDROID_DETECT_BLOCK}" > "${android_detect_file}"
    echo "${DYNAMIC_DOWNLOAD_BLOCK}" > "${dynamic_download_file}"
    echo "${ANDROID_FIXES_BLOCK}" > "${android_fixes_file}"

    step "Downloading official installer..."
    if ! curl -sSL "https://cursor.com/install" -o "$installer"; then
        err "Failed to download the official installer."
        exit 1
    fi
    ok "Download complete."

    step "Patching installer for Android/Termux..."

    local ver_string
    ver_string=$(grep -E -o '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]{7,}' "$installer" | head -n 1)
    if [[ -z "$ver_string" ]]; then
        err "Could not determine version string from the official installer."
        err "The script may have changed. Please report this issue."
        exit 1
    fi
    ok "Detected version: $ver_string"

    # Use sed with file-based injection to avoid shell expansion issues.
    # Note the use of `r` to read from a file and `d` to delete.
    sed -i \
        -e "/^ARCH=.*$/r ${android_detect_file}" \
        -e "/print_success \"Detected/c\print_success \"Detected \${OS}/\${ARCH}\$([ \${IS_ANDROID} = true ] && echo ' (Android/Termux)')\"" \
        -e "s/${ver_string}/\${VER}/g" \
        -e "/# Installation steps/i VER=\"${ver_string}\"" \
        -e "/DOWNLOAD_URL=.*/r ${dynamic_download_file}" \
        -e "/DOWNLOAD_URL=.*/d" \
        -e "/^print_step \"Creating symlink/a BIN_DIR=\$HOME/.local/bin\nBIN_LINK=\$BIN_DIR/cursor-agent\nFINAL_DIR=\$HOME/.local/share/cursor-agent/versions/\${VER}" \
        -e "s|~/.local/bin/cursor-agent|\$BIN_LINK|g" \
        -e "s|~/.local/share/cursor-agent/versions/\${VER}/cursor-agent|\$FINAL_DIR/cursor-agent|g" \
        -e "/^print_success \"Symlink created\"/r ${android_fixes_file}" \
        -e "/Start using Cursor Agent:/c\echo -e \"\${BOLD}2.\${NC} Start using Cursor Agent:\"\necho -e \"   \${BOLD}cursor-agent --help\${NC}\"" \
        "$installer"

    ok "Patching complete."
    echo
    step "Executing patched installer..."
    echo "=================================================="
    bash "$installer" "$@"
    echo "=================================================="
    ok "Patched installer finished."
}

main "$@"
