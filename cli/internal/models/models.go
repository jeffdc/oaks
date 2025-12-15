package models

// TaxonLevel represents the hierarchical level of a taxon
type TaxonLevel string

const (
	TaxonLevelSubgenus    TaxonLevel = "subgenus"
	TaxonLevelSection     TaxonLevel = "section"
	TaxonLevelSubsection  TaxonLevel = "subsection"
	TaxonLevelComplex     TaxonLevel = "complex"
)

// Taxon represents a taxonomic rank in the reference table
// Hierarchy: Genus (Quercus) → Subgenus → Section → Subsection → Complex → Species
type Taxon struct {
	Name   string     `json:"name" yaml:"name"`
	Level  TaxonLevel `json:"level" yaml:"level"`
	Parent *string    `json:"parent,omitempty" yaml:"parent,omitempty"` // Parent taxon name
	Author *string    `json:"author,omitempty" yaml:"author,omitempty"` // Taxonomic authority
	Notes  *string    `json:"notes,omitempty" yaml:"notes,omitempty"`
}

// DataPoint represents a single data point attributed to a specific source
type DataPoint struct {
	Value      string  `json:"value" yaml:"value"`
	SourceID   string  `json:"source_id" yaml:"source_id"`
	PageNumber *string `json:"page_number,omitempty" yaml:"page_number,omitempty"`
}

// OakEntry represents an Oak taxonomic entry
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
	Hybrids           []string `json:"hybrids,omitempty" yaml:"hybrids,omitempty"`
	CloselyRelatedTo  []string `json:"closely_related_to,omitempty" yaml:"closely_related_to,omitempty"`
	SubspeciesVarieties []string `json:"subspecies_varieties,omitempty" yaml:"subspecies_varieties,omitempty"`

	// Source-attributed data (stored in data_points table)
	CommonNames []DataPoint `json:"common_names,omitempty" yaml:"common_names,omitempty"`
	LeafColor   []DataPoint `json:"leaf_color,omitempty" yaml:"leaf_color,omitempty"`
	BudShape    []DataPoint `json:"bud_shape,omitempty" yaml:"bud_shape,omitempty"`
	LeafShape   []DataPoint `json:"leaf_shape,omitempty" yaml:"leaf_shape,omitempty"`
	BarkTexture []DataPoint `json:"bark_texture,omitempty" yaml:"bark_texture,omitempty"`
	Habitat     []DataPoint `json:"habitat,omitempty" yaml:"habitat,omitempty"`
	NativeRange []DataPoint `json:"native_range,omitempty" yaml:"native_range,omitempty"`
	Height      []DataPoint `json:"height,omitempty" yaml:"height,omitempty"`
	Synonyms    []string    `json:"synonyms,omitempty" yaml:"synonyms,omitempty"`
}

// NewOakEntry creates a new empty OakEntry with the given scientific name
func NewOakEntry(scientificName string) *OakEntry {
	return &OakEntry{
		ScientificName:      scientificName,
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		CommonNames:         []DataPoint{},
		LeafColor:           []DataPoint{},
		BudShape:            []DataPoint{},
		LeafShape:           []DataPoint{},
		BarkTexture:         []DataPoint{},
		Habitat:             []DataPoint{},
		NativeRange:         []DataPoint{},
		Height:              []DataPoint{},
		Synonyms:            []string{},
	}
}

// Source represents a source reference
type Source struct {
	SourceID   string  `json:"source_id" yaml:"source_id"`
	SourceType string  `json:"source_type" yaml:"source_type"`
	Name       string  `json:"name" yaml:"name"`
	Author     *string `json:"author,omitempty" yaml:"author,omitempty"`
	Year       *int    `json:"year,omitempty" yaml:"year,omitempty"`
	URL        *string `json:"url,omitempty" yaml:"url,omitempty"`
	ISBN       *string `json:"isbn,omitempty" yaml:"isbn,omitempty"`
	DOI        *string `json:"doi,omitempty" yaml:"doi,omitempty"`
	Notes      *string `json:"notes,omitempty" yaml:"notes,omitempty"`
}

// NewSource creates a new Source with the given ID, type, and name
func NewSource(sourceID, sourceType, name string) *Source {
	return &Source{
		SourceID:   sourceID,
		SourceType: sourceType,
		Name:       name,
	}
}
