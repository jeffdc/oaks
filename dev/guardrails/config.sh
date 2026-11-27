# Oaks' guardrail settings, read by heartwood_guardrails' git hooks and review
# scripts (dev/githooks/ runs them). Sourced by sh and bash: assignments only.

# Names the reuse review's folder (<git dir>/oaks-review) and the push guard's
# override (OAKS_PUSH_MAIN=1).
HEARTWOOD_APP=oaks

# Paths a commit may touch without a reuse review: a directory ends in /,
# anything else is one file. AGENTS.md, CLAUDE.md and DESIGN.md, which hold
# rules, are always reviewed. docs/ holds rules too (docs/COMPONENTS.md,
# docs/architecture/rules.md), but a change that touches only those is prose.
HEARTWOOD_PROSE="docs/ README.md CONTRIBUTING.md RELEASING.md"

# Where a new file needs the reviewer's justification.
HEARTWOOD_LIB="lib/"

# Oaks' questions for the reuse reviewer, added to its packet.
HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md

# The architecture review (MIX_ENV=test mix heartwood.architecture) uses the
# defaults: the docs in docs/architecture/, oaks' questions in
# dev/guardrails/architecture.md, and contexts named by three path segments
# (lib/oaks/species).
