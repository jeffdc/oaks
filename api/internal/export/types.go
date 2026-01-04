// Package export provides types and functions for exporting the oak database.
package export

// Taxonomy represents the nested taxonomy in export format.
type Taxonomy struct {
	Genus      string  `json:"genus"`
	Subgenus   *string `json:"subgenus"`
	Section    *string `json:"section"`
	Subsection *string `json:"subsection,omitempty"`
	Complex    *string `json:"complex,omitempty"`
}

// ExternalLink represents an external reference link for a species.
type ExternalLink struct {
	Name string `json:"name"` // Display label (e.g., "Wikipedia", "USDA Plants")
	URL  string `json:"url"`  // Direct link to species on external site
	Logo string `json:"logo"` // Identifier for bundled SVG icon (e.g., "wikipedia", "inaturalist")
}

// SourceData represents source-attributed data for a species.
type SourceData struct {
	SourceID         int64    `json:"source_id"`
	SourceName       string   `json:"source_name"`
	SourceURL        *string  `json:"source_url,omitempty"`
	License          *string  `json:"license,omitempty"`
	LicenseURL       *string  `json:"license_url,omitempty"`
	IsPreferred      bool     `json:"is_preferred"`
	LocalNames       []string `json:"local_names,omitempty"`
	Range            *string  `json:"range,omitempty"`
	GrowthHabit      *string  `json:"growth_habit,omitempty"`
	Leaves           *string  `json:"leaves,omitempty"`
	Flowers          *string  `json:"flowers,omitempty"`
	Fruits           *string  `json:"fruits,omitempty"`
	Bark             *string  `json:"bark,omitempty"`
	Twigs            *string  `json:"twigs,omitempty"`
	Buds             *string  `json:"buds,omitempty"`
	HardinessHabitat *string  `json:"hardiness_habitat,omitempty"`
	Miscellaneous    *string  `json:"miscellaneous,omitempty"`
	URL              *string  `json:"url,omitempty"` // Source's page for this species
}

// Species represents a species in export format.
type Species struct {
	Name                string         `json:"name"`
	Author              *string        `json:"author,omitempty"`
	IsHybrid            bool           `json:"is_hybrid"`
	ConservationStatus  *string        `json:"conservation_status,omitempty"`
	Taxonomy            Taxonomy       `json:"taxonomy"`
	Parent1             *string        `json:"parent1,omitempty"`
	Parent2             *string        `json:"parent2,omitempty"`
	Hybrids             []string       `json:"hybrids,omitempty"`
	CloselyRelatedTo    []string       `json:"closely_related_to,omitempty"`
	SubspeciesVarieties []string       `json:"subspecies_varieties,omitempty"`
	Synonyms            []string       `json:"synonyms,omitempty"`
	ExternalLinks       []ExternalLink `json:"external_links,omitempty"`
	Sources             []SourceData   `json:"sources,omitempty"`
}

// Metadata contains version info for cache invalidation.
type Metadata struct {
	Version      string `json:"version"`        // Timestamp-based version for cache invalidation
	ExportedAt   string `json:"exported_at"`    // ISO 8601 timestamp
	SpeciesCount int    `json:"species_count"`  // Number of species in export
	TaxaCount    int    `json:"taxa_count"`     // Number of taxa in export
	ArticleCount int    `json:"article_count"`  // Number of articles in export
}

// TaxonLink represents an external reference link for a taxon.
type TaxonLink struct {
	Label string `json:"label"` // e.g., "iNaturalist", "Wikipedia"
	URL   string `json:"url"`
}

// Taxon represents a taxon in export format.
type Taxon struct {
	Name             string      `json:"name"`
	Level            string      `json:"level"` // subgenus, section, subsection, complex
	Parent           *string     `json:"parent,omitempty"`
	Author           *string     `json:"author,omitempty"`
	Content          *string     `json:"content,omitempty"`
	ContentUpdatedAt *string     `json:"content_updated_at,omitempty"`
	Links            []TaxonLink `json:"links,omitempty"`
	SpeciesCount     int         `json:"species_count"`
}

// Source represents full source metadata at top level.
type Source struct {
	ID          int64   `json:"id"`
	SourceType  string  `json:"source_type"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	Author      *string `json:"author,omitempty"`
	Year        *int    `json:"year,omitempty"`
	URL         *string `json:"url,omitempty"`
	ISBN        *string `json:"isbn,omitempty"`
	DOI         *string `json:"doi,omitempty"`
	Notes       *string `json:"notes,omitempty"`
	License     *string `json:"license,omitempty"`
	LicenseURL  *string `json:"license_url,omitempty"`
}

// Article represents a reference article in export format.
type Article struct {
	ID          int64    `json:"id"`
	Slug        string   `json:"slug"`
	Title       string   `json:"title"`
	Author      string   `json:"author"`
	Content     *string  `json:"content,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	CreatedAt   string   `json:"created_at"`
	UpdatedAt   string   `json:"updated_at"`
	PublishedAt *string  `json:"published_at,omitempty"`
}

// File represents the complete export format.
type File struct {
	Metadata Metadata  `json:"metadata"`
	Sources  []Source  `json:"sources"`
	Taxa     []Taxon   `json:"taxa"`
	Species  []Species `json:"species"`
	Articles []Article `json:"articles,omitempty"`
}
