---
version: 1
slug: "lib-oaks-web-live-home-live-ex"
primary_target: "lib/oaks_web/live/home_live.ex"
related_targets: []
---

# Home page

Mode: Read. The site's front door at `/` (OaksWeb.HomeLive): what the Compendium is, a way in by search or by contents, and one oak to start from. Item 1900 (Jeff, 2026-11-21: "so flat and boring; the entire thing needs a rethink. We need a more dynamic font and feel for the title, and the left justification is a really strange choice for a top-level page").

## Audience and job

Identifiers arriving cold (from iNat, a search engine, a link) and returning readers. They need to know at once what this is, find a name fast, or pick a part of the book to open. Researchers need to see the sources behind it.

## Content and order

1. The title page on ink: Oak *Compendium* and the subtitle "Oaks, their varieties and their hybrids, and how to tell them apart".
2. The big search, straddling the ink's ochre edge; it submits to /search?q=.
3. The counts on paper (species, hybrids, sections, sources), from the database.
4. Contents: an italic heading with the acorn beside it over a ruled two-column list of the site's parts, each with its count and one line; parts that don't exist yet say "In preparation".
5. An oak at random (a non-hybrid species, with "Show another"), its name in display type, where it sits, its hybrids with their other parents.
6. The sources, primary first.

No byline, no identification-count claim, no quoted Oak Compendium prose until it is in the database (no hand-picked or hard-coded quotes).

## Anti-goals

Not a SaaS landing page (no hero CTA pair, feature cards or stat tiles), not a left-aligned admin column, not a dashboard.

## Direction contract

THESIS: The home page is a book's title page: the name set large and centred on the masthead's ink, a contents page below it. It refuses the left-aligned column of links and the marketing hero with feature cards.

OWN-WORLD: Ink #161616 field continuing from the masthead, ending in a 6px ochre edge; paper #fbfbf7 below. "Oak" in paper roman, "Compendium" in ochre italic, Source Serif 4 at display size. Archivo frame, Archivo Narrow counts with square ink bullets. Ruled lists on a 2px ink rule and hairlines, square 2px-ink search field with an ochre Find.

STORY: The visitor reads what the Compendium is, types a name into the search or opens a part from the contents, and meets one real oak with its place in the taxonomy and its hybrids.

FIRST VIEWPORT: At 1440: masthead (60px), then about 290px of ink holding the centred title (88px) and the two-line subtitle (23px); the 640px search hangs across the ochre edge, half on ink and half on paper; the counts centred below on paper; the italic Contents heading with the acorn; the first row of the two-column contents list at the fold. The primary action is the search.

FORM: The Title Page, Bookplate iteration; seed:3d50e731d9a63102; locked by Jeff on the decision page, round db8687fb. Sketch: .impeccable/mocks/decision/home-c3.html (in the 6b12-site-shell worktree). Build path code-led. Signature interaction: the search pinned across the ink's edge like a bookplate, its focus ring in pencil across both grounds as the sketch has it.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
