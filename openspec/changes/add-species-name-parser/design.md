# Design: Species Name Parser

## Context

Species name parsing is required for auto-linking in markdown content. The parser runs server-side at save time, storing resolved markdown links in content. This follows ICN (International Code of Nomenclature for algae, fungi, and plants) conventions.

### Name Forms (per ICN)

| Form | Example | ICN Reference |
|------|---------|---------------|
| Full | `Quercus alba` | Art. 23 |
| Abbreviated | `Q. alba`, `Q.alba` | Common convention |
| Hybrid | `Quercus ×bebbiana`, `Q. × alba` | Art. H.3 |
| Infraspecific | `Quercus alba subsp. latiloba` | Art. 24-27 |
| With author | `Quercus alba L.` | Art. 46-50 |

### Infraspecific Ranks

See [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md) for full research.

**Standard ICN ranks** (must accept):
| Abbreviation | Full Word | Notes |
|--------------|-----------|-------|
| `subsp.` | `subspecies` | ICN-recommended |
| `var.` | `variety`, `varietas` | ICN-recommended |
| `subvar.` | `subvariety`, `subvarietas` | |
| `f.` | `form`, `forma` | ICN-recommended |
| `subf.` | `subform`, `subforma` | |

**Non-standard variants** (accept for compatibility):
| Input | Notes |
|-------|-------|
| `ssp.` | Common but technically incorrect; zoological convention |
| `sspp.` | Subspecies plural |

**Hybrid infraspecific ranks** (nothotaxa):
| Abbreviation | Full Form |
|--------------|-----------|
| `nothosubsp.` | nothosubspecies |
| `nothovar.` | nothovariety |
| `nothof.` | nothoforma |

**Historical/deprecated** (accept for legacy parsing):
`cv.`, `prol.`, `proles`, `lusus`, `convar.`, `stirps`, `agamosp.`, `microf.`

**Edge cases**:
- Case-insensitive: accept `Var.`, `VAR.`, `var.`
- Period optional: accept `var foo` and `var. foo`
- Spacing optional: accept `var.foo` and `var. foo`
- Chained ranks: ICN disallows `subsp. foo var. bar` but parse if encountered, use lowest rank

### ICN Hybrid Notation (Art. H.3)

- Multiplication sign `×` (U+00D7) placed before epithet
- Lowercase `x` acceptable when `×` unavailable (Art. H.3A.2)
- Space after `×` is optional, based on readability
- `×` is not part of the name, just indicates hybrid nature

### ICN Author Citations (Art. 46-50)

| Pattern | Example | Meaning |
|---------|---------|---------|
| Single | `L.` | Linnaeus described it |
| Multiple | `Hook.f. et Thomson` | Joint authors |
| Parenthetical | `(L.) Pers.` | Linnaeus original, Persoon moved it |
| Ex | `Nutt. ex Seem.` | Nuttall proposed, Seemann published |
| In | `Clarke in Hook.f.` | Clarke published in Hooker's work |

### Stakeholders
- API server (primary: auto-linking at content save)
- CLI (future: validation, import parsing)

### Constraints
- Must be in Go for server-side use
- Reusable across API and CLI
- Minimal external dependencies (prefer stdlib or small focused libraries)

## Goals / Non-Goals

### Goals
- Parse all ICN-compliant oak species name forms
- Return structured data (genus, species, hybrid flag, infraspecific rank, author)
- Support scanning text for multiple species mentions with positions
- Enable link resolution: match parsed names against species database
- Maintainable, well-tested Go implementation

### Non-Goals
- Parsing non-oak genera (only `Quercus`/`Q.`)
- Full ICN compliance for all plant families
- Validating species existence (caller's responsibility)
- Handling OCR errors or typos
- Trade designations, marketing names (but accept historical `cv.` rank for legacy data)

## Decisions

### Decision: Implementation Approach

**Decision**: Use composable regex patterns with Go logic, not a single monolithic regex.

The grammar is regular (no recursion), so regex is appropriate. However, a single regex for the full grammar would be unmaintainable. Instead:

```go
// Build regex from named, testable components
var (
    genusPattern   = `(?:Quercus|Q\.)`
    hybridPattern  = `[×xX]`
    epithetPattern = `[a-z]+(?:-[a-z]+)?`
    rankPattern    = `(?i:subsp|ssp|var|varietas|variety|...)`  // case-insensitive
    // ... compose into full pattern
)
```

**Why not alternatives:**
- **Parser combinators**: Go's lack of good functional idioms (verbose closures, no ADTs, no pattern matching) makes them awkward
- **`participle` library**: Adds dependency for a grammar this simple
- **Hand-written scanner**: More code than necessary for a regular grammar

**Reference implementation**: [gnparser](https://github.com/gnames/gnparser) is a mature Go library for scientific name parsing. While we don't need its full generality (we only parse Quercus), its approach is worth studying.

**Recommendation**: Composable regex patterns. Each component (genus, epithet, rank, author patterns) should be separately defined and tested, then composed into the full grammar.

### Decision: Result Structure

```go
type ParseResult struct {
    Genus         string          // "Quercus" or "Q."
    Species       string          // The specific epithet
    IsHybrid      bool            // true if × or x present
    Infraspecific *Infraspecific  // nil if not present
    Author        string          // empty if not present
    Raw           string          // Original matched text
    Start         int             // Position in source text
    End           int             // End position
}

type Infraspecific struct {
    Rank    string  // "subsp.", "var.", "subvar.", "f.", "subf."
    Epithet string
}
```

### Decision: Preserve Original Text

The parser preserves the original text exactly as written:
- `Q.` stays as `Q.`, not normalized to `Quercus`
- `×` and `x` preserved as authored
- Original spacing preserved in `Raw` field

**Rationale**: Caller can normalize if needed. Preserving original enables accurate replacement in source text.

### Decision: Case Requirements

Enforce proper ICN formatting for genus and species, but be lenient with ranks:

- Genus: `Quercus` or `Q.` only (capital Q required, lowercase rejected)
- Species epithet: lowercase only (`alba`, not `Alba` or `ALBA`)
- Hybrid marker: `×`, `x`, `X` all recognized
- Infraspecific ranks: case-insensitive (`var.`, `VAR.`, `Var.` all accepted)

**Rationale**: Genus and species follow strict ICN conventions. Rank abbreviations vary more in practice and accepting case variations improves matching without false positives.

### Decision: Link Resolution API

```go
// Resolver checks if a species exists and returns its URL path
type Resolver interface {
    Resolve(species string) (path string, exists bool)
}

// LinkSpecies scans text, resolves species, returns text with markdown links
func LinkSpecies(text string, resolver Resolver) string
```

**Rationale**: Decouples parsing from database access. Resolver is injected, enabling testing and different backends.

**Implementation**: The `Resolver` interface is defined in `api/internal/parser/`. The database-backed implementation lives in `api/internal/db/resolver.go` to keep DB code together and the parser package dependency-free.

### Decision: Infraspecific Linking Behavior

Infraspecific names link to the parent species, but display the full matched text:

```
Input:  "Q. alba var. claudei is common"
Output: "[Q. alba var. claudei](/species/alba) is common"
         ^--- full match as link text   ^--- species-level path
```

The resolver receives the species epithet (`alba`), not the infraspecific epithet (`claudei`). The database tracks species, not varieties/subspecies as separate entities.

## Parser Grammar

The grammar is **regular** (in the formal language theory sense)—no recursion, just alternation, optional groups, and concatenation. This means regex can handle it, though a single monolithic regex would be hard to maintain.

Expressed in pseudo-BNF following ICN (see [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md) for rank details):

```
species_name   := genus space? hybrid_marker? space? epithet infraspecific? author?
genus          := "Quercus" | "Q."
hybrid_marker  := "×" | "x" | "X"
epithet        := [a-z]+ ("-" [a-z]+)?  // allows hyphenated epithets
infraspecific  := space rank "."? space? epithet
rank           := standard_rank | hybrid_rank | deprecated_rank
standard_rank  := "subsp" | "ssp" | "subspecies"
               |  "var" | "variety" | "varietas"
               |  "subvar" | "subvariety" | "subvarietas"
               |  "f" | "form" | "forma"
               |  "subf" | "subform" | "subforma"
hybrid_rank    := "nothosubsp" | "nothovar" | "nothof"
deprecated_rank := "cv" | "prol" | "proles" | "lusus" | "convar"
               |   "stirps" | "agamosp" | "microf"
author         := space author_pattern
space          := [ \t]+
```

Note: Genus is case-sensitive (`Quercus`/`Q.` only). Epithet must be lowercase. Rank matching is case-insensitive. Period after rank abbreviation is optional.

### Author Citation Patterns

Author citations are NOT recursive despite what some formal grammars suggest. In practice, botanical nomenclature uses a finite set of patterns with at most one level of parenthetical nesting:

| Pattern | Example | Structure |
|---------|---------|-----------|
| Single | `L.` | `name` |
| With filius | `Hook.f.` | `name + "f."` |
| Multiple | `Hook.f. et Thomson` | `name ("et"\|"&") name` |
| Parenthetical | `(L.) Pers.` | `"(" name ")" name` |
| With "ex" | `Nutt. ex Seem.` | `name "ex" name` |
| With "in" | `Clarke in Hook.f.` | `name "in" name` |
| Complex | `(Hook. & Arn.) A.Gray ex S.Watson` | `"(" name "&" name ")" name "ex" name` |

**Implementation approach**: Match these patterns with regex alternation, not recursion. Accept what we can parse; gracefully degrade on unrecognized formats (leave author portion as plain text).

### The `f.` Disambiguation Problem

The abbreviation `f.` has two meanings:
1. **Infraspecific rank**: `forma` (e.g., `Q. alba f. claudei`)
2. **Author suffix**: `filius` meaning "son" (e.g., `Q. alba Hook.f.`)

**Disambiguation rule**: Look at what follows `f.`
- If followed by **lowercase word** → infraspecific rank (`f. claudei`)
- If followed by **end of match, uppercase, or connector** → author suffix (`Hook.f.`, `Hook.f. et Thomson`)

```
Q. alba f. claudei     → f. is rank, claudei is infraspecific epithet
Q. alba Hook.f.        → f. is author suffix (Hooker's son)
Q. alba Hook.f. et Arn → f. is author suffix
```

This is solvable with regex lookahead or by checking the character/word following `f.` in code.

## Package Structure

```
api/internal/parser/
├── parser.go       # Core types (ParseResult, Infraspecific)
├── grammar.go      # Species name parsing logic
├── scanner.go      # Scan text for multiple matches, skip code/links
├── linker.go       # LinkSpecies with Resolver interface
├── parser_test.go  # Type and helper tests
├── grammar_test.go # Species name parsing tests
├── scanner_test.go # Scanning tests
└── linker_test.go  # Integration tests
```

## Risks / Trade-offs

### Risk: Ambiguous Matches
- **Risk**: "Q. Smith wrote about oaks" could match "Q. Smith"
- **Mitigation**: Require epithet to be lowercase; author patterns are uppercase-led. "Smith" starts with uppercase, so won't match epithet pattern.

### Risk: Author Citation Diversity
- **Risk**: Author citations vary enormously in format—abbreviation styles (L., Linn., Linnaeus), multi-part names (de Candolle, van den Heede), and complex combinations.
- **Mitigation**: Parse common patterns; gracefully degrade on unrecognized formats. False negatives (missing author) are acceptable since the species still gets linked. The author field is informational, not critical for linking.

### Risk: The `f.` Ambiguity
- **Risk**: `f.` means both "forma" (rank) and "filius" (author suffix for "son")
- **Mitigation**: Use lookahead—if followed by lowercase word, it's a rank; otherwise it's an author suffix. See "The `f.` Disambiguation Problem" section above.

### Risk: Greedy Matching in Prose
- **Risk**: Regex might match too much text. "Q. alba L. is common" could over-match.
- **Mitigation**: The lowercase epithet requirement provides a natural boundary. "is" won't match `[a-z]+` followed by author pattern because we're looking for specific author structures, not arbitrary words.

### Risk: False Positives
- **Risk**: Non-oak genera abbreviated as "Q." (rare but possible: Quillaja, Quincula)
- **Mitigation**: Context is oak database; false positives are acceptable edge cases. The resolver will fail to match them anyway.

## Open Questions

1. ~~Should we normalize `Q.` to `Quercus` in output?~~ No, preserve original.

2. ~~Should unresolved species become plain text or broken links?~~ Plain text (no link created).

3. ~~What is the complete list of infraspecific rank abbreviations?~~ **RESOLVED**
   - See [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md)
   - Accept all ICN standard ranks, non-standard variants (ssp.), hybrid ranks (nothovar.), and historical/deprecated ranks
   - Chained ranks: parse if encountered, use lowest rank

4. ~~Implementation approach~~ **RESOLVED** - Start with regex (see Decision: Implementation Approach above)

## References

- [Infraspecific Ranks Research](/cli/docs/infraspecific-ranks.md) - Database analysis and complete rank list
- [ICN Madrid Code](https://www.iapt-taxon.org/nomen/main.php)
- [Article H.3 - Hybrid Names](https://www.iapt-taxon.org/nomen/pages/main/art_h3.html)
- [Infraspecific Names](https://en.wikipedia.org/wiki/Infraspecific_name)
- [Author Citations](https://biologynotesonline.com/botanical-nomenclature-principles-rules-ranks-typification-author-citation-rejection/)
