# Maintenance

## Background

Maintained source fork: `0xble/Tachikoma` of `openclaw/Tachikoma`, both `main`.
This temporary clone was inspected from owned `origin/main`
`df8caabfb7f2895ab1d7797d976387ee57c5760a`; accepted upstream baseline:
`8ea8a90ab4840fe26870cf8d720e878b0b91078d`. Publish only to `origin`, never
upstream. Synchronization, publication, installation, and runtime use are
separate stages.

## Preserve

- MCP resource content must tolerate the changed shape while retaining adapter,
  provider, and type-conversion agreement.

## Active patches

### TACHIKOMA-001: `fix(mcp): handle resource content shape changes`

- **Provenance:** `953313647f2c35b0ed6d2c6551a4772a4c7f5820`, merged to this fork by [PR #1](https://github.com/0xble/Tachikoma/pull/1) as `df8caabfb7f2895ab1d7797d976387ee57c5760a`.
- **Surfaces:** `MCPToolAdapter.swift`, `MCPToolProvider.swift`, `TypeConversions.swift`.
- **Upstream issue / PR:** None after checked 2026-09-09 / None after checked 2026-09-09.
- **Regression:** Blocked: the patch added no focused changed-content fixture; add one before reconciliation or publication.
- **Rollback:** Revert the fork merge `df8caabfb7f2895ab1d7797d976387ee57c5760a` (or the patch commit on a rebased branch), then run the complete gate.
- **Retire when:** an upstream release implements equivalent shape compatibility with a focused fixture.

## Update and verify

Every run fetches owned `main` and latest upstream `main`, reconciles only this
recorded patch, runs `swift test` and `swift build`, and publishes only after
its blocked regression is resolved. Immediately fetch upstream again;
`git rev-list --left-right --count upstream/main...main` must show zero
upstream-only commits. After authorized publication require local/`origin/main`
SHA parity; otherwise report `Blocked` with failed stage and exact refs. Do not
install, activate, or validate a runtime without separate authorization and
exact runtime-SHA proof.
