# How the Preload Script Works

The preload script (`lib/termux-preload.js`) is loaded via Node.js's `--require`
flag. It runs before any other code and intercepts several system APIs to
make Termux look like a glibc Linux environment.

## 1. Spoofing glibc Detection

Cursor Agent checks whether it's running on a glibc system by:

- **Reading `/usr/bin/ldd`**: We intercept `fs.existsSync` to return `true` for
  `/usr/bin/ldd`
- **Running `ldd`**: We intercept `cp.execSync` and `fs.readFileSync` to return
  `"ldd (GNU libc) 2.38"` whenever the command contains "ldd"
- **Checking `process.report.getReport()`**: We patch this to include
  `glibcVersionRuntime: "2.38"` in the report header

This tricks the agent's loader into taking the `linux-arm64-gnu` (glibc) code
path, rather than the `linux-arm64-musl` path which would fail differently.

## 2. Stubbing Native Addons

The agent ships with several proprietary native addons that we can't rebuild:

- **`@anysphere/file-service`** (and its platform variants): Provides file
  system operations. We replace it with a JavaScript stub that returns `null`
  for all operations. The agent degrades gracefully.

- **`@anysphere/merkle-tree-napi`**: Provides Merkle tree operations for code
  analysis. We replace it with a JavaScript stub that returns empty results.

- **`tree-sitter`** and **`tree-sitter-bash`**: Language parsers for code
  analysis. We replace them with JavaScript stubs that return empty parse trees.

These stubs are created by intercepting `process.dlopen` (which loads `.node`
files) and returning JS objects instead. For tree-sitter, we also intercept
`Module._resolveFilename` and `Module._load` to redirect `require()` calls.

## 3. Injecting Preload into Worker Threads

The agent spawns worker threads and child processes. Without intervention,
those workers would not have the preload applied. We intercept:

- `worker_threads.Worker` constructor to inject `--require` into `execArgv`
- `child_process.fork()` to inject `--require` into the forked process

This ensures all sub-processes also get the glibc spoofing and stubs.

## 4. Creating JS Package Shims

The preload also writes stub `package.json` and `index.js` files into
`node_modules/@anysphere/` and `node_modules/tree-sitter*/` so that any
`require()` calls that bypass `dlopen` still resolve to our stubs.

## Why Not Just Rebuild Everything?

Some native addons are open source and we rebuild them (see docs/03).
But `file-service` and `merkle` are proprietary — no source is available.
For those, stubbing is the only option.
