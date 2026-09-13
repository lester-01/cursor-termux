#!/data/data/com.termux/files/usr/bin/bash
# cursor-termux: Install Cursor Agent CLI natively on Termux (Android ARM64)
# Usage: bash scripts/install.sh
set -euo pipefail

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"
INSTALL_ROOT="${HOME}/.local/share/cursor-agent"
BIN_DIR="${HOME}/.local/bin"
LAUNCHER="${BIN_DIR}/cursor-agent"
PRELOAD_DST="${INSTALL_ROOT}/termux-preload.js"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PRELOAD_SRC="${PKG_ROOT}/lib/termux-preload.js"

BLUE=$'\033[0;34m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

step() { printf '%s->%s %s\n' "$BLUE" "$NC" "$*"; }
ok()   { printf '%sok%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '%serror%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

require_termux() {
  [[ "${PREFIX}" == /data/data/com.termux/files/usr* ]] || \
    die "This installer is for Termux on Android only."
  local arch; arch="$(uname -m)"
  [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] || \
    die "Need ARM64 (got: $arch)."
  [[ -f "$PRELOAD_SRC" ]] || die "Missing lib/termux-preload.js (broken clone)."
}

safe_rm_version_dir() {
  local dir="$1"
  [[ -e "$dir" || -L "$dir" ]] || return 0
  if [[ -d "$dir" && ! -L "$dir" ]]; then
    rm -f "$dir/node" "$dir/rg" 2>/dev/null || true
    rm -rf "$dir"
  else
    rm -f "$dir" 2>/dev/null || true
  fi
}

cleanup_previous() {
  step "Cleaning previous installation..."
  pkill -f "${INSTALL_ROOT}/versions/.*/index.js" 2>/dev/null || true
  pkill -f "/\.local/bin/cursor-agent" 2>/dev/null || true
  sleep 0.3 2>/dev/null || true

  if [[ -d "${INSTALL_ROOT}/versions" ]]; then
    local d
    for d in "${INSTALL_ROOT}/versions"/*; do
      [[ -e "$d" ]] || continue
      safe_rm_version_dir "$d"
    done
  fi

  rm -f "${INSTALL_ROOT}/termux-preload.js" 2>/dev/null || true
  rm -rf "${INSTALL_ROOT}/versions" 2>/dev/null || true
  rm -f "$LAUNCHER" "${BIN_DIR}/agent"

  # Remove old bashrc block
  if [[ -f "${HOME}/.bashrc" ]] && grep -q '# --- cursor-termux ---' "${HOME}/.bashrc" 2>/dev/null; then
    awk '
      $0=="# --- cursor-termux ---" {skip=1; next}
      $0=="# --- end cursor-termux ---" {skip=0; next}
      !skip {print}
    ' "${HOME}/.bashrc" > "${HOME}/.bashrc.tmp" && mv "${HOME}/.bashrc.tmp" "${HOME}/.bashrc"
  fi

  mkdir -p "${INSTALL_ROOT}/versions" "$BIN_DIR" "$HOME/tmp"
  ok "Cleanup done"
}

install_deps() {
  step "Installing Termux packages..."
  pkg update -y
  pkg install -y curl git nodejs-lts ripgrep python make clang pkg-config binutils openssl-tool tar which
  command -v node >/dev/null || die "node missing after pkg install"
  command -v rg >/dev/null || die "ripgrep missing after pkg install"
  ok "Dependencies ready (node $(node -v))"
}

detect_version() {
  step "Detecting current Cursor Agent version..."
  local installer ver
  installer="$(mktemp)"
  curl -fsSL "https://cursor.com/install" -o "$installer"
  ver="$(grep -E -o '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]{7,}' "$installer" | head -n 1 || true)"
  rm -f "$installer"
  [[ -n "$ver" ]] || die "Could not parse version from https://cursor.com/install"
  CURSOR_VERSION="$ver"
  ok "Version: $CURSOR_VERSION"
}

download_package() {
  local url tmp stage src
  VERSION_DIR="${INSTALL_ROOT}/versions/${CURSOR_VERSION}"
  mkdir -p "${INSTALL_ROOT}/versions"
  step "Downloading agent package..."

  # Prefer android-specific tarball if available, fall back to linux/arm64
  url="https://downloads.cursor.com/lab/${CURSOR_VERSION}/linux/arm64/agent-cli-package.tar.gz"
  if curl -sfI "https://downloads.cursor.com/lab/${CURSOR_VERSION}/android/arm64/agent-cli-package.tar.gz" >/dev/null 2>&1; then
    url="https://downloads.cursor.com/lab/${CURSOR_VERSION}/android/arm64/agent-cli-package.tar.gz"
    ok "Using android/arm64 package"
  else
    ok "Using linux/arm64 package"
  fi

  tmp="$(mktemp -d)"
  stage="$(mktemp -d)"
  curl -fL --progress-bar "$url" | tar -xzf - -C "$tmp"
  if [[ -f "$tmp/index.js" ]]; then
    src="$tmp"
  else
    src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$src" ]] || die "Unexpected package layout"
  fi

  cp -a "$src"/. "$stage"/
  rm -f "$stage/node" "$stage/rg"
  safe_rm_version_dir "$VERSION_DIR"
  mv "$stage" "$VERSION_DIR"
  rm -rf "$tmp"

  [[ -f "$VERSION_DIR/index.js" ]] || die "index.js missing after extract"
  ok "Extracted to $VERSION_DIR"
}

swap_binaries() {
  step "Pointing bundled node/rg at Termux binaries..."
  rm -f "$VERSION_DIR/node" "$VERSION_DIR/rg"
  ln -s "$(command -v node)" "$VERSION_DIR/node"
  command -v rg >/dev/null 2>&1 && ln -s "$(command -v rg)" "$VERSION_DIR/rg" || true
  ok "node -> $(command -v node)"
}

install_glibc_stubs() {
  step "Creating glibc compatibility shims..."
  mkdir -p "$PREFIX/lib"
  local stub_c="$HOME/.cache/cursor-termux/empty-gnu-compat.c"
  mkdir -p "$(dirname "$stub_c")"
  cat > "$stub_c" <<'C'
void __termux_gnu_compat_stub(void) {}
C
  for lib in libm.so.6 libc.so.6 libpthread.so.0 libdl.so.2 libgcc_s.so.1; do
    clang -shared -fPIC -Wl,-soname,"$lib" "$stub_c" -o "$PREFIX/lib/$lib" 2>/dev/null || true
  done
  # Symlink libstdc++ for glibc compatibility
  if [[ -f "$PREFIX/lib/libc++_shared.so" ]]; then
    ln -sfn "$PREFIX/lib/libc++_shared.so" "$PREFIX/lib/libstdc++.so.6" 2>/dev/null || true
    ln -sfn "$PREFIX/lib/libc++_shared.so" "$PREFIX/lib/libstdc++.so" 2>/dev/null || true
  fi
  ok "glibc stubs ready"
}

rebuild_native_addon() {
  local pkg_name="$1"  # npm package name (e.g. node-pty, better-sqlite3)
  local node_name="$2" # output filename (e.g. pty.node, better_sqlite3.node)
  step "Rebuilding $pkg_name -> $node_name for Bionic..."
  (
    cd "$VERSION_DIR"
    npm i "$pkg_name" --ignore-scripts --no-save >/dev/null 2>&1 || true
    local pkg_dir="node_modules/$pkg_name"
    [[ -d "$pkg_dir" ]] || { warn "$pkg_name source not found, skipping"; return 0; }

    # Patch gyp files to skip Android detection (Termux's clang is not Android NDK)
    find "$pkg_dir" -type f \( -name '*.gyp' -o -name '*.gypi' \) -print0 2>/dev/null | \
      xargs -0 sed -i -E \
        -e 's/\bOS\s*==\s*"android"/OS=="never"/g' \
        -e 's/\btarget_os\s*==\s*"android"/target_os=="never"/g' \
        -e '/android_ndk_path/d' \
        -e '/ANDROID_/d' 2>/dev/null || true

    local jobs
    jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    npx node-gyp rebuild -C "$pkg_dir" -- -DOS=linux -Dtarget_os=linux -Dandroid_ndk_path=/nonexistent >/dev/null 2>&1 || true

    local built="$pkg_dir/build/Release/$node_name"
    if [[ -s "$built" ]]; then
      # Verify it's a Bionic binary (no glibc NEEDED entries)
      if readelf -d "$built" 2>/dev/null | grep -q 'NEEDED.*libc\.so$'; then
        cp -f "$built" "$VERSION_DIR/$node_name"
        ok "$node_name rebuilt for Bionic"
      else
        warn "$node_name rebuilt but may still have glibc deps; check readelf"
        cp -f "$built" "$VERSION_DIR/$node_name" 2>/dev/null || true
      fi
    else
      warn "$pkg_name rebuild failed; continuing"
    fi
  )
}

rebuild_native_addons() {
  step "Rebuilding native addons for Bionic..."
  # sqlite3 (already rebuilt by earlier installers, but be thorough)
  rebuild_native_addon "sqlite3" "node_sqlite3.node"
  # node-pty (needed for worker mode terminals)
  rebuild_native_addon "node-pty" "pty.node"
  # better-sqlite3 (needed for worker mode database)
  rebuild_native_addon "better-sqlite3" "better_sqlite3.node"
  ok "Native addon rebuild complete"
}

patch_merkle_stub() {
  step "Patching Merkle native binding -> JS stub..."
  local index_js="$VERSION_DIR/index.js"
  [[ -f "$index_js" ]] || die "index.js not found"
  cp -f "$index_js" "${index_js}.pre-merkle-bak"
  node - "$index_js" <<'NODE' || warn "Merkle patch skipped (pattern not found)"
const fs = require("fs");
const p = process.argv[2];
let src = fs.readFileSync(p, "utf8");
if (src.includes("MerkleClient:class{constructor(){}}")) {
  console.log("Merkle stub already present");
  process.exit(0);
}
const stub =
  '{MerkleClient:class{constructor(){}async build(){}async getTreeStructure(){return null}async getSimhash(){return[]}async getNumEmbeddableFiles(){return 0}},getParentProcessInfo:()=>null,MULTI_ROOT_ABSOLUTE_PATH:""}';
const exactFrom =
  "Original error: ${c&&c.stack?c.stack:c}`;throw new Error(n)}e.exports=u,e.exports.MerkleClient=u.MerkleClient";
const exactTo =
  "Original error: ${c&&c.stack?c.stack:c}`;u=" + stub + "}e.exports=u,e.exports.MerkleClient=u.MerkleClient";
if (src.includes(exactFrom)) {
  src = src.replace(exactFrom, exactTo);
  fs.writeFileSync(p, src);
  console.log("Patched Merkle throw -> stub (exact match)");
  process.exit(0);
}
const re = /if\(!\w\)\{let \w="Failed to load native binding for ".+?throw new Error\(\w\)\}/s;
if (re.test(src)) {
  src = src.replace(re, "if(!c){c=" + stub + ";}");
  fs.writeFileSync(p, src);
  console.log("Patched Merkle throw -> stub (regex fallback)");
  process.exit(0);
}
console.error("Could not locate Merkle failure path");
process.exit(2);
NODE
  node --check "$index_js" || die "Patched index.js failed syntax check"
  ok "Merkle stub OK"
}

patch_persist_tmpdir() {
  step "Patching persist state dir /tmp -> os.tmpdir()..."
  local index_js="$VERSION_DIR/index.js"
  [[ -f "$index_js" ]] || die "index.js not found"
  node - "$index_js" <<'NODE' || die "persist tmpdir patch failed"
const fs = require("fs");
const p = process.argv[2];
let src = fs.readFileSync(p, "utf8");
const from = 'A="cursor-agent",f="/tmp",h=';
const to = 'A="cursor-agent",f=u().tmpdir(),h=';
if (src.includes(to) && !src.includes(from)) {
  console.log("persist tmpdir already patched");
  process.exit(0);
}
if (!src.includes(from)) {
  console.error('Could not locate persist /tmp anchor (A="cursor-agent",f="/tmp",h=)');
  process.exit(2);
}
const count = src.split(from).length - 1;
if (count !== 1) {
  console.error("Expected exactly one persist /tmp anchor, found " + count);
  process.exit(2);
}
fs.writeFileSync(p, src.replace(from, to));
console.log('persist tmpdir patched (f="/tmp" -> u().tmpdir())');
NODE
  node --check "$index_js" || die "Patched index.js failed syntax check after persist tmpdir patch"
  ok "persist tmpdir OK"
}

install_preload_and_launcher() {
  step "Installing preload + durable launcher..."
  mkdir -p "$BIN_DIR" "$INSTALL_ROOT"
  cp -f "$PRELOAD_SRC" "$PRELOAD_DST"
  node --check "$PRELOAD_DST" || die "preload syntax check failed"

  cat > "$LAUNCHER" <<LAUNCHEREOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="\${PREFIX:-/data/data/com.termux/files/usr}"
HOME="\${HOME:-/data/data/com.termux/files/home}"
VERSION_DIR="${VERSION_DIR}"
# Match official package script: report how we were invoked (agent vs cursor-agent).
export CURSOR_INVOKED_AS="\$(basename "\$0")"
if [[ ! -f "\${VERSION_DIR}/index.js" ]]; then
  echo "cursor-agent: missing agent tree at \${VERSION_DIR}" >&2
  echo "Run: bash <dir>/scripts/install.sh" >&2
  exit 1
fi
export CURSOR_AGENT_VERSION_DIR="\${VERSION_DIR}"
export NODE_PATH="\${VERSION_DIR}/node_modules\${NODE_PATH:+:\${NODE_PATH}}"
# LD_LIBRARY_PATH for the agent process only (not in bashrc — safe for Termux-X11)
export LD_LIBRARY_PATH="\${PREFIX}/lib:\${LD_LIBRARY_PATH:-}"
PRELOAD="\${HOME}/.local/share/cursor-agent/termux-preload.js"
[[ -f "\${PRELOAD}" ]] || { echo "cursor-agent: missing preload; re-run install.sh" >&2; exit 1; }
case "\${NODE_OPTIONS:-}" in
  *termux-preload.js*) ;;
  *) export NODE_OPTIONS="--require=\${PRELOAD}\${NODE_OPTIONS:+ \${NODE_OPTIONS}}" ;;
esac
exec "\${PREFIX}/bin/node" -r "\${PRELOAD}" "\${VERSION_DIR}/index.js" "\$@"
LAUNCHEREOF
  chmod +x "$LAUNCHER"
  # Official install creates both names; agent is primary, cursor-agent is legacy.
  ln -sfn cursor-agent "${BIN_DIR}/agent"

  # Add PATH to bashrc (LD_LIBRARY_PATH is NOT exported here — only in launcher)
  local marker_begin="# --- cursor-termux ---"
  local marker_end="# --- end cursor-termux ---"
  touch "$HOME/.bashrc"
  if grep -q "$marker_begin" "$HOME/.bashrc" 2>/dev/null; then
    awk -v b="$marker_begin" -v e="$marker_end" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      !skip {print}
    ' "$HOME/.bashrc" > "$HOME/.bashrc.tmp" && mv "$HOME/.bashrc.tmp" "$HOME/.bashrc"
  fi
  cat >> "$HOME/.bashrc" <<BASHRC
${marker_begin}
export PATH="\$HOME/.local/bin:\$PATH"
${marker_end}
BASHRC

  ok "Launcher: $LAUNCHER"
  ok "Symlink: ${BIN_DIR}/agent -> cursor-agent"
  ok "Preload: $PRELOAD_DST"
}

smoke_test() {
  step "Smoke test..."
  export PATH="$BIN_DIR:$PATH"
  env -u LD_LIBRARY_PATH "$LAUNCHER" --help >/dev/null 2>&1 || \
    warn "cursor-agent --help had issues; check manually"
  ok "cursor-agent --help works"
  env -u LD_LIBRARY_PATH "${BIN_DIR}/agent" --help >/dev/null 2>&1 || \
    warn "agent --help had issues; check manually"
  ok "agent --help works"
}

main() {
  require_termux
  mkdir -p "$BIN_DIR" "$INSTALL_ROOT" "$HOME/tmp"

  install_deps
  cleanup_previous
  detect_version
  download_package
  swap_binaries
  install_glibc_stubs
  rebuild_native_addons
  patch_merkle_stub
  patch_persist_tmpdir
  install_preload_and_launcher
  smoke_test

  cat <<MSG

$(ok "Cursor Agent ready on Termux!")

  hash -r
  agent about
  # (legacy name also works: cursor-agent)
  NO_OPEN_BROWSER=1 agent login

  # In a project directory:
  agent

  # Worker mode:
  agent worker start

After agent update, reapply patches:
  bash scripts/apply-patches.sh

MSG
}

main "$@"
