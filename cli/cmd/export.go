package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
)

// ExportTaxonomy represents the nested taxonomy in export format
type ExportTaxonomy struct {
	Genus      string  `json:"genus"`
	Subgenus   *string `json:"subgenus"`
	Section    *string `json:"section"`
	Subsection *string `json:"subsection,omitempty"`
	Complex    *string `json:"complex,omitempty"`
}

// ExportSourceData represents source-attributed data for a species
type ExportSourceData struct {
	SourceID         int64    `json:"source_id"`
	SourceName       string   `json:"source_name"`
	SourceURL        *string  `json:"source_url,omitempty"`
	IsPreferred      bool     `json:"is_preferred"`
	LocalNames       []string `json:"local_names,omitempty"`
	Range            *string  `json:"range,omitempty"`
	GrowthHabit      *string  `json:"growth_habit,omitempty"`
	Leaves           *string  `json:"leaves,omitempty"`
	Flowers          *string  `json:"flowers,omitempty"`
	Fruits           *string  `json:"fruits,omitempty"`
	BarkTwigsBuds    *string  `json:"bark_twigs_buds,omitempty"`
	HardinessHabitat *string  `json:"hardiness_habitat,omitempty"`
	Miscellaneous    *string  `json:"miscellaneous,omitempty"`
	URL              *string  `json:"url,omitempty"` // Source's page for this species
}

// ExportSpecies represents a species in export format
type ExportSpecies struct {
	Name                string             `json:"name"`
	Author              *string            `json:"author,omitempty"`
	IsHybrid            bool               `json:"is_hybrid"`
	ConservationStatus  *string            `json:"conservation_status,omitempty"`
	Taxonomy            ExportTaxonomy     `json:"taxonomy"`
	Parent1             *string            `json:"parent1,omitempty"`
	Parent2             *string            `json:"parent2,omitempty"`
	Hybrids             []string           `json:"hybrids,omitempty"`
	CloselyRelatedTo    []string           `json:"closely_related_to,omitempty"`
	SubspeciesVarieties []string           `json:"subspecies_varieties,omitempty"`
	Synonyms            []string           `json:"synonyms,omitempty"`
	Sources             []ExportSourceData `json:"sources,omitempty"`
}

// ExportFile represents the complete export format
type ExportFile struct {
	Species []ExportSpecies `json:"species"`
}

var exportCmd = &cobra.Command{
	Use:   "export [output-file]",
	Short: "Export database to JSON",
	Long: `Export the oak database to JSON format for web app consumption.

The output follows the denormalized format documented in CLAUDE.md,
with taxonomy embedded in each species and data grouped by source.

If no output file is specified, writes to stdout.

Examples:
  oak export                      # Output to stdout
  oak export quercus_data.json    # Output to file
  oak export -o data.json         # Output to file using flag`,
	Args: cobra.MaximumNArgs(1),
	RunE: runExport,
}

var exportOutput string

func init() {
	rootCmd.AddCommand(exportCmd)
	exportCmd.Flags().StringVarP(&exportOutput, "output", "o", "", "Output file path")
}

func runExport(cmd *cobra.Command, args []string) error {
	database, err := getDB()
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Determine output path
	outputPath := exportOutput
	if len(args) > 0 {
		outputPath = args[0]
	}

	// Get all oak entries
	entries, err := database.ListOakEntries()
	if err != nil {
		return fmt.Errorf("failed to list oak entries: %w", err)
	}

	// Get all sources for lookup
	sources, err := database.ListSources()
	if err != nil {
		return fmt.Errorf("failed to list sources: %w", err)
	}
	sourceMap := make(map[int64]*models.Source)
	for _, s := range sources {
		sourceMap[s.ID] = s
	}

	// Build export data
	exportData := ExportFile{
		Species: make([]ExportSpecies, 0, len(entries)),
	}

	for _, entry := range entries {
		species := ExportSpecies{
			Name:               entry.ScientificName,
			Author:             entry.Author,
			IsHybrid:           entry.IsHybrid,
			ConservationStatus: entry.ConservationStatus,
			Taxonomy: ExportTaxonomy{
				Genus:      "Quercus",
				Subgenus:   entry.Subgenus,
				Section:    entry.Section,
				Subsection: entry.Subsection,
				Complex:    entry.Complex,
			},
			Parent1:             entry.Parent1,
			Parent2:             entry.Parent2,
			Hybrids:             nonEmptySlice(entry.Hybrids),
			CloselyRelatedTo:    nonEmptySlice(entry.CloselyRelatedTo),
			SubspeciesVarieties: nonEmptySlice(entry.SubspeciesVarieties),
			Synonyms:            nonEmptySlice(entry.Synonyms),
			Sources:             []ExportSourceData{},
		}

		// Get species_sources data for this entry
		speciesSources, err := database.GetSpeciesSources(entry.ScientificName)
		if err != nil {
			return fmt.Errorf("failed to get species sources for %s: %w", entry.ScientificName, err)
		}

		// Convert species_sources to export format
		for _, ss := range speciesSources {
			sd := ExportSourceData{
				SourceID:         ss.SourceID,
				SourceName:       fmt.Sprintf("Source %d", ss.SourceID),
				IsPreferred:      ss.IsPreferred,
				LocalNames:       nonEmptySlice(ss.LocalNames),
				Range:            ss.Range,
				GrowthHabit:      ss.GrowthHabit,
				Leaves:           ss.Leaves,
				Flowers:          ss.Flowers,
				Fruits:           ss.Fruits,
				BarkTwigsBuds:    ss.BarkTwigsBuds,
				HardinessHabitat: ss.HardinessHabitat,
				Miscellaneous:    ss.Miscellaneous,
				URL:              ss.URL,
			}

			if source, ok := sourceMap[ss.SourceID]; ok {
				sd.SourceName = source.Name
				sd.SourceURL = source.URL
			}

			species.Sources = append(species.Sources, sd)
		}

		exportData.Species = append(exportData.Species, species)
	}

	// Marshal to JSON
	jsonData, err := json.MarshalIndent(exportData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	// Write output
	if outputPath == "" {
		fmt.Println(string(jsonData))
	} else {
		if err := os.WriteFile(outputPath, jsonData, 0644); err != nil {
			return fmt.Errorf("failed to write output file: %w", err)
		}
		fmt.Fprintf(cmd.ErrOrStderr(), "Exported %d species to %s\n", len(exportData.Species), outputPath)
	}

	return nil
}

func nonEmptySlice(s []string) []string {
	if len(s) == 0 {
		return nil
	}
	return s
}
