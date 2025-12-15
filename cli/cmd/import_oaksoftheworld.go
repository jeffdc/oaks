package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
)

// ScraperSynonym handles both string and object formats for synonyms
type ScraperSynonym struct {
	Name   string `json:"name"`
	Author string `json:"author"`
}

func (s *ScraperSynonym) UnmarshalJSON(data []byte) error {
	// Try string first
	var str string
	if err := json.Unmarshal(data, &str); err == nil {
		s.Name = str
		return nil
	}
	// Try object
	type synObj struct {
		Name   string `json:"name"`
		Author string `json:"author"`
	}
	var obj synObj
	if err := json.Unmarshal(data, &obj); err != nil {
		return err
	}
	s.Name = obj.Name
	s.Author = obj.Author
	return nil
}

// ScraperTaxonomy represents taxonomy from the scraper
type ScraperTaxonomy struct {
	Subgenus   string `json:"subgenus"`
	Section    string `json:"section"`
	Subsection string `json:"subsection"`
	Complex    string `json:"complex"`
}

// ScraperSpecies represents a species from the scraper output
type ScraperSpecies struct {
	Name                string           `json:"name"`
	IsHybrid            bool             `json:"is_hybrid"`
	Author              string           `json:"author"`
	Synonyms            []ScraperSynonym `json:"synonyms"`
	LocalNames          []string         `json:"local_names"`
	Range               string           `json:"range"`
	GrowthHabit         string           `json:"growth_habit"`
	Leaves              string           `json:"leaves"`
	Flowers             string           `json:"flowers"`
	Fruits              string           `json:"fruits"`
	BarkTwigsBuds       string           `json:"bark_twigs_buds"`
	HardinessHabitat    string           `json:"hardiness_habitat"`
	Miscellaneous       string           `json:"miscellaneous"`
	SubspeciesVarieties []string         `json:"subspecies_varieties"`
	Taxonomy            ScraperTaxonomy  `json:"taxonomy"`
	ConservationStatus  string           `json:"conservation_status"`
	Hybrids             []string         `json:"hybrids"`
	CloselyRelatedTo    []string         `json:"closely_related_to"`
	URL                 string           `json:"url"`
	ParentFormula       string           `json:"parent_formula"`
	Parent1             string           `json:"parent1"`
	Parent2             string           `json:"parent2"`
}

// ScraperData represents the full scraper output
type ScraperData struct {
	Species []ScraperSpecies `json:"species"`
}

var oaksSourceID int64

var importOaksCmd = &cobra.Command{
	Use:   "import-oaksoftheworld <json-file>",
	Short: "Import data from oaksoftheworld scraper",
	Long: `Import oak species data from the oaksoftheworld.fr scraper output.

This command reads the quercus_data.json file produced by the scraper
and imports all species data into the database, attributing it to the
specified source.

Data is split between:
- oak_entries: species-intrinsic data (taxonomy, conservation status, etc.)
- species_sources: source-attributed descriptive data (leaves, range, etc.)

Examples:
  oak import-oaksoftheworld ../quercus_data.json --source-id 2`,
	Args: cobra.ExactArgs(1),
	RunE: runImportOaks,
}

func init() {
	importOaksCmd.Flags().Int64Var(&oaksSourceID, "source-id", 0, "Source ID to attribute the data to (required)")
	importOaksCmd.MarkFlagRequired("source-id")
	rootCmd.AddCommand(importOaksCmd)
}

func runImportOaks(cmd *cobra.Command, args []string) error {
	filePath := args[0]

	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	// Verify source exists
	source, err := database.GetSource(oaksSourceID)
	if err != nil {
		return err
	}
	if source == nil {
		return fmt.Errorf("source with ID %d not found", oaksSourceID)
	}

	// Read JSON file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var scraperData ScraperData
	if err := json.Unmarshal(data, &scraperData); err != nil {
		return fmt.Errorf("failed to parse JSON: %w", err)
	}

	fmt.Printf("Found %d species to import from %s\n", len(scraperData.Species), source.Name)
	fmt.Printf("Source ID: %d\n\n", oaksSourceID)

	entriesImported := 0
	entriesUpdated := 0
	sourcesImported := 0
	errors := 0

	for _, sp := range scraperData.Species {
		// Convert to OakEntry (species-intrinsic data)
		entry := convertToOakEntry(&sp)

		// Check if entry exists
		existing, err := database.GetOakEntry(entry.ScientificName)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error checking %s: %v\n", entry.ScientificName, err)
			errors++
			continue
		}

		if existing != nil {
			// Merge with existing entry
			mergeOaksEntry(existing, entry)
			if err := database.SaveOakEntry(existing); err != nil {
				fmt.Fprintf(os.Stderr, "Error updating %s: %v\n", entry.ScientificName, err)
				errors++
				continue
			}
			entriesUpdated++
		} else {
			if err := database.SaveOakEntry(entry); err != nil {
				fmt.Fprintf(os.Stderr, "Error inserting %s: %v\n", entry.ScientificName, err)
				errors++
				continue
			}
			entriesImported++
		}

		// Convert to SpeciesSource (source-attributed data)
		speciesSource := convertToSpeciesSource(&sp, oaksSourceID)
		if err := database.SaveSpeciesSource(speciesSource); err != nil {
			fmt.Fprintf(os.Stderr, "Error saving species source for %s: %v\n", entry.ScientificName, err)
			errors++
			continue
		}
		sourcesImported++
	}

	fmt.Printf("\nImport complete:\n")
	fmt.Printf("  New entries:      %d\n", entriesImported)
	fmt.Printf("  Updated entries:  %d\n", entriesUpdated)
	fmt.Printf("  Species sources:  %d\n", sourcesImported)
	fmt.Printf("  Errors:           %d\n", errors)

	return nil
}

func convertToOakEntry(sp *ScraperSpecies) *models.OakEntry {
	entry := &models.OakEntry{
		ScientificName:      sp.Name,
		IsHybrid:            sp.IsHybrid,
		Hybrids:             sp.Hybrids,
		CloselyRelatedTo:    sp.CloselyRelatedTo,
		SubspeciesVarieties: sp.SubspeciesVarieties,
		Synonyms:            []string{},
	}

	// Ensure slices are not nil
	if entry.Hybrids == nil {
		entry.Hybrids = []string{}
	}
	if entry.CloselyRelatedTo == nil {
		entry.CloselyRelatedTo = []string{}
	}
	if entry.SubspeciesVarieties == nil {
		entry.SubspeciesVarieties = []string{}
	}

	// Author
	if sp.Author != "" {
		entry.Author = &sp.Author
	}

	// Conservation status
	if sp.ConservationStatus != "" {
		entry.ConservationStatus = &sp.ConservationStatus
	}

	// Taxonomy
	if sp.Taxonomy.Subgenus != "" {
		entry.Subgenus = &sp.Taxonomy.Subgenus
	}
	if sp.Taxonomy.Section != "" {
		entry.Section = &sp.Taxonomy.Section
	}
	if sp.Taxonomy.Subsection != "" {
		entry.Subsection = &sp.Taxonomy.Subsection
	}
	if sp.Taxonomy.Complex != "" {
		entry.Complex = &sp.Taxonomy.Complex
	}

	// Hybrid parents
	if sp.Parent1 != "" {
		p1 := cleanParentName(sp.Parent1)
		entry.Parent1 = &p1
	}
	if sp.Parent2 != "" {
		p2 := cleanParentName(sp.Parent2)
		entry.Parent2 = &p2
	}

	// Synonyms - convert to string format
	for _, syn := range sp.Synonyms {
		synStr := syn.Name
		if syn.Author != "" {
			synStr += " " + syn.Author
		}
		entry.Synonyms = append(entry.Synonyms, synStr)
	}

	return entry
}

func convertToSpeciesSource(sp *ScraperSpecies, srcID int64) *models.SpeciesSource {
	ss := &models.SpeciesSource{
		ScientificName: sp.Name,
		SourceID:       srcID,
		LocalNames:     sp.LocalNames,
		IsPreferred:    true, // First source imported is preferred
	}

	// Ensure LocalNames is not nil
	if ss.LocalNames == nil {
		ss.LocalNames = []string{}
	}

	// Set text fields (clean whitespace)
	if sp.Range != "" {
		cleaned := cleanText(sp.Range)
		ss.Range = &cleaned
	}
	if sp.GrowthHabit != "" {
		cleaned := cleanText(sp.GrowthHabit)
		ss.GrowthHabit = &cleaned
	}
	if sp.Leaves != "" {
		cleaned := cleanText(sp.Leaves)
		ss.Leaves = &cleaned
	}
	if sp.Flowers != "" {
		cleaned := cleanText(sp.Flowers)
		ss.Flowers = &cleaned
	}
	if sp.Fruits != "" {
		cleaned := cleanText(sp.Fruits)
		ss.Fruits = &cleaned
	}
	if sp.BarkTwigsBuds != "" {
		cleaned := cleanText(sp.BarkTwigsBuds)
		ss.BarkTwigsBuds = &cleaned
	}
	if sp.HardinessHabitat != "" {
		cleaned := cleanText(sp.HardinessHabitat)
		ss.HardinessHabitat = &cleaned
	}
	if sp.Miscellaneous != "" {
		cleaned := cleanText(sp.Miscellaneous)
		ss.Miscellaneous = &cleaned
	}
	if sp.URL != "" {
		ss.URL = &sp.URL
	}

	return ss
}

func mergeOaksEntry(existing, new *models.OakEntry) {
	// Update fields that were empty
	if existing.Author == nil && new.Author != nil {
		existing.Author = new.Author
	}
	if existing.ConservationStatus == nil && new.ConservationStatus != nil {
		existing.ConservationStatus = new.ConservationStatus
	}
	if existing.Subgenus == nil && new.Subgenus != nil {
		existing.Subgenus = new.Subgenus
	}
	if existing.Section == nil && new.Section != nil {
		existing.Section = new.Section
	}
	if existing.Subsection == nil && new.Subsection != nil {
		existing.Subsection = new.Subsection
	}
	if existing.Complex == nil && new.Complex != nil {
		existing.Complex = new.Complex
	}
	if existing.Parent1 == nil && new.Parent1 != nil {
		existing.Parent1 = new.Parent1
	}
	if existing.Parent2 == nil && new.Parent2 != nil {
		existing.Parent2 = new.Parent2
	}

	// Merge arrays (add new items not already present)
	existing.Synonyms = mergeStringSlice(existing.Synonyms, new.Synonyms)
	existing.Hybrids = mergeStringSlice(existing.Hybrids, new.Hybrids)
	existing.CloselyRelatedTo = mergeStringSlice(existing.CloselyRelatedTo, new.CloselyRelatedTo)
	existing.SubspeciesVarieties = mergeStringSlice(existing.SubspeciesVarieties, new.SubspeciesVarieties)
}

func mergeStringSlice(existing, new []string) []string {
	seen := make(map[string]bool)
	for _, s := range existing {
		seen[s] = true
	}
	for _, s := range new {
		if !seen[s] {
			existing = append(existing, s)
			seen[s] = true
		}
	}
	return existing
}

func cleanParentName(name string) string {
	// Remove "Quercus " prefix if present
	name = strings.TrimPrefix(name, "Quercus ")
	name = strings.TrimPrefix(name, "Q. ")
	return strings.TrimSpace(name)
}

func cleanText(s string) string {
	// Clean up whitespace from scraper output
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "\t", " ")
	// Collapse multiple spaces
	for strings.Contains(s, "  ") {
		s = strings.ReplaceAll(s, "  ", " ")
	}
	return strings.TrimSpace(s)
}
