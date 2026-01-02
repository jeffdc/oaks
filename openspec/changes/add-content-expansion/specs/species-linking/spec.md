# species-linking Specification

## Purpose

Enables automatic bidirectional linking between markdown content (taxa pages, articles) and species pages, improving navigation and discoverability.

## Dependencies

**BLOCKED BY**: `species-name-parser` capability (bead `oaks-lqfj`) - Go implementation at `api/internal/parser/`

## Architecture

Auto-linking happens at **save time** on the API server, not at render time in the browser:
- When content is saved via API, the parser processes it
- Species mentions are converted to markdown links: `[Quercus alba](/species/alba)`
- Stored content contains resolved links
- Web app renders standard markdown without species detection

## ADDED Requirements

### Requirement: Species Auto-Linking

The API server SHALL automatically convert species name mentions to markdown links when content is saved.

#### Scenario: Full species name linked
- **WHEN** content containing "Quercus alba" is saved via API
- **AND** species "alba" exists in database
- **THEN** stored content contains `[Quercus alba](/species/alba)`

#### Scenario: Abbreviated species name linked
- **WHEN** content containing "Q. alba" or "Q.alba" is saved via API
- **AND** species "alba" exists in database
- **THEN** stored content contains `[Q. alba](/species/alba)` preserving original text

#### Scenario: Unknown species not linked
- **WHEN** content containing "Quercus unknownus" is saved via API
- **AND** species "unknownus" does not exist in database
- **THEN** text is stored as-is without link

#### Scenario: Species in code blocks not linked
- **WHEN** content contains species name inside markdown code block
- **THEN** text inside code block is not processed for linking

#### Scenario: Hybrid species linked
- **WHEN** content containing "Quercus ×bebbiana" is saved via API
- **AND** hybrid species "×bebbiana" exists in database
- **THEN** stored content contains link to species page

#### Scenario: Multiple species in paragraph
- **WHEN** content mentions "Quercus alba, Q. stellata, and Q. macrocarpa"
- **AND** all three species exist
- **THEN** each species name is individually linked in stored content

#### Scenario: Already linked species not double-linked
- **WHEN** content contains `[Quercus alba](/species/alba)` (already a link)
- **THEN** the existing link is preserved, not wrapped in another link

### Requirement: Species Backlinks

The API SHALL provide a backlinks endpoint, and the web application SHALL display backlinks on species pages.

#### Scenario: Get backlinks via API
- **WHEN** client sends `GET /api/v1/species/:name/backlinks`
- **THEN** server searches stored content for `/species/:name` pattern
- **AND** returns list of taxa and articles containing links to that species

#### Scenario: Species referenced in taxon content
- **WHEN** user views species "alba" page
- **AND** Section Quercus content contains link to alba
- **THEN** species page shows backlink to Section Quercus

#### Scenario: Species referenced in article
- **WHEN** user views species "alba" page
- **AND** article content contains link to alba
- **THEN** species page shows backlink to that article

#### Scenario: Species with no references
- **WHEN** user views species page
- **AND** no taxa content or articles link to that species
- **THEN** backlinks section is empty or hidden

#### Scenario: Backlinks show source type
- **WHEN** backlinks are displayed
- **THEN** each backlink indicates whether source is taxon or article

#### Scenario: Backlinks are clickable
- **WHEN** user clicks on a backlink
- **THEN** user navigates to the referencing content

### Requirement: Backlinks Position

Backlinks SHALL be displayed in a dedicated section on species pages, not interrupting the main species information.

#### Scenario: Backlinks section location
- **WHEN** species page is displayed
- **AND** species has backlinks
- **THEN** backlinks appear in a distinct section
- **AND** section is labeled (e.g., "Referenced In" or "See Also")

### Requirement: Link Appearance

Species links SHALL be visually consistent with other internal links.

#### Scenario: Link styling
- **WHEN** species link is rendered in content
- **THEN** link has same visual styling as other internal links
