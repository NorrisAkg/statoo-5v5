# Staging merge verification - 17 October 2026

Scenarios before conflict resolution:
- MERGE-01: retain both original commits as ancestors; no history rewrite.
- MERGE-02: individual ADMIN/PDT/VP/SG/SGA can author sport, shared members and expired identities cannot; ownership and financial limits unchanged.
- MERGE-03: live goals/assists, correction, undo and stale-history protection still pass.
- MERGE-04: keep Flutter web runtime, transport, packaging, offline local state, short names and backups.
- MERGE-05: publish new portal cache 2026-10-17-merged-1; remove welcome/admin/presidency/loading predecessors only in same scope; keep new cache and unrelated caches.
- MERGE-06: preserve all original tracked/untracked files; archive excluded evidence and configuration privately, no secrets committed.
- MERGE-07: active-session sync and concurrent offline starts remain recoverable; web and mobile role matrices agree.
- MERGE-08: run backend, Flutter, portal unit/browser suites, actual Flutter web build and packaged browser flows; distinguish failures and uncovered checks.


## Verification results

- Original checkout preserved throughout preparation; private verified backup: mobile/build/merge-safety-20261017 (150 paths, SHA-256 manifest, binary patch and verified complete Git bundle). Safety refs preserve both starting commits.
- Merge commit be305e1 retains e6cef61 and 8193637. Inventory: 86 integrated source/test/document paths; 64 audit/private configuration paths retained outside application commits. See fusion-file-inventory.json.
- Full Flutter suite: 450 passed. Additional live role controller check: 11 passed, exercising ADMIN/PDT/VP/SG/SGA and refusing shared members. Full backend: 76 passed, one existing Starlette/httpx warning. Web units: 59 passed. Critical platform/runtime analysis: no issues.
- Flutter web release and universal packaging succeeded in the isolated checkout. Live browser workflow, local offline/backup/restore and shared active-session resume each passed.
- Portal first run: 93/100; hardcoded test ports and an old-toast race were corrected in fixtures only. The 33 affected-file tests passed on retry. The final complete run passed 100/100, recorded in merge-browser-portal-final.txt.
- Cache MERGE-05 had two behavioral RED failures before the application version change. New cache merged-1 preserves all workflows; four PWA tests pass and the dedicated review approved preservation of unrelated scopes.
- Dedicated merge review found no blocker in sports permissions, ownership, stale history, transport or active-session sync. A pre-existing mobile ADMIN finance capability differs from the restrictive backend/portal author matrix; this merge introduces no financial permission expansion.
- Screenshot actually viewed: shared live screen, 1100px, light theme (local screenshot excluded from commits). Physical devices, Safari/Firefox, assistive readers and remote deployment remain unverified.

## Safe local delivery

A fresh fetch still shows origin/staging=e6cef61. The original dirty checkout will be saved with include-untracked stash (retained), fast-forwarded to the verified candidate, then excluded evidence restored byte-for-byte. No force push, hard reset or clean is used. No remote push is part of this operation.
