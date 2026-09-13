# Versioning & artifacts (roadmap)

Status: **TODO** — listed in the README roadmap. Not claimed as shipping today.

## When we pick this up

1. **CI** — daily check for new Cursor Agent versions (notify / issue).
2. **Optional release tarballs** — only after reviewing Cursor’s Terms of Service
   for redistributing Agent binaries.
3. **Supported path** — keep `scripts/install.sh` / `scripts/apply-patches.sh`
   on-device as the real install.

## Implementer notes

- GitHub-hosted Linux runners ≠ Termux/Bionic; don’t market host rebuilds as
  phone-ready Agent builds.
- Don’t commit Agent binaries into git.
- Record human-verified versions in [`10-device-spec.md`](10-device-spec.md).
