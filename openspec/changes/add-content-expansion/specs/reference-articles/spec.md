# reference-articles Specification

## Purpose

Enables standalone markdown articles for guides, book reviews, identification essays, and other reference material not tied to specific taxa.

## ADDED Requirements

### Requirement: Article Storage

The system SHALL store standalone articles with metadata including title, author, publication date, tags, and markdown content.

#### Scenario: Article with all fields
- **WHEN** article is retrieved from database
- **THEN** response includes `slug` (unique URL identifier)
- **AND** response includes `title`
- **AND** response includes `author`
- **AND** response includes `published_at` (ISO 8601 date)
- **AND** response includes `updated_at` (ISO 8601 timestamp or null)
- **AND** response includes `tags` (array of strings)
- **AND** response includes `content` (markdown)
- **AND** response includes `is_published` (boolean)

### Requirement: Article CRUD via API

The API SHALL provide endpoints for creating, reading, updating, and deleting articles.

#### Scenario: List all published articles
- **WHEN** client sends `GET /api/v1/articles`
- **THEN** server returns all articles where `is_published` is true
- **AND** articles are sorted by `published_at` descending
- **AND** response includes pagination metadata

#### Scenario: List articles with pagination
- **WHEN** client sends `GET /api/v1/articles?limit=10&offset=20`
- **THEN** server returns at most 10 articles starting from offset 20

#### Scenario: List articles filtered by tag
- **WHEN** client sends `GET /api/v1/articles?tag=guides`
- **THEN** server returns only articles with "guides" in tags array

#### Scenario: List articles with tag and pagination
- **WHEN** client sends `GET /api/v1/articles?tag=guides&limit=5`
- **THEN** server returns at most 5 articles with "guides" tag

#### Scenario: Get article by slug
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists and is published
- **THEN** server returns 200 OK with article data

#### Scenario: Get unpublished article without auth
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists but `is_published` is false
- **AND** request has no valid Authorization header
- **THEN** server returns 404 Not Found

#### Scenario: Get unpublished article with auth
- **WHEN** client sends `GET /api/v1/articles/:slug`
- **AND** article exists but `is_published` is false
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK with article data

#### Scenario: Create article
- **WHEN** client sends `POST /api/v1/articles` with valid article data
- **AND** request has valid Authorization header
- **THEN** server returns 201 Created
- **AND** response contains created article with generated slug
- **AND** `published_at` defaults to current date if not provided

#### Scenario: Create article with duplicate slug
- **WHEN** client sends `POST /api/v1/articles`
- **AND** generated or provided slug already exists
- **THEN** server appends numeric suffix to make slug unique

#### Scenario: Update article
- **WHEN** client sends `PUT /api/v1/articles/:slug` with updated data
- **AND** article exists
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK
- **AND** `updated_at` is set to current timestamp

#### Scenario: Delete article
- **WHEN** client sends `DELETE /api/v1/articles/:slug`
- **AND** article exists
- **AND** request has valid Authorization header
- **THEN** server returns 200 OK
- **AND** article is removed from database

#### Scenario: Get non-existent article
- **WHEN** client sends `GET /api/v1/articles/nonexistent`
- **THEN** server returns 404 Not Found

#### Scenario: Create article without auth
- **WHEN** client sends `POST /api/v1/articles`
- **AND** request has no Authorization header
- **THEN** server returns 401 Unauthorized

### Requirement: Article Slug Generation

The system SHALL generate URL-friendly slugs from article titles. Slugs are immutable after creation.

#### Scenario: Slug from simple title
- **WHEN** article is created with title "How to Document an Oak"
- **THEN** slug is generated as "how-to-document-an-oak"

#### Scenario: Slug from title with special characters
- **WHEN** article is created with title "Q. alba vs Q. stellata: A Comparison"
- **THEN** slug is generated as "q-alba-vs-q-stellata-a-comparison"

#### Scenario: Explicit slug provided
- **WHEN** article is created with explicit `slug` field
- **THEN** provided slug is used instead of generated one

#### Scenario: Slug immutable on update
- **WHEN** article is updated with new title
- **THEN** slug remains unchanged
- **AND** URLs to the article continue to work

#### Scenario: Slug field ignored on update
- **WHEN** client sends PUT with different `slug` value
- **THEN** the slug change is ignored
- **AND** article retains original slug

### Requirement: Articles in Export

The system SHALL include articles in the JSON export format.

#### Scenario: Export includes articles
- **WHEN** user requests `/api/v1/export`
- **THEN** response includes `articles` array
- **AND** each article includes all metadata fields
- **AND** only published articles are included

### Requirement: Articles Section in Web App

The web application SHALL provide a dedicated articles section.

#### Scenario: Articles accessible from landing page
- **WHEN** user visits the landing page
- **THEN** articles section or link is prominently visible

#### Scenario: Articles accessible from navigation
- **WHEN** user views any page
- **THEN** navigation includes link to articles section

#### Scenario: View articles list
- **WHEN** user navigates to articles section
- **THEN** page displays list of published articles
- **AND** articles show title, date, and tags

#### Scenario: Filter articles by tag
- **WHEN** user clicks on a tag in the articles section
- **THEN** list filters to show only articles with that tag

#### Scenario: View single article
- **WHEN** user clicks on an article title
- **THEN** article content is displayed rendered as HTML from markdown
- **AND** article metadata (title, author, date) is shown

### Requirement: Article Authoring in Web App

The web application SHALL provide editing capabilities for authenticated users.

#### Scenario: View drafts when authenticated
- **WHEN** user is authenticated with API key
- **AND** user views articles list
- **THEN** draft articles (is_published=false) are shown
- **AND** drafts are visually distinguished from published articles

#### Scenario: Create new article
- **WHEN** user is authenticated
- **AND** user clicks "New Article" button
- **THEN** article editor is displayed
- **AND** article is created as draft by default

#### Scenario: Edit existing article
- **WHEN** user is authenticated
- **AND** user views an article
- **THEN** "Edit" button is available
- **AND** clicking opens article editor

#### Scenario: Article editor
- **WHEN** user is editing an article
- **THEN** editor shows fields for title, content (markdown), and tags
- **AND** content has markdown preview
- **AND** user can save changes

#### Scenario: Publish article
- **WHEN** user is editing a draft article
- **THEN** "Publish" button is available
- **AND** clicking sets is_published=true and saves

#### Scenario: Unpublish article
- **WHEN** user is editing a published article
- **THEN** "Unpublish" button is available
- **AND** clicking sets is_published=false and saves

### Requirement: Article Tags

The system SHALL support categorization of articles via string tags.

#### Scenario: Article with multiple tags
- **WHEN** article is created with tags ["guides", "identification"]
- **THEN** article appears in both tag filters

#### Scenario: List available tags
- **WHEN** client sends `GET /api/v1/articles/tags`
- **THEN** server returns array of all unique tags used across articles

### Requirement: Article Validation

The API SHALL validate article data on create and update.

#### Scenario: Title required
- **WHEN** client sends POST/PUT without title
- **THEN** server returns 400 Bad Request
- **AND** response indicates title is required

#### Scenario: Title max length
- **WHEN** client sends POST/PUT with title exceeding 200 characters
- **THEN** server returns 400 Bad Request
- **AND** response indicates title too long

#### Scenario: Content required
- **WHEN** client sends POST/PUT without content
- **THEN** server returns 400 Bad Request
- **AND** response indicates content is required

#### Scenario: Author defaults
- **WHEN** client sends POST without author field
- **THEN** author defaults to "Jeff Clark"

#### Scenario: Tags max count
- **WHEN** client sends POST/PUT with more than 10 tags
- **THEN** server returns 400 Bad Request
- **AND** response indicates too many tags

#### Scenario: Tag max length
- **WHEN** client sends POST/PUT with tag exceeding 50 characters
- **THEN** server returns 400 Bad Request
- **AND** response indicates tag too long
