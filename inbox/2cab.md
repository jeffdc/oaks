---
kind: decision
text: ?dry_run with any value other than true is a 400, not an apply
plan: compendium
item: f8f5
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-ab5c413275376b6b6
created: "2026-11-21T22:58:44Z"
---

A producer that writes dry_run=false or dry_run=1 should learn the rule rather than have the request treated as something it didn't mean.
