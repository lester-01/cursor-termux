# Why This Exists

## The Problem

Cursor Agent CLI is a Node.js application distributed by Cursor (Anysphere).
It ships as a tarball containing:

1. A bundled `index.js` (the agent code)
2. A set of **native addons** (`.node` files) — compiled C/C++ code loaded by Node.js
3. Bundled `node` and `ripgrep` binaries

These native addons and binaries are compiled against **glibc** (GNU C Library),
the standard libc on Linux distributions.

Termux runs on Android, which uses **Bionic** (Android's own C library).
Bionic is not binary-compatible with glibc. Specifically:

- **Different library names**: glibc uses `libc.so.6`, `libm.so.6`, `libpthread.so.0`, etc.
  Bionic uses `libc.so`, `libm.so`, etc.
- **Different ABI**: Even where names overlap, the internal symbols differ
- **Different dynamic linker**: glibc uses `ld-linux-aarch64.so.1`;
  Android uses `/system/bin/linker64`

When you try to load a glibc-compiled `.node` file on Termux, you get:

```
Error: dlopen failed: library "libgcc_s.so.1" not found:
needed by .../pty.node in namespace (default)
```

## The Solution

This project takes a layered approach:

1. **Replace bundled binaries** with Termux-native ones (`node`, `ripgrep`)
2. **Rebuild open-source addons** from source for Bionic (`node-pty`, `better-sqlite3`, `sqlite3`)
3. **Stub proprietary addons** with pure JavaScript replacements (`file-service`, `merkle`)
4. **Spoof glibc detection** so the agent loader takes the correct code path
5. **Create empty shim libraries** with the correct glibc `soname` to satisfy the dynamic linker

## Why Not Proot?

[Proot](https://github.com/termux/proot) runs a full Linux distribution inside
Termux, providing a glibc environment. This works but:

- Heavy: hundreds of MB for a minimal distro
- Performance overhead from syscall translation
- File system isolation can be confusing
- You lose direct access to Termux's tools and files

Native execution is lighter, faster, and more integrated.
