---
kind: decision
text: 'The 403 page is written for a refused form (title ''Request refused''): the only HTML 403 today is Plug.CSRFProtection''s invalid-token error; Go back is primary when there is a Referer, else Log in'
plan: compendium
item: e237
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-aa59fd67ee390c2c2
created: "2026-11-22T00:06:10Z"
settled:
  action: accept
  note: with review aba6
  by: Jeff
  human: true
  at: "2026-11-22T00:24:28Z"
---

The impeccable finish reviewer found 'You don't have permission to see this page' named the wrong problem; the API's 403s are JSON and never reach this page
