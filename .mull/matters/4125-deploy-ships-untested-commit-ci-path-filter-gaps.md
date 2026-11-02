---
status: done
tags: [p0, ci]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Deploy ships untested commit; CI path filter gaps

- .github/workflows/deploy.yml:22: checkout has no ref:, so a workflow_run deploy ships main HEAD at deploy time, not the commit CI tested. Fix: ref: ${{ github.event.workflow_run.head_sha }} (both deploy and smoke-test jobs).
- .github/workflows/ci.yml:6-16 paths filter omits docker-entrypoint.sh, litestream.yml, rel/**, Makefile, .github/workflows/deploy.yml -> those changes never trigger CI/deploy.
- superfly/flyctl-actions/setup-flyctl@master is unpinned.
(Actions bumped to checkout@v7/cache@v6 in cfdbb68.)
