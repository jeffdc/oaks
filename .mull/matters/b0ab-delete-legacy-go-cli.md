---
status: done
tags: [p3, cleanup]
effort: S
created: 2026-11-02
updated: 2026-11-02
epic: audit-2026-11
---

# Delete legacy Go CLI

cli/ (~18.6k lines) can't build: cli/internal/embedded/embedded.go:8 imports github.com/jeff/oaks/api/embed via go.mod replace => ../api, removed in cbf66c8 (2026-02-08). Targets dead schema (oak_entries, species_sources keyed by scientific_name, taxa.notes — cli/internal/db/db.go:80-160) and dead API (POST/PUT/DELETE /api/v1/species..., /api/v1/export, /api/v1/health). Nothing invokes it (Makefile, CI, Dockerfile; .dockerignore excludes /cli/).
Hazards if revived: oak taxa import --clear DELETEs all taxa outside a txn then fails inserts (cmd/taxa.go:194, db.go:339,262); db.New creates oak_entries on open (db.go:109); cli/README.md:322-336 says to rm the prod DB over SSH and SFTP a local copy.
Before deleting: decide on cli/data/*.yaml (3.7k-line seed snapshot covered by DATA_LICENSE:9). Update DATA_LICENSE, README.md:52, CLAUDE.md:36, .github/copilot-instructions.md:33, scripts/transform_to_export_schema.py:6, scripts/import_inat_species.py:161,228.
Requires Jeff's OK (destructive).
