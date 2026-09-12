# Acknowledgments

This project builds upon the work of several others who made Cursor Agent CLI
work on Termux before us:

## Direct Inspiration

- **[brukberhane/cursor-termux](https://github.com/brukberhane/cursor-termux)**
  (`npm: bruk-cursor-termux`) — Provided the core Termux preload mechanism,
  Merkle inline patching, tree-sitter JS stubs, LD_LIBRARY_PATH scoping, and
  the `bct --patch-only` workflow. This repo is a continuation of their work.

- **[Afnanksalal/cursor-termux](https://github.com/Afnanksalal/cursor-termux)**
  (`npm: cursor-termux`) — The original project that demonstrated how to patch
  the Cursor Agent for Termux. Bruk's fork built on top of this.

## Our Contributions (this repo)

- Worker mode support: rebuilt `pty.node` and `better_sqlite3.node` for Bionic
- Documented the *why* behind each fix (see `docs/`)
- Simplified install procedure with clearer error messages

## Upstream

- **[Cursor](https://cursor.com)** — The proprietary AI coding assistant whose
  Agent CLI we're making run on Termux. Cursor Agent is their property; this
  repo only ships compatibility glue.

## License

The code in this repo (installer, preload, launcher) is MIT licensed.
Cursor Agent itself is proprietary software of Anysphere / Cursor.
