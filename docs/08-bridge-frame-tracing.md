# Bridge frame tracing

The Termux preload can log HTTP/2 Connect bridge frame progress. It is **off by
default** and only activates when you set an environment variable.

## Enable

```bash
export CURSOR_TRACE_FRAMES=true
# optional: override log path (default: $TMPDIR/bridge-trace.log)
# export CURSOR_TRACE_PATH="$HOME/bridge-trace.log"

hash -r
agent   # or: cursor-agent / worker start
```

After a run:

```bash
ls -la "${CURSOR_TRACE_PATH:-$TMPDIR/bridge-trace.log}"
tail -50 "${CURSOR_TRACE_PATH:-$TMPDIR/bridge-trace.log}"
```

## What you should see

- `=== Instrumentation loaded ===` when the preload patches `http2.connect`
- `FRAME_START` / `FRAME_END` for PrivateWorkerBridge / ControlService streams
- Byte totals and elapsed time; progress % when `content-length` is present

Connect bidi RPCs often omit `content-length`, so you may see `(unknown size)`
and still get a correct `FRAME_END` byte count from the `data` handler.

## Disable

Unset the variable (or set it to anything other than `true`) and restart the
agent process. No install change required.

```bash
unset CURSOR_TRACE_FRAMES
```

## Notes

- Tracer lives in `lib/termux-preload.js`; install/apply-patches copy it to
  `~/.local/share/cursor-agent/termux-preload.js`.
- Default path uses `os.tmpdir()` so Android/Termux never writes under `/tmp`.
- Sample hang evidence: [`docs/evidence/plugin-hang/bridge-trace.log`](evidence/plugin-hang/bridge-trace.log).
