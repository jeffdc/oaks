---
kind: decision
text: The parse refusals the private API answers are an explicit list of Plug's own exceptions (ParseError, RequestTooLargeError, UnsupportedMediaTypeError, BadEncodingError, InvalidQueryError, BadRequestError, TimeoutError), each with its own message; anything else raises as before
plan: ""
item: 254e
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a2b5f373901cd058e
created: "2026-11-22T00:50:27Z"
---

A catch-all on any 4xx plug_status would also swallow adapter errors (Bandit's) whose meaning isn't known here, and specific messages tell an agent what to fix
