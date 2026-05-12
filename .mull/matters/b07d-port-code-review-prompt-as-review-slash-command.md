---
status: raw
tags: [tier-1]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Port code-review prompt as /review slash command

Adopt gallformers' code-review rubric as an oaks-specific slash command. Highest-ROI agent-workflow port.

Implementation:
- Copy /Users/jeff/dev/gallformers/prompts/code-review.md to oaks/.claude/commands/review.md
- Replace gallformers/Postgres references with oaks/SQLite/Phoenix-LiveView
- Adjust persona references (Quercus context, sources model, taxonomy specifics)
- Keep the severity-level + correctness/idiom/perf/security/tests/clarity rubric structure

Crib from: gallformers/prompts/code-review.md

Effort: S
