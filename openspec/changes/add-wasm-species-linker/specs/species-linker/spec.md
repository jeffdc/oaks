# species-linker Specification

## Purpose

Provides a Rust/WASM parsing library for recognizing oak species names in text, with JavaScript integration for client-side linking at render time. The parser follows ICN (International Code of Nomenclature) conventions and runs entirely in the browser.

## ADDED Requirements

### Requirement: Parse Full Species Names

The parser SHALL recognize full oak species names in the format "Quercus {epithet}" per ICN Article 23.

#### Scenario: Standard full name
- **WHEN** text contains "Quercus alba"
- **THEN** parser returns { genus: "Quercus", species: "alba", isHybrid: false }

#### Scenario: Hyphenated epithet
- **WHEN** text contains "Quercus castello-paivae"
- **THEN** parser returns { species: "castello-paivae" }

### Requirement: Parse Abbreviated Species Names

The parser SHALL recognize abbreviated oak species names in the format "Q. {epithet}" or "Q.{epithet}".

#### Scenario: Abbreviated with space
- **WHEN** text contains "Q. alba"
- **THEN** parser returns { genus: "Q.", species: "alba" }

#### Scenario: Abbreviated without space
- **WHEN** text contains "Q.alba"
- **THEN** parser returns { genus: "Q.", species: "alba" }

### Requirement: Parse Hybrid Species Names

The parser SHALL recognize hybrid species names per ICN Article H.3, accepting × (U+00D7), lowercase x, and uppercase X as hybrid markers.

#### Scenario: Hybrid with Unicode multiplication sign
- **WHEN** text contains "Quercus ×bebbiana"
- **THEN** parser returns { species: "bebbiana", isHybrid: true }

#### Scenario: Hybrid with lowercase x
- **WHEN** text contains "Quercus xbebbiana"
- **THEN** parser returns { species: "bebbiana", isHybrid: true }

#### Scenario: Hybrid with uppercase X
- **WHEN** text contains "Quercus Xbebbiana"
- **THEN** parser returns { species: "bebbiana", isHybrid: true }

#### Scenario: Abbreviated hybrid
- **WHEN** text contains "Q. ×alba"
- **THEN** parser returns { genus: "Q.", species: "alba", isHybrid: true }

### Requirement: Parse Infraspecific Taxa

The parser SHALL recognize infraspecific ranks per ICN Articles 24-27 and common variants. See [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md) for complete list.

#### Scenario: Subspecies
- **WHEN** text contains "Quercus robur subsp. pedunculiflora"
- **THEN** parser returns { species: "robur", infraspecific: { rank: "subsp.", epithet: "pedunculiflora" } }

#### Scenario: Variety
- **WHEN** text contains "Quercus alba var. latiloba"
- **THEN** parser returns { species: "alba", infraspecific: { rank: "var.", epithet: "latiloba" } }

#### Scenario: Form (f. disambiguation)
- **WHEN** text contains "Quercus robur f. fastigiata"
- **THEN** parser returns { species: "robur", infraspecific: { rank: "f.", epithet: "fastigiata" } }
- **AND** parser correctly identifies f. as rank (not author suffix) because it precedes lowercase epithet

#### Scenario: Hybrid infraspecific rank
- **WHEN** text contains "Quercus ×bebbiana nothovar. deamii"
- **THEN** parser returns { species: "bebbiana", isHybrid: true, infraspecific: { rank: "nothovar.", epithet: "deamii" } }

### Requirement: Parse Author Citations

The parser SHALL recognize author citations per ICN Articles 46-50.

#### Scenario: Simple author
- **WHEN** text contains "Quercus alba L."
- **THEN** parser returns { author: "L." }

#### Scenario: Author with f. suffix (filius)
- **WHEN** text contains "Quercus glauca Hook.f."
- **THEN** parser returns { author: "Hook.f." }
- **AND** parser correctly identifies f. as author suffix (not rank) because it's not followed by lowercase epithet

#### Scenario: Parenthetical author
- **WHEN** text contains "Quercus petraea (Matt.) Liebl."
- **THEN** parser returns { author: "(Matt.) Liebl." }

#### Scenario: Ex author
- **WHEN** text contains "Quercus prinoides Nutt. ex Seem."
- **THEN** parser returns { author: "Nutt. ex Seem." }

### Requirement: Scan Text for Species Mentions

The parser SHALL scan text and return all species mentions with byte positions for replacement.

#### Scenario: Multiple species in paragraph
- **WHEN** text is "Compare Quercus alba and Q. macrocarpa in the field."
- **THEN** scanSpecies returns two matches with correct start/end positions

#### Scenario: Return position information
- **WHEN** text is "The Quercus alba grows tall."
- **THEN** match includes start: 4, end: 16 (byte positions)

### Requirement: Skip Code Blocks

The parser SHALL NOT match species names within markdown code blocks.

#### Scenario: Inline code skipped
- **WHEN** text contains "Use `Quercus alba` as the species name"
- **THEN** scanSpecies returns no matches

#### Scenario: Fenced code block skipped
- **WHEN** text contains "```\nQuercus alba\n```"
- **THEN** scanSpecies returns no matches

### Requirement: Skip Existing Links

The parser SHALL NOT match species names already in markdown links.

#### Scenario: Inline link skipped
- **WHEN** text contains "[Quercus alba](/species/alba)"
- **THEN** scanSpecies returns no matches

#### Scenario: Image alt text skipped
- **WHEN** text contains "![Quercus alba leaf](/images/alba.jpg)"
- **THEN** scanSpecies returns no matches

### Requirement: Skip URLs

The parser SHALL NOT match species names within URLs.

#### Scenario: Species in URL path skipped
- **WHEN** text contains "See https://example.com/Quercus_alba for details"
- **THEN** scanSpecies returns no matches

### Requirement: Client-Side Link Resolution

The JavaScript integration SHALL resolve species mentions against the local database and replace with markdown links.

#### Scenario: Species resolved to link
- **WHEN** text contains "Quercus alba"
- **AND** species exists in IndexedDB
- **THEN** linkSpecies returns "[Quercus alba](/species/alba)"

#### Scenario: Infraspecific resolved to species link
- **WHEN** text contains "Q. alba var. claudei"
- **AND** species "alba" exists in IndexedDB
- **THEN** linkSpecies returns "[Q. alba var. claudei](/species/alba)"
- **AND** full infraspecific text is used as link text
- **AND** link target is the species page

#### Scenario: Unresolved species unchanged
- **WHEN** text contains "Quercus unknownus"
- **AND** species does not exist in IndexedDB
- **THEN** linkSpecies returns "Quercus unknownus" (unchanged)

#### Scenario: Multiple species resolved
- **WHEN** text contains "Quercus alba and Q. rubra"
- **AND** both species exist in IndexedDB
- **THEN** linkSpecies returns "[Quercus alba](/species/alba) and [Q. rubra](/species/rubra)"

### Requirement: WASM Module Loading

The web app SHALL load the WASM parser module efficiently.

#### Scenario: Lazy loading
- **WHEN** page loads
- **THEN** WASM module is NOT loaded until content rendering is needed

#### Scenario: Single initialization
- **WHEN** multiple components need species linking
- **THEN** WASM module is loaded only once and shared

#### Scenario: Offline availability
- **WHEN** user is offline
- **AND** WASM module was previously cached
- **THEN** species linking works normally

### Requirement: Compact WASM Size

The WASM artifact SHALL be optimized for web delivery.

#### Scenario: Size limit
- **WHEN** WASM is built for release
- **THEN** gzipped artifact is less than 100KB

### Requirement: Structured Parse Result

The parser SHALL return structured objects with consistent fields.

#### Scenario: Complete parse result
- **WHEN** parsing "Quercus alba var. latiloba (L.) Pers."
- **THEN** result contains:
  - genus: "Quercus"
  - species: "alba"
  - isHybrid: false
  - infraspecific: { rank: "var.", epithet: "latiloba" }
  - author: "(L.) Pers."
  - raw: "Quercus alba var. latiloba (L.) Pers."
  - start: (byte position)
  - end: (byte position)

### Requirement: TypeScript Definitions

The WASM build SHALL generate TypeScript type definitions.

#### Scenario: Type definitions available
- **WHEN** WASM is built with wasm-pack
- **THEN** `.d.ts` files are generated for all exported functions
- **AND** TypeScript projects can import with full type safety
