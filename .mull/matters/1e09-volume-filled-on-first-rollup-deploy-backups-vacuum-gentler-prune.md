---
status: refined
tags: [p1, ops]
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
relates: [ed73]
---

# Volume filled on first rollup deploy: backups, VACUUM, gentler prune

2026-11-02 incident: after deploying the rollup (623195a) the 1GB /data volume filled: ~94MB DB + 10 pre-migrate backups (docker-entrypoint.sh MAX_BACKUPS=10) + WAL that grew while Litestream couldn't checkpoint during the first rollup's 173 back-to-back write txns and the 214k-row prune DELETE. Pre-migrate backup then failed ('database or disk is full') -> restart loop -> site down until volume extended to 3GB (fly volumes extend + stop/start). Replica in S3 stayed intact. Prune completed after restart (page_views 287k -> 73k).
Follow-ups:
1. Entrypoint: keep 2-3 backups, and only back up when migrations are pending (Litestream already holds the real backups in S3).
2. Delete old/partial /data/backups/pre-migrate-*.db via sleep-infinity pattern (destructive on prod - needs Jeff's OK).
3. One-off VACUUM: ~70% of the DB is free pages after the prune (~94MB -> ~30MB).
4. Rollup: prune in batches with a pause/checkpoint between, so a large backlog can't starve Litestream checkpoints again (steady state is ~1 day/run, low risk).
