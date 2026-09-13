# Plugin transfer hang (large marketplace plugins)

On slow links (~1 Mbps), first chat / private-worker claim can stall ~5 minutes
when Cursor pushes a large marketplace plugin as **one** protobuf frame over the
HTTP/2 Connect bridge. The server RPC deadline fires before extract +
`.installed` complete, so every new chat retries the same download.

This is a **platform reliability** issue (bridge frame + deadline + packaging),
not a Termux-only bug. Termux made it easy to measure; a throttled PC should
reproduce the same pattern.

## Symptoms

- First tool call delayed several minutes after claim
- Debug/verbose: long gap, then `Writing binary file` for a huge `.tar.gz`, then
  `controller_disconnected` / reconnect
- Large plugin extract dir empty; no sibling `.installed` marker
- Small plugins (tens–hundreds of KB) finish fine in the same session

## Size vs behavior (lab, ~1.1 Mbps)

| Plugin | Approx size | Behavior |
|--------|-------------|----------|
| Context7 (`406`) | ~53 KB | Fine (&lt;3s with peers) |
| Supabase (`652`) | ~204 KB | Fine |
| shadcn UI (`6948`) | ~53 MB tar.gz | Hang / deadline / no `.installed` |

## Root cause

1. Cloud pushes the plugin as a **unary** `WriteBinaryFile` REQUEST: the entire
   blob is one frame on the bidi stream.
2. At **~143–190 KiB/s** on the bridge, ~53 MB takes **~274–358 s**.
3. Server deadline is roughly **300–360 s** → controller drops after (or during)
   the write; `tar -xzf` and `.installed` never run for that plugin.
4. Bootstrap can treat plugins as one transaction: a failing large push can leave
   a bad/empty manifest even when smaller plugins already extracted.

## HTTP vs bridge (same device, same day)

| Path | Bytes | Time | Rate |
|------|-------|------|------|
| Worker bridge (6948) | 53 353 271 | ~273.8 s | **~190 KiB/s** |
| Public HTTP (size-matched) | 53 353 271 | ~19.7 s | **~2.5 MiB/s** |
| GitHub `shadcn-ui/ui@10f1717a` | ~28.2 MB | ~11.2 s | **~2.5 MiB/s** |
| Local copy of blob | 53 353 271 | ~0.04 s | disk |

The phone radio is **not** the limiter. Hang is specific to the **plugin frame
on the worker bridge** (or whatever throttles that path).

Raw numbers: [`docs/evidence/plugin-hang/http-speed-results.txt`](evidence/plugin-hang/http-speed-results.txt).

## Packaging bloat

Cursor’s shadcn marketplace blob was the **whole `shadcn-ui/ui` git checkout**
(~9940 members, ~102 MB uncompressed), including a **~22 MB `.git` pack**. The
useful plugin bits (`.cursor-plugin/plugin.json` + skills) are tiny. Public
GitHub snapshot of the same commit is ~28 MB without that pack.

## `.installed` contract

- File is exactly **32 ASCII hex bytes**, **no newline**
- Contents equal marketplace `artifactDigest` (confirmed for Context7/Supabase)
- Cloud uses it to decide skip vs re-push; worker does not invent the digest
- After a failed large push, manually creating `.installed` can skip re-download
  but you must still extract the tar yourself — and updates can invalidate the
  digest. Prefer fixing network/packaging over permanent markers.

## Tracing on Termux

See [`08-bridge-frame-tracing.md`](08-bridge-frame-tracing.md). Evidence from the
instrumented run: [`docs/evidence/plugin-hang/`](evidence/plugin-hang/).

## PC reproduction checklist

1. Enable a large marketplace plugin (tens of MB) and a small control plugin.
2. Throttle the machine to ~1 Mbps down (or use a slow link).
3. Clear that plugin’s cache / `.installed` so cloud must re-push.
4. Start a fresh agent/worker chat and time claim → first tools.
5. If the large plugin hangs and the small one does not → escalate as **platform**
   bug (not Termux-specific).

## Escalation / disclosure

- Treat as a **reliability / availability** bug (timeout vs payload size).
- Real security issues: `security-reports@cursor.com` (see cursor.com/security).
- No public bounty was advertised for this class of issue at investigation time —
  do not bank on payout; forum / product feedback is the main path after PC repro.

## Related (deferred)

Android Agent Store parent-mode checks can warn when `/data` is group-writable
(normal on Android). Separate from this hang; see troubleshooting. Not fixed in
this repo yet.
