# Oaks' guardrail settings, read by heartwood_guardrails' git hooks and review
# scripts (dev/githooks/ runs them). Sourced by sh and bash: assignments only.

# Names the reuse review's folder (<git dir>/oaks-review) and the push guard's
# override (OAKS_PUSH_MAIN=1).
HEARTWOOD_APP=oaks

# Paths a commit may touch without a reuse review: a directory ends in /,
# anything else is one file. AGENTS.md and CLAUDE.md are always reviewed, and
# so are CODING_STANDARDS.md and DESIGN.md, which hold rules too.
HEARTWOOD_PROSE="docs/ README.md CONTRIBUTING.md RELEASING.md"

# Prose to CI only: a pull request that changes nothing but these and the
# paths above skips the jobs that test code (heartwood's actions/changes, in
# ci.yml and security.yml). The commit gate still reviews them. Only files no
# code, test or build step reads.
HEARTWOOD_CI_PROSE="AGENTS.md CLAUDE.md CODING_STANDARDS.md DESIGN.md PRODUCT.md LICENSE DATA_LICENSE"

# Where a new file needs the reviewer's justification.
HEARTWOOD_LIB="lib/"

# Oaks' questions for the reuse reviewer, added to its packet.
HEARTWOOD_CHECKLIST=dev/guardrails/checklist.md

# The architecture review (MIX_ENV=test mix heartwood.architecture) uses the
# defaults: the docs in docs/architecture/, oaks' questions in
# dev/guardrails/architecture.md, and contexts named by three path segments
# (lib/oaks/species).
