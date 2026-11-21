---
kind: decision
text: Test files import the fixture modules they use explicitly; DataCase and ConnCase don't auto-import them
plan: compendium
item: "5762"
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a3668863f96bd227b
created: "2026-11-21T23:02:40Z"
settled:
  action: accept
  note: with review 3ff7
  by: Jeff
  human: true
  at: "2026-11-21T23:08:02Z"
---

Matches gallformers and the existing AccountsFixtures use, and keeps each file's dependencies visible; CODING_STANDARDS.md updated to say so.
