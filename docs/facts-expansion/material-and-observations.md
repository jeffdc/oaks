# Material and observations

Phase 7 of the [Facts expansion](README.md). Jeff's verbatim material in the database, private, with sources. Needs Sources and facts core; can run beside Taxonomy.

## Done when

- Jeff's existing material is loaded, after he checks a sample.
- A test shows no public route returns materials.
- Duplicates are grouped.
- Jeff can capture a single iNat comment or exemplary observation by URL.

## Known so far

1. **Materials schema.** Verbatim text, kind, date, URL, observation, authorship (Jeff, cited, not Jeff), taxon links (target and mentioned), set-aside flag, duplicate group. Private: never in the public API.
2. **Load Jeff's notes material.** From `compendium-notes/` (kept locally, outside git): the snippets, manuscript paragraphs with authorship flags, review notes. Jeff's keep/drop sorting maps to set-aside; other people's comments are excluded. Loaded through the import endpoint; Jeff checks a sample from the dry-run report before it applies.
3. **Duplicate grouping.** Group near-duplicate materials so the editor can fold them.
4. **Observations and capture mode.** Import an iNat observation or comment by URL with photos, licence and attribution; observation roles: exemplar, evidence, material, trait illustration.

## What already exists

The [species photos plan](../species-photos-plan.md) built the exemplar role for photos: `Oaks.INaturalist` (observation and photo fetching, licence mapping), `Oaks.Images` with its `images` table (one row per iNat photo per species, with the observation and photo IDs), durable imports on Oban, and the Add photos dialog on the species page. Step 4 builds on it rather than beside it. The quote locator for evidence spans into materials is ported from gallformers here (see [Sources and facts core](sources-and-facts.md)).

## Held for this phase

- The home page sketch had an epigraph quoting Jeff's own iNat words (on *Quercus shumardii*). It was left out because his material wasn't in the database and the plan forbids hand-picking or hard-coding his prose. Jeff wants it once the material is in.

## To work out

- Whether observations become their own table that images point at (an observation with several photos and roles), or the `images` table grows the other roles.
- Where capture mode lives in the site: the species page's Add photos dialog widened to comments and roles, or a separate capture screen.
- Which material reads agents need through the private API (its `materials:read` scope exists) for fact proposals and entry assembly.
- How the home page epigraph's quote is chosen: random, one Jeff marks, or per visit.
