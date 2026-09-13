---
name: "\U0001F41E Bug Report — Cursor Agent on Termux"
about: "Something doesn't work? File a report so we can diagnose it."
title: "[Bug] "
labels: ["bug", "needs-triage"]
assignees: []
---

<!--
Thanks for taking the time to fill out this bug report.
Please answer EVERY section — incomplete reports will be closed.
-->

## Device Information (MANDATORY)

Run these commands in Termux and paste the output:

```bash
echo "=== Device ==="
getprop ro.product.manufacturer
getprop ro.product.model
getprop ro.product.name
echo "=== Android ==="
getprop ro.build.version.release
getprop ro.build.version.sdk
echo "=== Kernel ==="
uname -r
uname -m
echo "=== Termux ==="
dpkg --print-architecture 2>/dev/null || echo "unknown"
echo "=== Storage ==="
df -h /data/data/com.termux/files/home 2>/dev/null | tail -1
echo "=== Node ==="
node -v
echo "=== npm ==="
npm -v
echo "=== Installed packages ==="
pkg list-installed 2>/dev/null | grep -E 'nodejs|ripgrep|clang|make|python|binutils|openssl' || true
```

## What were you doing?

*Fresh install / after update / normal usage / other (specify):*

## What did you expect?

```

```

## What actually happened? (paste the FULL error, not a summary)

```

```

## Which version of this repo are you using?

<!-- Run: git -C ~/projects/termux-cursor log --oneline -1 -->
```
<commit hash here>
```

## Which Cursor Agent version?

<!-- Run: agent about | head -10 -->
```

```

## Have you run the playbook steps and verified preload?

```bash
# Check launcher exists
ls -la ~/.local/bin/cursor-agent ~/.local/bin/agent 2>&1

# Check preload matches repo
cmp -s ~/projects/termux-cursor/lib/termux-preload.js ~/.local/share/cursor-agent/termux-preload.js 2>&1

# Check persist tmpdir patch applied
rg -n 'tmpdir\(\)' ~/.local/share/cursor-agent/versions/*/index.js 2>/dev/null | head -5
```

Paste results here:

```

```

## Screenshots / logs

If applicable, attach screenshots or a log file.

## Is this a regression?

*Did it work before? If yes, what was the last working version?*

## Additional context

*Anything else that might help? E.g. proxy, VPN, root, custom kernel, etc.*
