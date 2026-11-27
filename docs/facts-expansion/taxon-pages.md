# Taxon pages

Phase 10 of the [Facts expansion](README.md). The public taxon pages from the prototypes, on real data. Needs Taxonomy, Traits and fact review, Authoring editor and the site shell.

## Done when

- Species, hybrid, variety and higher taxa pages all use one template on real data, following the prototype.
- Comparisons work at `?vs=`, the reader at `?read=`.
- Impeccable's finish review passes.

## Design input

`design/prototype/shumardii.html`, `compare.html`, `x-riparia.html`, `hypoleucoides.html`, `acutissima.html`, `shumardii-sources.html`; the taxon page brief in `.impeccable/surfaces/design-prototype-shumardii-html.md`; DESIGN.md. Large UI work: the full Impeccable process, including its finish review.

## Where it starts from

The [species photos plan](../species-photos-plan.md) rebuilt the species page as an intermediate step (`design/prototype/species-today.html`; its Phase 4 decisions and scope table), to be revisited when the facts model exists. What it left waiting is this phase's list: the write-up fragment and reader, the field marks table with other sources behind a disclosure, what sets it apart (ranked traits), look-alikes, agree/differs/unreviewed marks, the comparison at `?vs=`, accepted and misapplied name status, and the range map place. Where the intermediate page deviates from the prototype by Jeff's choice (source tabs, all text shown, two columns, the attribution rule), this phase decides afresh with Jeff. The library pieces it added (`photo_columns`, `source_tabs`, `ruled_rows`, `hybrid_rows`, `comma_list`, `not_covered_notice`, `cite_line`, the photo viewer) are available.

## Known so far

1. **Components first,** added to the library and reviewed in `/dev/components`:
   - The DESIGN.md devices not yet built: the derived-value line with its Archivo tag ("Lobes per side 3–4 · counts"), the 3px ochre differs underline on a comparison row, the key-difference star, kbd hints on action buttons, and the reversed ochre-on-ink label plate (ID tip).
   - The page parts `app.css` still repeats across pages: ruled rows (sources, articles, search, species list, merge refs), italic empty states (taxon, search, merge, comparison, species list) and option buttons (the comparison source picker, the articles tag filter). As components they shrink `app.css` toward nothing.
   - The fragment-and-reader component, built in heartwood's `heartwood_ui` package, which both apps depend on, and themed in oaks by an adapter block ([Architecture groundwork](architecture-groundwork.md#3-sharing-with-gallformers), Jeff, 2026-11-26). Gallformers solves the same problem for ID Notes (`gall_live.ex`): an excerpt with Read, a modal reader with A-/A+, Copy link, and a `?read=` deep link. That is its design source.
2. **Taxon page.** Prototype `shumardii`: breadcrumb and siblings menu, title, write-up fragment and reader, distinguishing traits, look-alikes, hybrids, field marks with sources behind, range list and map place, names, sources, cite.
3. **Comparison mode.** Prototype `compare`: `?vs=` on the taxon page, key-difference stars, the ID tip row.
4. **Hybrid and infraspecific pages.** Prototype `x-riparia`: a hybrid between its parents; variety pages under their species.
5. **Taxonomy browse, species list, sources pages,** on the new model.
6. **API ETag/Cache-Control plug.** `OaksWeb.Plugs.ApiCache`, cribbed from gallformers' `lib/gallformers_web/plugs/api_cache.ex`: MD5 of the body as the ETag, 304 on a matching If-None-Match, skipped for status 400 and above. Done when a repeat GET with the returned ETag gets a 304 (tested, and checked by hand with `curl -I`).

## Known bugs and ideas

- The IUCN status stamp has no source mark (IUCN 2024-2 with its assessment), though DESIGN.md's Status Tag and the prototype show one. Nothing stores the assessment's source yet; Taxonomy's editorial fields (conservation status with its source) supply it.
- Backlinks ("Referenced in") on taxon pages: the articles and taxa that reference this one, each with a type icon and title, hidden when there are none.

## To work out

- Which of the intermediate page's choices carry over to the full template.
