# Tasks: Species Name Parser

## 1. Core Types and Setup

- [ ] 1.1 Create `api/internal/parser/parser.go` with core types (ParseResult, Infraspecific)
- [ ] 1.2 Define regex patterns for genus, hybrid marker, epithet (from research doc)
- [ ] 1.3 Define regex patterns for all rank variants (standard, hybrid, historical)
- [ ] 1.4 Write `parser_test.go` with unit tests for pattern matching

## 2. Species Grammar

See [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md) for rank research.

- [ ] 2.1 Create `api/internal/parser/grammar.go`
- [ ] 2.2 Implement genus matching (Quercus | Q., case-insensitive)
- [ ] 2.3 Implement hybrid marker matching (×, x, X with optional space)
- [ ] 2.4 Implement epithet matching (lowercase word, allow hyphens)
- [ ] 2.5 Implement rank matching with all variants:
  - Standard: subsp., ssp., var., varietas, variety, subvar., f., forma, form, subf.
  - Hybrid: nothosubsp., nothovar., nothof.
  - Historical: cv., prol., proles, lusus, convar., stirps, agamosp., microf.
  - Case-insensitive, period optional, spacing flexible
- [ ] 2.6 Implement infraspecific parsing (rank + epithet)
- [ ] 2.7 Implement author parsing (handle parenthetical, "f." suffix, et/ex/in connectors)
- [ ] 2.8 Compose full species name regex/parser
- [ ] 2.9 Export `ParseSpecies(text string) (*ParseResult, error)`
- [ ] 2.10 Write `grammar_test.go` with ICN-compliant test cases

## 3. Text Scanning

- [ ] 3.1 Create `api/internal/parser/scanner.go`
- [ ] 3.2 Implement `ScanSpecies(text string) []ParseResult`
- [ ] 3.3 Add code block detection (skip ``` and ` regions)
- [ ] 3.4 Add existing link detection (skip [...] regions)
- [ ] 3.5 Return matches with start/end positions
- [ ] 3.6 Write `scanner_test.go`

## 4. Link Resolution

- [ ] 4.1 Create `api/internal/parser/linker.go`
- [ ] 4.2 Define `Resolver` interface
- [ ] 4.3 Implement `LinkSpecies(text string, resolver Resolver) string`
- [ ] 4.4 Replace matched species with markdown links `[original](/species/name)`
- [ ] 4.5 Leave unresolved species as plain text
- [ ] 4.6 Write `linker_test.go` with mock resolver

## 5. Testing

- [ ] 5.1 Test full species names (Quercus alba)
- [ ] 5.2 Test abbreviated forms (Q. alba, Q.alba)
- [ ] 5.3 Test hybrid forms (×bebbiana, × alba, xalba)
- [ ] 5.4 Test standard infraspecific ranks (subsp., var., subvar., f., subf.)
- [ ] 5.5 Test non-standard variants (ssp., variety, forma)
- [ ] 5.6 Test hybrid infraspecific ranks (nothosubsp., nothovar., nothof.)
- [ ] 5.7 Test historical/deprecated ranks (cv., prol., lusus, etc.)
- [ ] 5.8 Test author citations (L., Hook.f., (L.) Pers., Nutt. ex Seem.)
- [ ] 5.9 Test scanning with multiple species in text
- [ ] 5.10 Test code block and link skipping
- [ ] 5.11 Test case insensitivity (genus, ranks)
- [ ] 5.12 Test hyphenated epithets (castello-paivae)
- [ ] 5.13 Test optional period after rank (var vs var.)
- [ ] 5.14 Test flexible spacing (var.foo vs var. foo)
- [ ] 5.15 Test infraspecific linking resolves to species page

## 6. Integration

- [ ] 6.1 Add parser package to API server imports
- [ ] 6.2 Create database-backed Resolver implementation in `api/internal/db/resolver.go`
- [ ] 6.3 Integrate with content save endpoints:
  - `PUT /api/v1/taxa/:level/:name` (taxa content updates)
  - `POST /api/v1/articles` (new articles)
  - `PUT /api/v1/articles/:slug` (article updates)
- [ ] 6.4 Update add-content-expansion design.md to reference this parser

## 7. Documentation

- [ ] 7.1 Add package doc comments
- [ ] 7.2 Document public API (ParseSpecies, ScanSpecies, LinkSpecies)
- [ ] 7.3 Add examples in test files
