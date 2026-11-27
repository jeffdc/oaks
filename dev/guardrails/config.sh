# Oaks' guardrail settings, read by heartwood_guardrails' git hooks and review
# scripts (dev/githooks/ runs them). Sourced by sh and bash: assignments only.

# Names the reuse review's folder (<git dir>/oaks-review) and the push guard's
# override (OAKS_PUSH_MAIN=1).
HEARTWOOD_APP=oaks

# Prose: a commit that touches only these needs no reuse review, and a pull
# request that changes only these skips the jobs that test code (heartwood's
# actions/changes, in ci.yml and security.yml). A directory ends in /; an entry
# with *, ? or [...] is a pattern, where * matches across /, so *.md is every
# Markdown file, anywhere, AGENTS.md, CLAUDE.md and DESIGN.md included (Jeff,
# 2026-11-27: doc-only commits skip review). No code, test or build step reads
# Markdown. One that does (content, a prompt, a fixture) goes in
# HEARTWOOD_CODE, or a change to it alone would skip both.
HEARTWOOD_PROSE="docs/ *.md LICENSE DATA_LICENSE"

# Where a new file needs the reviewer's justification.
HEARTWOOD_LIB="lib/"

# Oaks' questions for the reuse reviewer, added to its packet.
HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md

# The architecture review (MIX_ENV=test mix heartwood.architecture) uses the
# defaults: the docs in docs/architecture/, oaks' questions in
# dev/guardrails/architecture.md, and contexts named by three path segments
# (lib/oaks/species).
