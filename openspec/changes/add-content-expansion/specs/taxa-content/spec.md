# taxa-content Specification

## Purpose

Enables freeform markdown content to be attached to taxonomy levels (subgenus, section, subsection, complex), allowing curated descriptions of higher-level taxa characteristics.

## ADDED Requirements

### Requirement: Taxa Content Storage

The system SHALL store freeform markdown content for any taxon in the taxonomy hierarchy.

#### Scenario: Taxon with content
- **WHEN** user retrieves a taxon via API
- **AND** the taxon has content
- **THEN** response includes `content` field with markdown text
- **AND** response includes `content_updated_at` timestamp

#### Scenario: Taxon without content
- **WHEN** user retrieves a taxon via API
- **AND** the taxon has no content
- **THEN** response includes `content` as null or empty string
- **AND** `content_updated_at` is null

### Requirement: Taxa Content Update

The system SHALL allow updating taxon content via the existing taxa update endpoint.

#### Scenario: Add content to taxon
- **WHEN** user sends PUT to `/api/v1/taxa/:level/:name` with `content` field
- **THEN** content is stored for the taxon
- **AND** `content_updated_at` is set to current timestamp
- **AND** server returns 200 OK

#### Scenario: Update existing content
- **WHEN** user sends PUT to `/api/v1/taxa/:level/:name` with new `content`
- **AND** taxon already has content
- **THEN** content is replaced
- **AND** `content_updated_at` is updated

#### Scenario: Clear content
- **WHEN** user sends PUT with `content` as empty string or null
- **THEN** content is cleared from taxon
- **AND** `content_updated_at` is set to current timestamp

### Requirement: Taxa Content in Export

The system SHALL include taxa content in the JSON export format.

#### Scenario: Export includes taxa content
- **WHEN** user requests `/api/v1/export`
- **THEN** each taxon in the `taxa` array includes `content` field
- **AND** each taxon includes `content_updated_at` field

### Requirement: Taxa Content Display

The web application SHALL render taxon content as formatted markdown on taxon pages.

#### Scenario: View taxon with content
- **WHEN** user navigates to a taxon page (e.g., Section Quercus)
- **AND** taxon has content
- **THEN** content is displayed rendered as HTML from markdown

#### Scenario: View taxon without content
- **WHEN** user navigates to a taxon page
- **AND** taxon has no content
- **THEN** page displays normally without content section
- **AND** no error occurs

### Requirement: Taxa Content Editing

The web application SHALL provide editing capabilities for taxon content for authenticated users.

#### Scenario: Edit taxon content
- **WHEN** user is authenticated with API key
- **AND** user views a taxon page
- **THEN** "Edit Content" button is available
- **AND** clicking opens content editor

#### Scenario: Taxon content editor
- **WHEN** user is editing taxon content
- **THEN** editor shows markdown textarea
- **AND** content has markdown preview
- **AND** user can save changes

#### Scenario: Add content to taxon without content
- **WHEN** user is authenticated
- **AND** user views a taxon page without content
- **THEN** "Add Content" button is available
- **AND** clicking opens content editor

### Requirement: Taxa Content Scope

Taxa content SHALL NOT inherit or cascade to child taxa or species.

#### Scenario: Child taxon has no inherited content
- **WHEN** parent Section Quercus has content
- **AND** child Subsection Alba has no content
- **THEN** Subsection Alba page shows no content
- **AND** parent content is not displayed

#### Scenario: Species has no inherited content
- **WHEN** Section Quercus has content
- **AND** species Quercus alba belongs to Section Quercus
- **THEN** species alba page does not display Section content
