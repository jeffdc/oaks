---
kind: decision
text: 'My four pages no longer use fe6d''s shared .edit-content-btn, .create-taxon-btn and .action-btn classes: their buttons are CoreComponents.button (compact ghost, primary ochre for the taxon form''s submit), so no page-scoped overrides of those classes were needed'
plan: compendium
item: 58ef
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a9900eef46870d81d
created: "2026-11-22T01:30:20Z"
---

A cheap template swap that avoids depending on fe6d's parallel restyle; create-taxon-btn stays as the element id the tests use
