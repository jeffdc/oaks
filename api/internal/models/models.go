package models

// TaxonLevel represents the hierarchical level of a taxon
type TaxonLevel string

const (
	TaxonLevelSubgenus   TaxonLevel = "subgenus"
	TaxonLevelSection    TaxonLevel = "section"
	TaxonLevelSubsection TaxonLevel = "subsection"
	TaxonLevelComplex    TaxonLevel = "complex"
)

// TaxonLink represents a labeled external link for a taxon
type TaxonLink struct {
	Label string `json:"label" yaml:"label"` // e.g., "iNaturalist", "Wikipedia"
	URL   string `json:"url" yaml:"url"`
}

// ExternalLink represents an external reference link for a species
type ExternalLink struct {
	Name string `json:"name" yaml:"name"` // Display label (e.g., "Wikipedia", "USDA Plants")
	URL  string `json:"url" yaml:"url"`   // Direct link to species on external site
	Logo string `json:"logo" yaml:"logo"` // Identifier for bundled SVG icon (e.g., "wikipedia", "inaturalist")
}

// Taxon represents a taxonomic rank in the reference table
// Hierarchy: Genus (Quercus) -> Subgenus -> Section -> Subsection -> Complex -> Species
type Taxon struct {
	Name   string      `json:"name" yaml:"name"`
	Level  TaxonLevel  `json:"level" yaml:"level"`
	Parent *string     `json:"parent,omitempty" yaml:"parent,omitempty"` // Parent taxon name
	Author *string     `json:"author,omitempty" yaml:"author,omitempty"` // Taxonomic authority
	Notes  *string     `json:"notes,omitempty" yaml:"notes,omitempty"`
	Links  []TaxonLink `json:"links,omitempty" yaml:"links,omitempty"` // External reference links
}

// SpeciesSource represents source-attributed descriptive data for a species
// One row = everything source X says about species Y
type SpeciesSource struct {
	ID               int64    `json:"id" yaml:"id"`
	ScientificName   string   `json:"scientific_name" yaml:"scientific_name"`
	SourceID         int64    `json:"source_id" yaml:"source_id"`
	LocalNames       []string `json:"local_names,omitempty" yaml:"local_names,omitempty"`
	Range            *string  `json:"range,omitempty" yaml:"range,omitempty"`
	GrowthHabit      *string  `json:"growth_habit,omitempty" yaml:"growth_habit,omitempty"`
	Leaves           *string  `json:"leaves,omitempty" yaml:"leaves,omitempty"`
	Flowers          *string  `json:"flowers,omitempty" yaml:"flowers,omitempty"`
	Fruits           *string  `json:"fruits,omitempty" yaml:"fruits,omitempty"`
	Bark             *string  `json:"bark,omitempty" yaml:"bark,omitempty"`
	Twigs            *string  `json:"twigs,omitempty" yaml:"twigs,omitempty"`
	Buds             *string  `json:"buds,omitempty" yaml:"buds,omitempty"`
	HardinessHabitat *string  `json:"hardiness_habitat,omitempty" yaml:"hardiness_habitat,omitempty"`
	Miscellaneous    *string  `json:"miscellaneous,omitempty" yaml:"miscellaneous,omitempty"`
	URL              *string  `json:"url,omitempty" yaml:"url,omitempty"`
	IsPreferred      bool     `json:"is_preferred" yaml:"is_preferred"`
}

// OakEntry represents an Oak taxonomic entry (species-intrinsic data)
// Source-attributed descriptive data is stored separately in species_sources
type OakEntry struct {
	ScientificName     string  `json:"scientific_name" yaml:"scientific_name"`
	Author             *string `json:"author,omitempty" yaml:"author,omitempty"`
	IsHybrid           bool    `json:"is_hybrid" yaml:"is_hybrid"`
	ConservationStatus *string `json:"conservation_status,omitempty" yaml:"conservation_status,omitempty"`

	// Taxonomy (flat columns, validated against taxa reference table)
	Subgenus   *string `json:"subgenus,omitempty" yaml:"subgenus,omitempty"`
	Section    *string `json:"section,omitempty" yaml:"section,omitempty"`
	Subsection *string `json:"subsection,omitempty" yaml:"subsection,omitempty"`
	Complex    *string `json:"complex,omitempty" yaml:"complex,omitempty"`

	// Hybrid parents (only set if IsHybrid is true)
	Parent1 *string `json:"parent1,omitempty" yaml:"parent1,omitempty"`
	Parent2 *string `json:"parent2,omitempty" yaml:"parent2,omitempty"`

	// Related species
	Hybrids             []string `json:"hybrids,omitempty" yaml:"hybrids,omitempty"`
	CloselyRelatedTo    []string `json:"closely_related_to,omitempty" yaml:"closely_related_to,omitempty"`
	SubspeciesVarieties []string `json:"subspecies_varieties,omitempty" yaml:"subspecies_varieties,omitempty"`
	Synonyms            []string `json:"synonyms,omitempty" yaml:"synonyms,omitempty"`

	// External reference links
	ExternalLinks []ExternalLink `json:"external_links,omitempty" yaml:"external_links,omitempty"`
}

// NewOakEntry creates a new empty OakEntry with the given scientific name
func NewOakEntry(scientificName string) *OakEntry {
	return &OakEntry{
		ScientificName:      scientificName,
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []ExternalLink{},
	}
}

// NewSpeciesSource creates a new SpeciesSource for a species from a source
func NewSpeciesSource(scientificName string, sourceID int64) *SpeciesSource {
	return &SpeciesSource{
		ScientificName: scientificName,
		SourceID:       sourceID,
		LocalNames:     []string{},
		IsPreferred:    false,
	}
}

// Source represents a source reference
type Source struct {
	ID          int64   `json:"id" yaml:"id"`
	SourceType  string  `json:"source_type" yaml:"source_type"`
	Name        string  `json:"name" yaml:"name"`
	Description *string `json:"description,omitempty" yaml:"description,omitempty"`
	Author      *string `json:"author,omitempty" yaml:"author,omitempty"`
	Year        *int    `json:"year,omitempty" yaml:"year,omitempty"`
	URL         *string `json:"url,omitempty" yaml:"url,omitempty"`
	ISBN        *string `json:"isbn,omitempty" yaml:"isbn,omitempty"`
	DOI         *string `json:"doi,omitempty" yaml:"doi,omitempty"`
	Notes       *string `json:"notes,omitempty" yaml:"notes,omitempty"`
	License     *string `json:"license,omitempty" yaml:"license,omitempty"`
	LicenseURL  *string `json:"license_url,omitempty" yaml:"license_url,omitempty"`
}

// NewSource creates a new Source with the given type and name
func NewSource(sourceType, name string) *Source {
	return &Source{
		SourceType: sourceType,
		Name:       name,
	}
}
