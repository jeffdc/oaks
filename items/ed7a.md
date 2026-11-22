---
title: Require a parent for non-root taxa
stage: captured
kind: idea
source: item a161
created: "2026-11-22T01:55:45Z"
updated: "2026-11-22T01:55:45Z"
---

Taxon.changeset could validate_required(:parent) unless level is subgenus, so no save or import can silently orphan a section, subsection or complex (it drops out of the tree and its page 404s). Left out of a161 because the changeset is shared with the import path (Oaks.Import.Tables) and some test fixtures create parentless sections, and the Taxonomy phase (5ba9) may reshape taxa anyway. Related: the taxon form's parent select could keep the stored parent as an option even when it names no taxon at the parent level, as the species form's taxon_options does, so a save can't drop it either.
