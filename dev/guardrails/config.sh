# Oaks' guardrail settings, read by heartwood_guardrails' git hooks and review
# scripts (dev/githooks/ runs them). Sourced by sh and bash: assignments only.

# Names the reuse review's folder (<git dir>/oaks-review) and the push guard's
# override (OAKS_PUSH_MAIN=1).
HEARTWOOD_APP=oaks

# Where heartwood_guardrails is, from the repository's root: Mix checks a
# sparse git dependency out into its folder's own directory.
HEARTWOOD_HOME=deps/heartwood_guardrails/guardrails

# Paths a commit may touch without a reuse review: a directory ends in /,
# anything else is one file. AGENTS.md and CLAUDE.md are always reviewed, and
# so are CODING_STANDARDS.md and DESIGN.md, which hold rules too.
HEARTWOOD_PROSE="docs/ README.md CONTRIBUTING.md RELEASING.md"

# Where a new file needs the reviewer's justification.
HEARTWOOD_LIB="lib/"

# Oaks' questions for the reviewer, added to the packet.
HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md
