# Rebuilding Native Addons for Bionic

Some native addons are open source and can be rebuilt from source for Bionic.
This is the cleanest fix — the resulting `.node` files link against Android's
standard libraries and work without any hacks.

## How It Works

The install script does:

```bash
# Install the npm package source (without running its build scripts)
npm i node-pty --ignore-scripts --no-save

# Patch gyp files to skip Android NDK detection
# Termux's clang is not the Android NDK, but the build system
# may detect "android" and try to use NDK paths that don't exist.
sed -i -e 's/OS=="android"/OS=="never"/g' node_modules/node-pty/*.gyp

# Build targeting Linux (which maps to Bionic on Termux)
npx node-gyp rebuild -C node_modules/node-pty -- -DOS=linux -Dtarget_os=linux
```

## Addons We Rebuild

### `node-pty` → `pty.node`

**Source**: [microsoft/node-pty](https://github.com/microsoft/node-pty) (MIT)  
**Purpose**: Creates pseudo-terminals for the agent's worker mode  
**Output**: `pty.node` — 60 KB, links against `libc.so`, `libc++_shared.so`, `libdl.so`, `libm.so`, `liblog.so`

Without this, worker mode fails with:
```
Error: dlopen failed: library "libgcc_s.so.1" not found:
needed by .../pty.node in namespace (default)
```

### `better-sqlite3` → `better_sqlite3.node`

**Source**: [WiseLibs/better-sqlite3](https://github.com/WiseLibs/better-sqlite3) (MIT)  
**Purpose**: SQLite database for the agent's worker mode (stores state, config)  
**Output**: `better_sqlite3.node` — 2.1 MB, links against Bionic libs

Without this, worker mode fails with:
```
Error: Cannot find module 'better-sqlite3'
```

### `sqlite3` → `node_sqlite3.node`

**Source**: [TryGhost/node-sqlite3](https://github.com/TryGhost/node-sqlite3) (BSD)  
**Purpose**: SQLite database for the main agent process  
**Output**: `node_sqlite3.node` — rebuilt for Bionic

## Verification

After rebuilding, we verify the binary is Bionic-compatible:

```bash
readelf -d pty.node | grep NEEDED
# Should show: libc.so, libc++_shared.so, libdl.so, libm.so, liblog.so
# NOT: libc.so.6, libgcc_s.so.1, ld-linux-aarch64.so.1
```

## Limitations

- Rebuild is **best-effort**. If the build fails, the agent may still work
  without the affected feature (e.g., worker mode won't start without pty.node)
- After `cursor-agent update`, the new version directory has fresh glibc
  binaries — run `scripts/apply-patches.sh` to rebuild
