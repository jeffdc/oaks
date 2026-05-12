---
status: raw
tags: [tier-1]
created: 2026-05-12
updated: 2026-05-12
epic: gallformers-port
---

# Document mull workflow in CLAUDE.md

Oaks just migrated from beads to mull. Without documented conventions, agents will invent ad-hoc patterns.

Implementation:
- Add 'Task Tracking with mull' section to oaks/CLAUDE.md
- Cover: status lifecycle (raw→refined→planned→active→done), epic-as-label convention, when to use --needs vs --blocks vs --relates, when matter vs TodoWrite
- Reference active epics (e.g. species-maps, gallformers-port) as examples
- Remove or update any remaining beads references

Crib from: gallformers/CLAUDE.md mull section

Effort: S
