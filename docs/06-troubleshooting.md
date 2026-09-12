# Troubleshooting

## Common Errors and Solutions

### "bad interpreter: No such file or directory"

**Error:**
```
cursor-termux: /usr/bin/env: bad interpreter: No such file or directory
```

**Cause:** The script has a shebang like `#!/usr/bin/env node` or `#!/usr/bin/env bash`.
Termux does not have `/usr/bin/env` — the env binary is at `$PREFIX/bin/env`.

**Fix:** Use the launcher script directly, which has a Termux-compatible shebang:
```bash
~/.local/bin/cursor-agent
```

Or install the `termux-exec` package which sets up compatibility:
```bash
pkg install termux-exec
```

### "dlopen failed: library ... not found"

**Error:**
```
Error: dlopen failed: library "libgcc_s.so.1" not found:
needed by .../pty.node in namespace (default)
```

**Cause:** A native `.node` addon is compiled against glibc and is looking for
glibc shared libraries that don't exist on Bionic.

**Fix:** Run `bash scripts/apply-patches.sh` to rebuild native addons and create
glibc compatibility shims.

### "Cannot find module 'better-sqlite3'"

**Error:**
```
Error: Cannot find module 'better-sqlite3'
Require stack:
- .../index.js
```

**Cause:** The worker mode needs `better-sqlite3` which wasn't rebuilt for Bionic.

**Fix:** Run `bash scripts/apply-patches.sh` which rebuilds better-sqlite3 from source.

### "SIGSYS: bad system call"

**Error:**
```
SIGSYS: bad system call
PC=0x... m=0 sigcode=1
syscall.faccessat2(...)
```

**Cause:** This happens with Go binaries compiled with upstream Go ≥1.20 on
Android kernels <5.8. The `faccessat2` syscall doesn't exist on older kernels.

**Fix:** This is NOT a cursor-agent issue (cursor-agent is Node.js, not Go).
But if you're seeing this with other tools, use Termux's patched Go toolchain
(`pkg install golang`) which avoids this syscall.

### "Failed to login" / "Network error"

**Cause:** Cursor's API may be blocked by your network, or the login URL didn't
open correctly.

**Fix:**
```bash
# Print the URL instead of trying to open a browser
NO_OPEN_BROWSER=1 cursor-agent login
# Open the printed URL manually in any browser
```

### "cursor-agent update" broke things

**Fix:** Always run after update:
```bash
bash scripts/apply-patches.sh
```

### "Text file busy" when installing

**Cause:** An old `cursor-agent` process is still running and holding files.

**Fix:**
```bash
pkill -f "cursor-agent" 2>/dev/null || true
sleep 1
# Then retry
bash scripts/install.sh
```

### "npm ERR! code EINTEGRITY" during rebuild

**Cause:** npm integrity check failed due to incomplete download.

**Fix:**
```bash
cd ~/.local/share/cursor-agent/versions/*/
npm cache clean --force 2>/dev/null || true
# Then re-run apply-patches.sh
```

### "ENOENT: no such file or directory, mkdir '/tmp/cursor-agent-persist-…'"

**Error:**
```
Could not safely resume chat …: ENOENT: no such file or directory,
mkdir '/tmp/cursor-agent-persist-10328'
```

**Cause:** Upstream Cursor Agent hardcodes persist/resume state under `/tmp`.
Android/Termux has no writable `/tmp` at the filesystem root (`TMPDIR` is
`$PREFIX/tmp` instead).

**Fix:** Reapply patches (includes the persist tmpdir rewrite):
```bash
bash scripts/apply-patches.sh
```

This replaces the hardcoded `f="/tmp"` persist base with `os.tmpdir()` so
state lands in `$TMPDIR/cursor-agent-persist-<uid>`.

## Collecting Debug Info

```bash
# Check version and status
cursor-agent about
cursor-agent status

# Run with verbose logging
cursor-agent --verbose

# Check which .node files are loaded
ls -la ~/.local/share/cursor-agent/versions/*/*.node

# Check dynamic library dependencies
readelf -d ~/.local/share/cursor-agent/versions/*/pty.node | grep NEEDED

# Check if preload is loaded
NODE_OPTIONS="--require=$HOME/.local/share/cursor-agent/termux-preload.js" \
  node -e "console.log('preload loaded')"
```
