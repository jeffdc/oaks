---
kind: decision
text: Wrap Mix.Tasks.SmokeTest in if Code.ensure_loaded?(Req) so the task is compiled only where Req is a dependency (dev and test), leaving Req dev/test-only
plan: ""
item: 6df3
by: /Users/jeff/dev/oaks/.claude/worktrees/agent-a401775827acbfdf7
created: "2026-11-22T00:44:35Z"
---

The smoke test runs only from CI's dev-env nix shell and locally, never in the release; making Req a prod dep would add Req, Finch and Mint to the Docker build for nothing, @compile no_warn_undefined would hide the warning but leave a task that crashes in prod, and excluding lib/mix via elixirc_paths would need the file moved or a fragile path list
