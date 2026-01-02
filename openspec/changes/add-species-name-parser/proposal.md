# Change: Add Species Name Parser

## Status: WON'T DO

**Superseded by**: `add-wasm-species-linker` (2026-01-02)

**Reason**: Go's RE2 regex engine lacks lookahead, making the `f.` disambiguation (forma vs filius) awkward. The grammar is regular but the scanning/disambiguation logic becomes spaghetti. Rust's `nom` parser combinators provide cleaner implementation. Client-side linking (WASM in browser) also simplifies the API and enables code reuse across browser and iOS.

**Preserved for**: Reference material in `design.md` (ICN conventions, infraspecific ranks, author citation patterns) and `specs/` (parsing requirements/scenarios).

---

## Why

The `add-content-expansion` proposal requires automatic linking of species mentions in markdown content. Rather than fragile regex patterns, a proper parser following ICN (International Code of Nomenclature) rules provides correct, maintainable parsing. Server-side linking at save time means stored content contains resolved markdown links, simplifying the web app.

## What Changes

- **NEW** `species-name-parser` capability: A Go parsing library for recognizing oak species names in text
- Located at `api/internal/parser/` for use by API server and CLI (via embedded server)
- Follows ICN naming conventions for species, infraspecific taxa, hybrids, and author citations
- Returns structured parse results with genus, species, hybrid flag, infraspecific rank/epithet, and author
- Supports scanning text for multiple species mentions with position information
- Resolves species to markdown links at save time (not render time)

## Impact

- Affected specs: None existing (new capability)
- Affected code: `api/internal/parser/` (new package)
- Dependencies: `add-content-expansion` will use this parser for species auto-linking at save time
- Unblocks: `add-content-expansion/specs/species-linking/spec.md`

## References

- [ICN - International Code of Nomenclature](https://www.iapt-taxon.org/nomen/main.php)
- [Article H.3 - Hybrid notation](https://www.iapt-taxon.org/nomen/pages/main/art_h3.html)
