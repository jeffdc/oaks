# species-name-parser Specification

## Purpose

Provides a Go parsing library for recognizing and extracting oak species names from text, following ICN (International Code of Nomenclature) conventions. Used for server-side auto-linking of species mentions in markdown content.

## ADDED Requirements

### Requirement: Parse Full Species Names

The parser SHALL recognize full oak species names in the format "Quercus {epithet}" per ICN Article 23.

#### Scenario: Standard full name
- **WHEN** text contains "Quercus alba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", IsHybrid: false }

#### Scenario: Hyphenated epithet
- **WHEN** text contains "Quercus castello-paivae"
- **THEN** parser returns { Species: "castello-paivae" }

### Requirement: Parse Abbreviated Species Names

The parser SHALL recognize abbreviated oak species names in the format "Q. {epithet}" or "Q.{epithet}".

#### Scenario: Abbreviated with space
- **WHEN** text contains "Q. alba"
- **THEN** parser returns { Genus: "Q.", Species: "alba" }

#### Scenario: Abbreviated without space
- **WHEN** text contains "Q.alba"
- **THEN** parser returns { Genus: "Q.", Species: "alba" }

### Requirement: Parse Hybrid Species Names

The parser SHALL recognize hybrid species names per ICN Article H.3, accepting both × (U+00D7) and lowercase x as hybrid markers.

#### Scenario: Hybrid with Unicode multiplication sign
- **WHEN** text contains "Quercus ×bebbiana"
- **THEN** parser returns { Species: "bebbiana", IsHybrid: true }

#### Scenario: Hybrid with lowercase x
- **WHEN** text contains "Quercus xbebbiana"
- **THEN** parser returns { Species: "bebbiana", IsHybrid: true }

#### Scenario: Hybrid with uppercase X
- **WHEN** text contains "Quercus Xbebbiana"
- **THEN** parser returns { Species: "bebbiana", IsHybrid: true }

#### Scenario: Hybrid with space after marker
- **WHEN** text contains "Quercus × bebbiana"
- **THEN** parser returns { Species: "bebbiana", IsHybrid: true }

#### Scenario: Abbreviated hybrid
- **WHEN** text contains "Q. ×alba"
- **THEN** parser returns { Genus: "Q.", Species: "alba", IsHybrid: true }

#### Scenario: Preserve original hybrid marker
- **WHEN** text contains "Q. xalba"
- **THEN** Raw field preserves "Q. xalba" (not normalized to ×)

### Requirement: Parse Infraspecific Taxa

The parser SHALL recognize infraspecific ranks per ICN Articles 24-27 and common variants. See [cli/docs/infraspecific-ranks.md](/cli/docs/infraspecific-ranks.md) for complete list.

**Acceptance Criterion**: The parser MUST accept ALL rank abbreviations listed in the "Parser Requirements" section of `cli/docs/infraspecific-ranks.md`, including standard ranks, hybrid ranks (notho-), and historical/deprecated ranks. Implementation tests must verify coverage of the complete list.

#### Scenario: Subspecies
- **WHEN** text contains "Quercus robur subsp. pedunculiflora"
- **THEN** parser returns { Genus: "Quercus", Species: "robur", Infraspecific: { Rank: "subsp.", Epithet: "pedunculiflora" } }

#### Scenario: Variety
- **WHEN** text contains "Quercus alba var. latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "var.", Epithet: "latiloba" } }

#### Scenario: Subvariety
- **WHEN** text contains "Quercus alba subvar. elongata"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "subvar.", Epithet: "elongata" } }

#### Scenario: Form
- **WHEN** text contains "Quercus robur f. fastigiata"
- **THEN** parser returns { Genus: "Quercus", Species: "robur", Infraspecific: { Rank: "f.", Epithet: "fastigiata" } }

#### Scenario: Subform
- **WHEN** text contains "Quercus robur subf. pendula"
- **THEN** parser returns { Genus: "Quercus", Species: "robur", Infraspecific: { Rank: "subf.", Epithet: "pendula" } }

#### Scenario: Abbreviated with infraspecific
- **WHEN** text contains "Q. alba var. latiloba"
- **THEN** parser returns { Genus: "Q.", Species: "alba", Infraspecific: { Rank: "var.", Epithet: "latiloba" } }

#### Scenario: Non-standard ssp accepted
- **WHEN** text contains "Quercus alba ssp. latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "ssp.", Epithet: "latiloba" } }
- **AND** rank is preserved as authored (not normalized to "subsp.")

#### Scenario: Full word rank accepted
- **WHEN** text contains "Quercus alba variety latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "variety", Epithet: "latiloba" } }

#### Scenario: Hybrid infraspecific rank (nothovariety)
- **WHEN** text contains "Quercus ×bebbiana nothovar. deamii"
- **THEN** parser returns { Genus: "Quercus", Species: "bebbiana", IsHybrid: true, Infraspecific: { Rank: "nothovar.", Epithet: "deamii" } }

#### Scenario: Historical rank accepted
- **WHEN** text contains "Quercus robur cv. Fastigiata"
- **THEN** parser returns { Genus: "Quercus", Species: "robur", Infraspecific: { Rank: "cv.", Epithet: "Fastigiata" } }

#### Scenario: Case insensitive rank
- **WHEN** text contains "Quercus alba VAR. latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "VAR.", Epithet: "latiloba" } }
- **AND** rank case is preserved as authored

#### Scenario: Rank without period
- **WHEN** text contains "Quercus alba var latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "var", Epithet: "latiloba" } }

#### Scenario: Rank without space after period
- **WHEN** text contains "Quercus alba var.latiloba"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: { Rank: "var.", Epithet: "latiloba" } }

#### Scenario: Autonym (infraspecific matches species)
- **WHEN** text contains "Quercus agrifolia subsp. agrifolia"
- **THEN** parser returns { Genus: "Quercus", Species: "agrifolia", Infraspecific: { Rank: "subsp.", Epithet: "agrifolia" } }
- **AND** autonyms are parsed like any other infraspecific name

#### Scenario: Chained ranks (legacy, non-ICN)
- **WHEN** text contains "Quercus robur subsp. robur var. pendula"
- **THEN** parser returns { Genus: "Quercus", Species: "robur", Infraspecific: { Rank: "var.", Epithet: "pendula" } }
- **AND** only the lowest (most specific) rank is captured
- **AND** Raw field contains full matched text including both ranks

### Requirement: Parse Author Citations

The parser SHALL recognize author citations per ICN Articles 46-50, including single authors, parenthetical authors, and connectors (et, ex, in).

#### Scenario: Simple author
- **WHEN** text contains "Quercus alba L."
- **THEN** parser returns { Author: "L." }

#### Scenario: Author with lowercase suffix
- **WHEN** text contains "Quercus rubra Michx."
- **THEN** parser returns { Author: "Michx." }

#### Scenario: Author with f. suffix
- **WHEN** text contains "Quercus glauca Hook.f."
- **THEN** parser returns { Author: "Hook.f." }

#### Scenario: Multiple authors with et
- **WHEN** text contains "Quercus acuta Hook.f. et Thomson"
- **THEN** parser returns { Author: "Hook.f. et Thomson" }

#### Scenario: Parenthetical author (basionym)
- **WHEN** text contains "Quercus petraea (Matt.) Liebl."
- **THEN** parser returns { Author: "(Matt.) Liebl." }

#### Scenario: Ex author
- **WHEN** text contains "Quercus prinoides Nutt. ex Seem."
- **THEN** parser returns { Author: "Nutt. ex Seem." }

#### Scenario: In author
- **WHEN** text contains "Quercus semiserrata Clarke in Hook.f."
- **THEN** parser returns { Author: "Clarke in Hook.f." }

#### Scenario: No author present
- **WHEN** text contains "Quercus alba"
- **THEN** parser returns { Author: "" }

#### Scenario: Author with infraspecific
- **WHEN** text contains "Quercus alba var. latiloba Michx."
- **THEN** parser returns { Infraspecific: { Rank: "var.", Epithet: "latiloba" }, Author: "Michx." }

### Requirement: Scan Text for Multiple Species

The parser SHALL scan a text block and return all species mentions with their byte positions.

#### Scenario: Multiple species in paragraph
- **WHEN** text is "Compare Quercus alba and Q. macrocarpa in the field."
- **THEN** ScanSpecies returns two matches with correct Start/End positions

#### Scenario: Return position information
- **WHEN** text is "The Quercus alba grows tall."
- **THEN** match includes Start: 4, End: 16 (byte positions)

#### Scenario: Empty text
- **WHEN** text is ""
- **THEN** ScanSpecies returns empty slice

#### Scenario: No species found
- **WHEN** text is "Oak trees are beautiful."
- **THEN** ScanSpecies returns empty slice

### Requirement: Punctuation Boundaries

The parser SHALL correctly handle punctuation at name boundaries, distinguishing structural periods (part of abbreviations) from sentence punctuation.

#### Scenario: Sentence-ending period excluded
- **WHEN** text is "I observed Q. alba."
- **THEN** parser matches "Q. alba" (excludes sentence-ending period)
- **AND** the period in "Q." is preserved as part of genus abbreviation

#### Scenario: Comma-separated species list
- **WHEN** text is "Q. alba, Q. rubra, and Q. macrocarpa"
- **THEN** parser matches three species: "Q. alba", "Q. rubra", "Q. macrocarpa"
- **AND** commas are excluded from matches

#### Scenario: Infraspecific with trailing punctuation
- **WHEN** text is "The variety Q. alba var. latiloba."
- **THEN** parser matches "Q. alba var. latiloba" (excludes sentence-ending period)
- **AND** the period in "var." is preserved as part of rank abbreviation

#### Scenario: Author citation with trailing punctuation
- **WHEN** text is "Described by Quercus alba L.!"
- **THEN** parser matches "Quercus alba L." (includes author period, excludes exclamation)

### Requirement: Skip Code Blocks

The parser SHALL NOT match species names within markdown code blocks.

#### Scenario: Inline code skipped
- **WHEN** text contains "Use `Quercus alba` as the species name"
- **THEN** ScanSpecies returns no matches

#### Scenario: Fenced code block skipped
- **WHEN** text contains "```\nQuercus alba\n```"
- **THEN** ScanSpecies returns no matches

#### Scenario: Species outside code matched
- **WHEN** text contains "Quercus alba is `the` common oak"
- **THEN** ScanSpecies returns one match for "Quercus alba"

### Requirement: Skip Existing Links

The parser SHALL NOT match species names that are already markdown links, including inline links, reference-style links, and image alt text.

#### Scenario: Inline link skipped
- **WHEN** text contains "[Quercus alba](/species/alba)"
- **THEN** ScanSpecies returns no matches

#### Scenario: Reference-style link skipped
- **WHEN** text contains "[Quercus alba][1]" and "[1]: /species/alba"
- **THEN** ScanSpecies returns no matches for the bracketed text

#### Scenario: Image alt text skipped
- **WHEN** text contains "![Quercus alba leaf](/images/alba.jpg)"
- **THEN** ScanSpecies returns no matches

#### Scenario: Unlinked species matched
- **WHEN** text contains "Quercus alba and [other link](/foo)"
- **THEN** ScanSpecies returns one match for "Quercus alba"

### Requirement: Skip URLs

The parser SHALL NOT match species names that appear within URLs.

#### Scenario: Species in URL path skipped
- **WHEN** text contains "See https://example.com/Quercus_alba for details"
- **THEN** ScanSpecies returns no matches

#### Scenario: Species in link target skipped
- **WHEN** text contains "[click here](/path/Quercus/alba)"
- **THEN** ScanSpecies returns no matches for text inside parentheses

#### Scenario: Species outside URL matched
- **WHEN** text contains "Quercus alba: https://example.com/info"
- **THEN** ScanSpecies returns one match for "Quercus alba"

### Requirement: Link Resolution

The parser SHALL provide a function to replace species mentions with markdown links using a resolver interface.

#### Scenario: Species resolved to link
- **WHEN** text contains "Quercus alba"
- **AND** resolver returns ("/species/alba", true) for "alba"
- **THEN** LinkSpecies returns "[Quercus alba](/species/alba)"

#### Scenario: Infraspecific resolved to species link
- **WHEN** text contains "Q. alba var. claudei"
- **AND** resolver returns ("/species/alba", true) for "alba"
- **THEN** LinkSpecies returns "[Q. alba var. claudei](/species/alba)"
- **AND** full infraspecific text is used as link text
- **AND** link target is the species page, not a variety page

#### Scenario: Unresolved species unchanged
- **WHEN** text contains "Quercus unknownus"
- **AND** resolver returns ("", false) for "unknownus"
- **THEN** LinkSpecies returns "Quercus unknownus" (unchanged)

#### Scenario: Multiple species resolved
- **WHEN** text contains "Quercus alba and Q. rubra"
- **AND** both species resolve
- **THEN** LinkSpecies returns "[Quercus alba](/species/alba) and [Q. rubra](/species/rubra)"

#### Scenario: Preserve surrounding text
- **WHEN** text contains "The mighty Quercus alba grows here."
- **AND** alba resolves
- **THEN** LinkSpecies returns "The mighty [Quercus alba](/species/alba) grows here."

### Requirement: Structured Parse Result

The parser SHALL return structured objects with consistent fields per ICN conventions.

#### Scenario: Complete parse result structure
- **WHEN** parsing "Quercus alba var. latiloba (L.) Pers."
- **THEN** result contains:
  - Genus: "Quercus"
  - Species: "alba"
  - IsHybrid: false
  - Infraspecific: { Rank: "var.", Epithet: "latiloba" }
  - Author: "(L.) Pers."
  - Raw: "Quercus alba var. latiloba (L.) Pers."
  - Start: (byte position)
  - End: (byte position)

#### Scenario: Minimal parse result
- **WHEN** parsing "Q. alba"
- **THEN** result contains:
  - Genus: "Q."
  - Species: "alba"
  - IsHybrid: false
  - Infraspecific: nil
  - Author: ""

### Requirement: Error Handling

The parser SHALL return explicit errors for invalid input and partial results for recoverable cases.

#### Scenario: No match returns nil without error
- **WHEN** `ParseSpecies("hello world")` is called
- **THEN** result is `nil` and error is `nil`
- **AND** caller can distinguish "no species found" from "parse error"

#### Scenario: Empty input returns nil without error
- **WHEN** `ParseSpecies("")` is called
- **THEN** result is `nil` and error is `nil`

#### Scenario: Improper case rejected
- **WHEN** `ParseSpecies("quercus alba")` is called (lowercase genus)
- **THEN** result is `nil` and error is `nil` (not a valid species name)

#### Scenario: Unrecognized author format returns partial result
- **WHEN** text contains "Quercus alba [weird author 2024]"
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Author: "" }
- **AND** error is `nil`
- **AND** unrecognized author text is excluded from match

#### Scenario: Malformed infraspecific returns partial result
- **WHEN** text contains "Quercus alba var."
- **THEN** parser returns { Genus: "Quercus", Species: "alba", Infraspecific: nil }
- **AND** incomplete infraspecific is excluded from match

#### Scenario: ScanSpecies never errors
- **WHEN** `ScanSpecies(anyText)` is called
- **THEN** function returns `[]ParseResult` (possibly empty), never an error
- **AND** malformed regions are silently skipped
