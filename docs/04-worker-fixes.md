# Worker Mode Fixes

Cursor Agent's worker mode (`cursor-agent worker start`) runs a background
process that handles tasks. Getting this working required fixing two additional
native addons beyond what the original installer handled.

## The Problem

When running `cursor-agent worker start`, we hit:

```
Error: dlopen failed: library "libgcc_s.so.1" not found:
needed by .../pty.node in namespace (default)
```

After fixing that:

```
Error: Cannot find module 'better-sqlite3'
```

## Root Cause

The main agent process (`index.js`) uses `node_sqlite3` for its database needs,
and the file-service / merkle addons are stubbed by the preload. But the worker
mode spawns additional code paths that load:

1. **`node-pty`** (`pty.node`) — Creates pseudo-terminals for running
   sub-processes in the worker. This is a C++ addon that needs `libgcc_s.so.1`
   for GCC exception handling.

2. **`better-sqlite3`** (`better_sqlite3.node`) — A faster SQLite3 binding used
   by the worker for its own database. This is a C++ addon with its own
   bundled SQLite amalgamation.

Both are available as open-source npm packages with build systems, so we can
rebuild them for Bionic.

## The Fix

### 1. Create `libgcc_s.so.1` shim (temporary workaround)

For `.node` files that can't be rebuilt (proprietary ones), we create empty
shared libraries with the correct glibc soname:

```bash
clang -shared -fPIC -Wl,-soname,libgcc_s.so.1 empty.c -o $PREFIX/lib/libgcc_s.so.1
```

This is a stub — the actual GCC unwind functions are not provided. But for
`.node` files that don't actually call these functions at runtime (or whose
calls are caught by C++ exception handlers), this is enough to satisfy the
dynamic linker.

### 2. Rebuild `node-pty` from source

```
npm i node-pty --ignore-scripts
# Patch gyp, build for linux target
npx node-gyp rebuild -C node_modules/node-pty -- -DOS=linux -Dtarget_os=linux
cp node_modules/node-pty/build/Release/pty.node .
```

### 3. Rebuild `better-sqlite3` from source

Same approach — it includes its own SQLite amalgamation, so the build takes
longer (~2 minutes).

## Verification

After rebuilding, test that the worker starts:

```bash
cursor-agent worker start --verbose
```

You should see:
```
13:27:06 INFO  Starting in worker mode ...
13:27:07 INFO  Fetching user privacy mode...
```

The worker will stay running until you send SIGINT or SIGTERM.
