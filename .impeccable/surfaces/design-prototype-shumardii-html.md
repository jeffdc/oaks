---
version: 1
slug: "design-prototype-shumardii-html"
primary_target: "design/prototype/shumardii.html"
related_targets: ["design/prototype/compare.html","design/prototype/x-riparia.html","design/prototype/acutissima.html","design/prototype/hypoleucoides.html"]
---

# Taxon page

Mode: Read. Prototype at design/prototype/ (static HTML, outside the Phoenix app) until the data model exists.

## Audience and job

Identifiers (often arriving from an iNat tab, also on a phone under a tree, or studying a group) need "is it this, or that?" answered at once. Researchers need name, author, synonymy and the source of every claim.

## Content and order

1. Taxonomy breadcrumb, stable in the same place on every taxon page (genus › subg. › sect. › subsect. › complex › taxon), every step linked; varieties and hybrids use it too.
2. Title: name, author, common name, status with its source.
3. Jeff's general write-up of the taxon, in his words, directly under the title and above everything else (Jeff, 2026-11-20: "the most important part"): a short excerpt on the page, the full text in a popover that closes on Esc or a click outside. It must not dominate the page.
4. Most distinguishing traits: a short ranked set, Jeff's statement first with source mark and agree/differs mark. Photos as a carousel in a left column (empty until exemplars exist).
5. Look-alikes easy to reach and compare: a side-by-side trait comparison per look-alike, shareable by URL.
6. Hybrids at hand: always visible near the top, each with its other parent.
7. All field marks by trait in flora order, Jeff first, other sources behind.
8. Range: text first (states/provinces by country, native/introduced, sourced) in a layout that reserves the map's place.
9. Nomenclature and synonymy, sources, a cite-this-page line (format decided at build).

States: full taxon; thin NA taxon; honest catalog stub (others' data clearly marked, says Jeff hasn't covered it); hybrid page between its parents; variety page under its species; conflicts marked, never hidden; view state in the URL.

## Anti-goals

Must not feel like a SaaS dashboard, a coffee-table book, a scraped aggregator, or a dense academic flora. Must not look like a dichotomous key (Jeff, 2026-11-20): no couplets, key numbering, dotted leaders or key path. No bud sketch or life-size callouts.

## Direction contract

THESIS: The taxon page is a field reference that answers "is it this, or that?" first: the traits that set it apart, then its look-alikes and hybrids one step away. It refuses the database-shaped page of source tabs and stacked cards.

OWN-WORLD: Taken from the pocket dendrology key's printed materials, not its structure. Ink black (#161616) on bright white stock (#fbfbf7), an ochre band (#d9a21b) as the one committed field, a pencil blue (#2f5fb3) for source marks and links. Heavy grotesk (Archivo) for the frame, a sturdy text serif (Source Serif 4) for reading. Statements stand on rules, never in boxes. Agree / differs / unreviewed are drawn marks, not colours. Counts set in tabular figures.

STORY: The reader sees where the taxon sits, reads the few traits that separate it in Jeff's words with their sources, opens a look-alike to compare side by side, or jumps to a hybrid; a researcher follows any mark to its source and copies the citation.

FIRST VIEWPORT: Ink masthead with nav and search. Ochre band with the taxonomy breadcrumb at fixed height. Title row: italic name, author, common name, status. Directly under it, Jeff's write-up as a short excerpt that opens the full text in a popover. Below, three columns: photo carousel left; distinguishing traits as the reading column centre; look-alikes (each with Compare) and hybrids (with the other parent) in the right rail.

FORM: The Twig Key world (the "Twig Key" sketch, .impeccable/mocks/decision/assigned.html), its key structure removed at Jeff's direction; Jeff confirmed on 2026-11-21 that design/prototype/shumardii.html shows it. The decision page recorded no answer, and roll seed:48b50a33fc9e9d1f doesn't list this world, so the seed is not its source. Signature interaction: choosing a look-alike opens a side-by-side comparison aligned trait by trait, at a shareable URL.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
