# Infraspecific Rank Abbreviations

Research documentation for the species name parser. This document catalogs all infraspecific rank abbreviations that may appear in botanical nomenclature, based on ICN standards and patterns found in our Oak Compendium database.

## Database Analysis

Patterns found in `oak_compendium.db` synonyms field:

| Abbreviation | Count | Example |
|--------------|-------|---------|
| `var.` | 60 | `reticulata var. retifolia Liebm. 1869` |
| `f.` | 36 | `dumosa f. berberidifolia (Liebm.) Trel. 1924` |
| `subsp.` | 9 | `subsp. broteroana` |
| `F.` | 4 | (capitalized variant) |

The database contains 308 trinomial names stored as space-separated epithets (e.g., `agrifolia oxyadenia` rather than `agrifolia var. oxyadenia`).

## ICN-Official Ranks

These are the ranks recognized by the International Code of Nomenclature for algae, fungi, and plants (ICN). The parser MUST accept all of these.

### Principal Ranks (Common)

| Rank | Abbreviation | Full Word | Latin | Notes |
|------|--------------|-----------|-------|-------|
| Subspecies | `subsp.` | `subspecies` | - | ICN-recommended abbreviation |
| Variety | `var.` | `variety` | `varietas` | ICN-recommended abbreviation |
| Form | `f.` | `form` | `forma` | ICN-recommended abbreviation |

### Secondary Ranks (Less Common)

| Rank | Abbreviation | Full Word | Latin |
|------|--------------|-----------|-------|
| Subvariety | `subvar.` | `subvariety` | `subvarietas` |
| Subform | `subf.` | `subform` | `subforma` |

## Non-Standard Variants

These are commonly encountered but not officially recommended by the ICN.

| Input | Intended Rank | Notes |
|-------|---------------|-------|
| `ssp.` | Subspecies | Common but NOT ICN-recognized; more properly zoological |
| `sspp.` | Subspecies (plural) | Can be confused with `spp.` (species plural) |
| `varietas` | Variety | Latin form, sometimes seen in older literature |
| `forma` | Form | Latin form |

**Important**: The abbreviation `ssp.` is widely used but technically incorrect for botanical nomenclature. The ICN recommends `subsp.` exclusively. However, the parser should accept both since `ssp.` appears frequently in practice.

## Hybrid Infraspecific Ranks

When an infraspecific taxon is derived from a hybrid (nothospecies), the prefix "notho-" is added to the rank term.

| Abbreviation | Full Form | Example |
|--------------|-----------|---------|
| `nothosubsp.` | nothosubspecies | *Mentha ×piperita* nothosubsp. *piperita* |
| `nothovar.` | nothovariety | *Salix rubens* nothovar. *basfordiana* |
| `nothof.` | nothoforma | *Drosera anglica* nothof. *obovata* |

## Historical/Deprecated Ranks

These ranks are no longer recommended but may appear in historical literature and synonymies. The parser should recognize them for completeness.

| Abbreviation | Full Form | Notes |
|--------------|-----------|-------|
| `cv.` | cultivar | **Deprecated** since ~2004; use single quotes (e.g., 'Sunburst') |
| `prol.` | proles | Historical "race" rank; eliminated by IBC in 1905 |
| `proles` | proles | Full word form |
| `lusus` | lusus naturae | "Freak/mutant"; deprecated |
| `convar.` | convarietas | Cultivar group; deprecated |
| `stirps` | stirps | Historical race designation |
| `agamosp.` | agamospecies | Asexually reproducing species |
| `microf.` | microforma | Very rare |

## Parser Requirements

### Abbreviations to Accept

The parser should accept the following (case-insensitive):

```
# Standard ranks
subsp.    subspecies
ssp.      (non-standard but common)
var.      variety    varietas
subvar.   subvariety subvarietas
f.        form       forma
subf.     subform    subforma

# Hybrid ranks
nothosubsp.
nothovar.
nothof.

# Historical (for legacy parsing)
cv.
prol.     proles
lusus
convar.
stirps
agamosp.
microf.
```

### Regex Pattern

```regex
# Primary pattern for common ranks (case-insensitive)
(?i)\b(subsp|ssp|subspecies|var|varietas|variety|subvar|subvarietas|subvariety|f|forma|form|subf|subforma|subform)\.?\s+

# Hybrid ranks
(?i)\b(nothosubsp|nothovar|nothof)\.?\s+

# Historical/deprecated
(?i)\b(cv|prol|proles|lusus|convar|stirps|agamosp|microf)\.?\s+
```

### Edge Cases

1. **Case variation**: Accept `F.`, `f.`, `Var.`, `var.`, etc.

2. **Period optional**: Some sources omit the period (`var foo` vs `var. foo`)

3. **Spacing variation**: Handle both `var.foo` and `var. foo`

4. **Autonyms**: The infraspecific epithet matches the species epithet
   - Example: `Quercus agrifolia subsp. agrifolia`
   - These are automatically created when a species is divided

5. **Chained ranks**: The ICN does NOT allow compound names like `subsp. foo var. bar`. However, older literature may contain such constructions. The parser should:
   - Parse them if encountered
   - Flag them as potentially invalid
   - Use only the lowest rank for storage

6. **Hybrid indicators**: Names may include `×` before or within:
   - `× alba` (hybrid species)
   - `agrifolia × parvula` (hybrid formula)
   - `× piperita nothosubsp. piperita` (infraspecific hybrid)

## Name Structure

A complete infraspecific name follows this pattern:

```
[Genus] [species epithet] [rank indicator] [infraspecific epithet] [author]
```

Examples:
- `Quercus alba var. latiloba Michx.`
- `Quercus dumosa f. berberidifolia (Liebm.) Trel.`
- `Mentha × piperita nothosubsp. piperita`

The rank indicator is NOT italicized; only the genus, species, and infraspecific epithets are italicized.

## Storage Recommendations

Based on database analysis, our current approach stores trinomials as space-separated epithets without explicit rank indicators:

```
# Current storage
scientific_name: "agrifolia oxyadenia"

# Full name would be
# Quercus agrifolia var. oxyadenia
```

Consider whether to:
1. Keep current format (simpler, works for display)
2. Add explicit `infraspecific_rank` column
3. Store full trinomial with rank indicator

The iNaturalist source data does not include rank indicators, which is why our current format omits them.

## References

- [ICN Article 24 - Infraspecific Names](https://www.bgbm.org/iapt/nomenclature/code/SaintLouis/0028Ch3Sec5a024.htm)
- [Infraspecific name - Wikipedia](https://en.wikipedia.org/wiki/Infraspecific_name)
- [Plant Nomenclature Syntax - SCCSS](https://southcoastcss.org/plant-nomenclature-syntax/)
- [gnparser - BMC Bioinformatics](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/s12859-017-1663-3)
- [GBIF Name Parser](https://www.gbif.org/tool/HBJlXaP5qU2UWKcOESy0s/name-parser)
- [iNaturalist Forum - ssp. abbreviation](https://forum.inaturalist.org/t/subspecies-ssp-abbreviation-is-incorrect/65377)
