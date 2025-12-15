package cmd

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/jeff/oaks/cli/internal/schema"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

var sourceID string

var importBulkCmd = &cobra.Command{
	Use:   "import-bulk <file>",
	Short: "Import data from a file in bulk",
	Long: `Import oak entries from a YAML or JSON file with conflict resolution.
All imported data will be attributed to the specified source.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		filePath := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		validator, err := getSchema()
		if err != nil {
			return err
		}

		// Verify source exists
		source, err := database.GetSource(sourceID)
		if err != nil {
			return err
		}
		if source == nil {
			return fmt.Errorf("source '%s' not found. Create it first with 'oak source new'", sourceID)
		}

		return importBulk(database, validator, filePath, sourceID)
	},
}

func importBulk(database *db.Database, validator *schema.Validator, filePath, srcID string) error {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read import file: %w", err)
	}

	var entries []models.OakEntry
	ext := strings.ToLower(filepath.Ext(filePath))

	switch ext {
	case ".yaml", ".yml":
		if err := yaml.Unmarshal(data, &entries); err != nil {
			return fmt.Errorf("failed to parse YAML: %w", err)
		}
	case ".json":
		if err := json.Unmarshal(data, &entries); err != nil {
			return fmt.Errorf("failed to parse JSON: %w", err)
		}
	default:
		return fmt.Errorf("unsupported file format: %s (use .yaml, .yml, or .json)", ext)
	}

	fmt.Printf("Found %d entries to import\n", len(entries))

	imported := 0
	skipped := 0

	for _, entry := range entries {
		if err := validator.ValidateOakEntry(&entry); err != nil {
			fmt.Fprintf(os.Stderr, "Validation failed for '%s': %v\n", entry.ScientificName, err)
			skipped++
			continue
		}

		existing, err := database.GetOakEntry(entry.ScientificName)
		if err != nil {
			return err
		}

		if existing != nil {
			// Check for conflicts (same source)
			conflicts := findConflicts(existing, &entry, srcID)
			if len(conflicts) > 0 {
				resolved, skip := resolveConflicts(entry.ScientificName, conflicts)
				if skip {
					fmt.Printf("Skipping '%s'\n", entry.ScientificName)
					skipped++
					continue
				}
				// Apply resolutions
				applyResolutions(&entry, resolved)
			}

			// Merge with existing entry
			mergeEntries(existing, &entry, srcID)
			entry = *existing
		}

		if err := database.SaveOakEntry(&entry); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to save '%s': %v\n", entry.ScientificName, err)
			skipped++
			continue
		}

		imported++
	}

	fmt.Printf("\nImport complete: %d imported, %d skipped\n", imported, skipped)
	return nil
}

type conflict struct {
	field        string
	existingVal  string
	importedVal  string
}

func findConflicts(existing, imported *models.OakEntry, srcID string) []conflict {
	var conflicts []conflict

	checkField := func(fieldName string, existingDPs, importedDPs []models.DataPoint) {
		existingBySource := make(map[string]string)
		for _, dp := range existingDPs {
			if dp.SourceID == srcID {
				existingBySource[dp.SourceID] = dp.Value
			}
		}

		for _, dp := range importedDPs {
			if dp.SourceID == srcID {
				if existingVal, ok := existingBySource[srcID]; ok && existingVal != dp.Value {
					conflicts = append(conflicts, conflict{
						field:       fieldName,
						existingVal: existingVal,
						importedVal: dp.Value,
					})
				}
			}
		}
	}

	checkField("leaf_color", existing.LeafColor, imported.LeafColor)
	checkField("leaf_shape", existing.LeafShape, imported.LeafShape)
	checkField("bud_shape", existing.BudShape, imported.BudShape)
	checkField("bark_texture", existing.BarkTexture, imported.BarkTexture)
	checkField("habitat", existing.Habitat, imported.Habitat)
	checkField("native_range", existing.NativeRange, imported.NativeRange)
	checkField("height", existing.Height, imported.Height)
	checkField("common_names", existing.CommonNames, imported.CommonNames)

	return conflicts
}

func resolveConflicts(name string, conflicts []conflict) (map[string]string, bool) {
	reader := bufio.NewReader(os.Stdin)
	resolutions := make(map[string]string)

	for _, c := range conflicts {
		fmt.Printf("\nConflict for %s, field: %s\n", name, c.field)
		fmt.Printf("[1] Database Value: '%s'\n", c.existingVal)
		fmt.Printf("[2] Imported Value: '%s'\n", c.importedVal)
		fmt.Printf("[S] Skip this entry\n")
		fmt.Print("> Enter choice (1/2/S): ")

		response, _ := reader.ReadString('\n')
		response = strings.TrimSpace(strings.ToLower(response))

		switch response {
		case "1":
			resolutions[c.field] = c.existingVal
		case "2":
			resolutions[c.field] = c.importedVal
		case "s":
			return nil, true
		default:
			// Default to keeping existing
			resolutions[c.field] = c.existingVal
		}
	}

	return resolutions, false
}

func applyResolutions(entry *models.OakEntry, resolutions map[string]string) {
	applyToField := func(fieldName string, dataPoints *[]models.DataPoint) {
		if val, ok := resolutions[fieldName]; ok {
			for i := range *dataPoints {
				(*dataPoints)[i].Value = val
			}
		}
	}

	applyToField("leaf_color", &entry.LeafColor)
	applyToField("leaf_shape", &entry.LeafShape)
	applyToField("bud_shape", &entry.BudShape)
	applyToField("bark_texture", &entry.BarkTexture)
	applyToField("habitat", &entry.Habitat)
	applyToField("native_range", &entry.NativeRange)
	applyToField("height", &entry.Height)
	applyToField("common_names", &entry.CommonNames)
}

func mergeEntries(existing, imported *models.OakEntry, srcID string) {
	mergeField := func(existingDPs *[]models.DataPoint, importedDPs []models.DataPoint) {
		// Add imported data points that don't conflict with existing ones from the same source
		existingSources := make(map[string]bool)
		for _, dp := range *existingDPs {
			existingSources[dp.SourceID] = true
		}

		for _, dp := range importedDPs {
			if !existingSources[dp.SourceID] {
				*existingDPs = append(*existingDPs, dp)
			}
		}
	}

	mergeField(&existing.LeafColor, imported.LeafColor)
	mergeField(&existing.LeafShape, imported.LeafShape)
	mergeField(&existing.BudShape, imported.BudShape)
	mergeField(&existing.BarkTexture, imported.BarkTexture)
	mergeField(&existing.Habitat, imported.Habitat)
	mergeField(&existing.NativeRange, imported.NativeRange)
	mergeField(&existing.Height, imported.Height)
	mergeField(&existing.CommonNames, imported.CommonNames)

	// Merge synonyms
	existingSynonyms := make(map[string]bool)
	for _, s := range existing.Synonyms {
		existingSynonyms[s] = true
	}
	for _, s := range imported.Synonyms {
		if !existingSynonyms[s] {
			existing.Synonyms = append(existing.Synonyms, s)
		}
	}
}

func init() {
	importBulkCmd.Flags().StringVar(&sourceID, "source-id", "", "Source ID to attribute the data to (required)")
	importBulkCmd.MarkFlagRequired("source-id")
	rootCmd.AddCommand(importBulkCmd)
}
