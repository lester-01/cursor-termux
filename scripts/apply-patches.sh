#!/data/data/com.termux/files/usr/bin/bash
# termux-cursor: Reapply patches after `cursor-agent update`
# Usage: bash scripts/apply-patches.sh
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

BLUE=$'\033[0;34m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; NC=$'\033[0m'
step() { printf '%s->%s %s\n' "$BLUE" "$NC" "$*"; }
ok()   { printf '%sok%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s!%s %s\n' "$YELLOW" "$NC" "$*"; }
die()  { printf '%serror%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

latest_version_dir() {
  local d
  d="$(ls -1d "${INSTALL_ROOT}/versions"/* 2>/dev/null | grep -v '\.old$' | sort | tail -n 1 || true)"
  [[ -n "$d" && -f "$d/index.js" ]] || return 1
  printf '%s\n' "$d"
}

rebuild_native_addon() {
  local pkg_name="$1" node_name="$2"
  step "Rebuilding $pkg_name -> $node_name..."
  (
    cd "$VERSION_DIR"
    npm i "$pkg_name" --ignore-scripts --no-save >/dev/null 2>&1 || true
    local pkg_dir="node_modules/$pkg_name"
    [[ -d "$pkg_dir" ]] || { warn "$pkg_name source not found, skipping"; return 0; }
    find "$pkg_dir" -type f \( -name '*.gyp' -o -name '*.gypi' \) -print0 2>/dev/null | \
      xargs -0 sed -i -E \
        -e 's/\bOS\s*==\s*"android"/OS=="never"/g' \
        -e 's/\btarget_os\s*==\s*"android"/target_os=="never"/g' \
        -e '/android_ndk_path/d' -e '/ANDROID_/d' 2>/dev/null || true
    local jobs; jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
    npx node-gyp rebuild -C "$pkg_dir" -- -DOS=linux -Dtarget_os=linux -Dandroid_ndk_path=/nonexistent >/dev/null 2>&1 || true
    local built="$pkg_dir/build/Release/$node_name"
    if [[ -s "$built" ]]; then
      cp -f "$built" "$VERSION_DIR/$node_name"
      ok "$node_name rebuilt"
    else
      warn "$pkg_name rebuild failed; continuing"
    fi
  )
}

swap_binaries() {
  step "Pointing node/rg at Termux binaries..."
  rm -f "$VERSION_DIR/node" "$VERSION_DIR/rg"
  ln -s "$(command -v node)" "$VERSION_DIR/node"
  command -v rg >/dev/null 2>&1 && ln -s "$(command -v rg)" "$VERSION_DIR/rg" || true
  ok "node -> $(command -v node)"
}

install_glibc_stubs() {
  step "Creating glibc compatibility shims..."
  mkdir -p "$PREFIX/lib"
  local stub_c="$HOME/.cache/termux-cursor/empty-gnu-compat.c"
  mkdir -p "$(dirname "$stub_c")"
  [[ -f "$stub_c" ]] || cat > "$stub_c" <<'C'
void __termux_gnu_compat_stub(void) {}
C
  for lib in libm.so.6 libc.so.6 libpthread.so.0 libdl.so.2 libgcc_s.so.1; do
    clang -shared -fPIC -Wl,-soname,"$lib" "$stub_c" -o "$PREFIX/lib/$lib" 2>/dev/null || true
  done
  ok "glibc stubs ready"
}

patch_merkle_stub() {
  step "Patching Merkle -> JS stub..."
  local index_js="$VERSION_DIR/index.js"
  [[ -f "$index_js" ]] || die "index.js not found"
  cp -f "$index_js" "${index_js}.pre-merkle-bak" 2>/dev/null || true
  node - "$index_js" <<'NODE' || warn "Merkle patch skipped"
const fs = require("fs");
const p = process.argv[2];
let src = fs.readFileSync(p, "utf8");
if (src.includes("MerkleClient:class{constructor(){}}")) process.exit(0);
const stub = '{MerkleClient:class{constructor(){}async build(){}async getTreeStructure(){return null}async getSimhash(){return[]}async getNumEmbeddableFiles(){return 0}},getParentProcessInfo:()=>null,MULTI_ROOT_ABSOLUTE_PATH:""}';
const exactFrom = "Original error: ${c&&c.stack?c.stack:c}`;throw new Error(n)}e.exports=u,e.exports.MerkleClient=u.MerkleClient";
const exactTo = "Original error: ${c&&c.stack?c.stack:c}`;u=" + stub + "}e.exports=u,e.exports.MerkleClient=u.MerkleClient";
if (src.includes(exactFrom)) { fs.writeFileSync(p, src.replace(exactFrom, exactTo)); console.log("Merkle patched (exact)"); process.exit(0); }
const re = /if\(!\w\)\{let \w="Failed to load native binding for ".+?throw new Error\(\w\)\}/s;
if (re.test(src)) { fs.writeFileSync(p, src.replace(re, "if(!c){c=" + stub + ";}")); console.log("Merkle patched (regex)"); process.exit(0); }
console.error("Could not locate Merkle failure path"); process.exit(2);
NODE
  node --check "$index_js" || die "index.js syntax check failed"
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
  node --check "$index_js" || die "index.js syntax check failed after persist tmpdir patch"
  ok "persist tmpdir OK"
}

install_preload_and_launcher() {
  step "Installing preload + launcher..."
  mkdir -p "$BIN_DIR" "$INSTALL_ROOT"
  cp -f "$PRELOAD_SRC" "$PRELOAD_DST"
  node --check "$PRELOAD_DST" || die "preload syntax check"
  cat > "$LAUNCHER" <<LAUNCHEREOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
PREFIX="\${PREFIX:-/data/data/com.termux/files/usr}"
HOME="\${HOME:-/data/data/com.termux/files/home}"
VERSION_DIR="${VERSION_DIR}"
[[ -f "\${VERSION_DIR}/index.js" ]] || { echo "cursor-agent: missing tree" >&2; exit 1; }
export CURSOR_AGENT_VERSION_DIR="\${VERSION_DIR}"
export NODE_PATH="\${VERSION_DIR}/node_modules\${NODE_PATH:+:\${NODE_PATH}}"
export LD_LIBRARY_PATH="\${PREFIX}/lib:\${LD_LIBRARY_PATH:-}"
PRELOAD="\${HOME}/.local/share/cursor-agent/termux-preload.js"
[[ -f "\${PRELOAD}" ]] || { echo "cursor-agent: missing preload" >&2; exit 1; }
case "\${NODE_OPTIONS:-}" in *termux-preload.js*) ;; *) export NODE_OPTIONS="--require=\${PRELOAD}\${NODE_OPTIONS:+ \${NODE_OPTIONS}}" ;; esac
exec "\${PREFIX}/bin/node" -r "\${PRELOAD}" "\${VERSION_DIR}/index.js" "\$@"
LAUNCHEREOF
  chmod +x "$LAUNCHER"
  ok "Launcher updated"
}

main() {
  VERSION_DIR="$(latest_version_dir)" || die "No installed agent version found. Run install.sh first."
  step "Patching $VERSION_DIR"
  swap_binaries
  install_glibc_stubs
  rebuild_native_addon "node-pty" "pty.node"
  rebuild_native_addon "better-sqlite3" "better_sqlite3.node"
  rebuild_native_addon "sqlite3" "node_sqlite3.node"
  patch_merkle_stub
  patch_persist_tmpdir
  install_preload_and_launcher
  export PATH="$BIN_DIR:$PATH"
  env -u LD_LIBRARY_PATH "$LAUNCHER" --help >/dev/null 2>&1 && ok "cursor-agent --help works" || warn "check manually"
  ok "Patches reapplied. hash -r && cursor-agent about"
}

main "$@"
