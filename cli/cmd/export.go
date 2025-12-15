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
	SourceID   string   `json:"source_id"`
	SourceName string   `json:"source_name"`
	SourceURL  *string  `json:"source_url,omitempty"`
	LocalNames []string `json:"local_names,omitempty"`
	Synonyms   []string `json:"synonyms,omitempty"`
	// Morphological fields from data_points
	LeafColor   *string `json:"leaf_color,omitempty"`
	LeafShape   *string `json:"leaf_shape,omitempty"`
	BudShape    *string `json:"bud_shape,omitempty"`
	BarkTexture *string `json:"bark_texture,omitempty"`
	Habitat     *string `json:"habitat,omitempty"`
	NativeRange *string `json:"native_range,omitempty"`
	Height      *string `json:"height,omitempty"`
}

// ExportSpecies represents a species in export format
type ExportSpecies struct {
	Name               string             `json:"name"`
	Author             *string            `json:"author,omitempty"`
	IsHybrid           bool               `json:"is_hybrid"`
	ConservationStatus *string            `json:"conservation_status,omitempty"`
	Taxonomy           ExportTaxonomy     `json:"taxonomy"`
	Parent1            *string            `json:"parent1,omitempty"`
	Parent2            *string            `json:"parent2,omitempty"`
	Hybrids            []string           `json:"hybrids,omitempty"`
	CloselyRelatedTo   []string           `json:"closely_related_to,omitempty"`
	Sources            []ExportSourceData `json:"sources,omitempty"`
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
	sourceMap := make(map[string]*models.Source)
	for _, s := range sources {
		sourceMap[s.SourceID] = s
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
			Parent1:          entry.Parent1,
			Parent2:          entry.Parent2,
			Hybrids:          nonEmptySlice(entry.Hybrids),
			CloselyRelatedTo: nonEmptySlice(entry.CloselyRelatedTo),
			Sources:          []ExportSourceData{},
		}

		// Get data points for this entry
		dataPoints, err := database.GetDataPointsForEntry(entry.ScientificName)
		if err != nil {
			return fmt.Errorf("failed to get data points for %s: %w", entry.ScientificName, err)
		}

		// Group data by source
		sourceDataMap := make(map[string]*ExportSourceData)

		// Process common_names (becomes local_names in export)
		for _, dp := range dataPoints["common_names"] {
			sd := getOrCreateSourceData(sourceDataMap, dp.SourceID, sourceMap)
			sd.LocalNames = append(sd.LocalNames, dp.Value)
		}

		// Process morphological fields
		processField(dataPoints, "leaf_color", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.LeafColor = &v })
		processField(dataPoints, "leaf_shape", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.LeafShape = &v })
		processField(dataPoints, "bud_shape", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.BudShape = &v })
		processField(dataPoints, "bark_texture", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.BarkTexture = &v })
		processField(dataPoints, "habitat", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.Habitat = &v })
		processField(dataPoints, "native_range", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.NativeRange = &v })
		processField(dataPoints, "height", sourceDataMap, sourceMap, func(sd *ExportSourceData, v string) { sd.Height = &v })

		// Add synonyms (stored on entry, not in data_points)
		if len(entry.Synonyms) > 0 {
			// If we have sources with data, add synonyms to the first one
			// Otherwise create a placeholder source
			if len(sourceDataMap) > 0 {
				for _, sd := range sourceDataMap {
					sd.Synonyms = entry.Synonyms
					break
				}
			}
		}

		// Convert map to slice
		for _, sd := range sourceDataMap {
			species.Sources = append(species.Sources, *sd)
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

func getOrCreateSourceData(m map[string]*ExportSourceData, sourceID string, sourceMap map[string]*models.Source) *ExportSourceData {
	if sd, ok := m[sourceID]; ok {
		return sd
	}

	sd := &ExportSourceData{
		SourceID:   sourceID,
		SourceName: sourceID, // Default to ID if source not found
		LocalNames: []string{},
		Synonyms:   []string{},
	}

	if source, ok := sourceMap[sourceID]; ok {
		sd.SourceName = source.Name
		sd.SourceURL = source.URL
	}

	m[sourceID] = sd
	return sd
}

func processField(dataPoints map[string][]models.DataPoint, fieldName string, sourceDataMap map[string]*ExportSourceData, sourceMap map[string]*models.Source, setter func(*ExportSourceData, string)) {
	for _, dp := range dataPoints[fieldName] {
		sd := getOrCreateSourceData(sourceDataMap, dp.SourceID, sourceMap)
		setter(sd, dp.Value)
	}
}

func nonEmptySlice(s []string) []string {
	if len(s) == 0 {
		return nil
	}
	return s
}
