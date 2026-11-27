# Taxonomy

Phase 6 of the [Facts expansion](README.md). Taxa, names, hybrids and varieties as a real tree linked to iNat. Needs Sources and facts core, because hybrid parentage is a sourced fact. Material and observations can run beside it. It builds on Architecture groundwork's keys: species and taxa linked by foreign key, not by name.

## Done when

- Every current species row is a taxon with names, loaded through the import endpoint after Jeff reads its dry-run report.
- Hybrids have sourced parentage.
- Varieties and subspecies are child taxa with a stored rank.
- Taxa carry iNat ids.
- Today's pages and API v1 tests pass through an adapter.

## Known so far

1. **Taxa, names and ancestry schema.** Ranks including subspecies, variety, nothospecies and formula hybrid; names with status (accepted, synonym, misapplied) and authorship, extending the `names` table Architecture groundwork makes for synonyms and common names; a closure table; the iNat id. Port gallformers' `Taxa.Ancestry`, tree validator and `NameNormalizer`.
2. **Hybrids and parentage.** Named and formula hybrids are taxa; parentage is a fact; an intersectional hybrid sits at the lowest rank both parents share.
3. **Migrate species into taxa.** An import Jeff checks from its dry-run report before it applies: parse names (×, formula, misspellings), infraspecific names to child taxa, autonyms, synonyms to names, `parent1`/`parent2` to parentage facts sourced to the Legacy data source (made in Sources and facts core). It fixes the stored-data bugs below as part of the move.
4. **iNat backbone sync.** Fetch Quercus taxonomy from the iNat API (the inaturalist-api skill), diff, and propose the changes as an import, dry-run first for Jeff; departures recorded with Jeff's basis note.
5. **Taxon editorial fields.** External links (editable in the UI) and conservation status with its source.
6. **Compatibility adapter.** Today's pages and API v1 read the new model; synonym redirects keep working.

## Stored-data bugs the move fixes

- Nine named hybrids have stored taxonomy that disagrees with their parents' (× *alvordiana*, × *autumnalis*, × *comptoniae*, × *harbisonii*, × *hillii*, × *hispanica*, × *introgressa*, × *kinseliae*, × *munzii*). For example × *comptoniae* is stored in sect. *Quercus* though *lyrata* and *virginiana* share only subg. *Quercus*, and × *alvordiana* carries a parent's complex (*dumosa*). Placement at the lowest shared rank settles them.
- Malformed synonyms: a citation stored as a name (`J. Arnold Arbor. 29(1): 40. 1948 palustris x phellos`), two names in one entry (`tauzin, tauza`), `lunglinge(x) nsis Hu`, and `acutissima subsp chenii (Nakai) A.Camus 1934` (subsp without its dot).
- Nine hybrids store several synonyms in one string joined by `=` (× *audleyensis*, *kinseliae*, *mellichampii*, *morehus*, *rolfsii*, *runcinata*, *sternbergii*, *subintegra*, *succulenta*), so the species page and search show them as one garbled name.
- About 300 infraspecific names (*acutissima kingii* and the like) are stored without their rank, so the species list can't print var. or subsp. The stored rank in step 1 answers it.

## To work out

- Require a parent for every non-root taxon, so no save or import can orphan a section, subsection or complex (it drops out of the tree and its page 404s). Today's `Taxon.changeset` doesn't, because the import path and some test fixtures create parentless sections. The taxon form's parent select should also keep a stored parent as an option, as the species form does.
- How the intermediate species page reads the new model: through the adapter, or moved onto it directly.
- How images, which belong to a species row today, move to taxa.
