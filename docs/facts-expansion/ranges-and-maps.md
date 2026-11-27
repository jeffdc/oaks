# Ranges and maps

Phase 12 of the [Facts expansion](README.md). Range facts per place, then the map. Needs Taxonomy and the site shell.

## Done when

Taxa have sourced range facts per place and the taxon page draws a map from them.

## Decided

- Any source can supply range data (Jeff, 2026-11-21).
- The taxon page reserves the map place beside the range list (`design/prototype/shumardii.html`). The intermediate species page has no map place yet.

## Known so far

1. **Boundary data.** GeoJSON or TopoJSON for countries, states and provinces, and counties. Candidates: Natural Earth, GADM, geoBoundaries. Compare file size, licensing (it must allow use on a public site) and granularity. Done when a dataset (or combination) is chosen, with the reasons, and the region identifier scheme the range facts key on is written down here.
2. **Range facts per place.** Range facts (taxon, place, native or introduced) with sources, at whatever granularity is known, in the Facts context.
3. **Map component.** A reusable Leaflet or MapLibre component, in the component library, that highlights any set of regions, with efficient boundary loading and zoom and pan. Check the CSP in `lib/oaks_web/plugs/security_headers.ex` allows what the library needs.
4. **Map on the taxon page.** The map fills the reserved place beside the range list; hidden when the taxon has no range facts.

## To work out

- How today's range text (each source's `range` in `species_sources`) becomes range facts: agent proposals through the import, reviewed by Jeff like other facts, or left as text.
