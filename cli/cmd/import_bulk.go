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

var sourceID int64

var importBulkCmd = &cobra.Command{
	Use:   "import-bulk <file>",
	Short: "Import data from a file in bulk",
	Long: `Import oak entries from a YAML or JSON file.
All imported data will be attributed to the specified source.

Note: This command imports OakEntry (species-intrinsic) data only.
Source-attributed descriptive data should be imported via import-oaksoftheworld.`,
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
			return fmt.Errorf("source with ID %d not found. Create it first with 'oak source new'", sourceID)
		}

		return importBulk(database, validator, filePath, sourceID)
	},
}

func importBulk(database *db.Database, validator *schema.Validator, filePath string, srcID int64) error {
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
			// Check for conflicts on intrinsic fields
			conflicts := findConflicts(existing, &entry)
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
			mergeEntries(existing, &entry)
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
	field       string
	existingVal string
	importedVal string
}

func findConflicts(existing, imported *models.OakEntry) []conflict {
	var conflicts []conflict

	// Check intrinsic fields that could conflict
	if existing.Author != nil && imported.Author != nil && *existing.Author != *imported.Author {
		conflicts = append(conflicts, conflict{
			field:       "author",
			existingVal: *existing.Author,
			importedVal: *imported.Author,
		})
	}

	if existing.ConservationStatus != nil && imported.ConservationStatus != nil &&
		*existing.ConservationStatus != *imported.ConservationStatus {
		conflicts = append(conflicts, conflict{
			field:       "conservation_status",
			existingVal: *existing.ConservationStatus,
			importedVal: *imported.ConservationStatus,
		})
	}

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
	if val, ok := resolutions["author"]; ok {
		entry.Author = &val
	}
	if val, ok := resolutions["conservation_status"]; ok {
		entry.ConservationStatus = &val
	}
}

func mergeEntries(existing, imported *models.OakEntry) {
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

	// Merge hybrids
	existingHybrids := make(map[string]bool)
	for _, h := range existing.Hybrids {
		existingHybrids[h] = true
	}
	for _, h := range imported.Hybrids {
		if !existingHybrids[h] {
			existing.Hybrids = append(existing.Hybrids, h)
		}
	}

	// Merge closely related
	existingRelated := make(map[string]bool)
	for _, r := range existing.CloselyRelatedTo {
		existingRelated[r] = true
	}
	for _, r := range imported.CloselyRelatedTo {
		if !existingRelated[r] {
			existing.CloselyRelatedTo = append(existing.CloselyRelatedTo, r)
		}
	}

	// Merge subspecies/varieties
	existingSubsp := make(map[string]bool)
	for _, s := range existing.SubspeciesVarieties {
		existingSubsp[s] = true
	}
	for _, s := range imported.SubspeciesVarieties {
		if !existingSubsp[s] {
			existing.SubspeciesVarieties = append(existing.SubspeciesVarieties, s)
		}
	}

	// For single-value fields, only update if existing is nil
	if existing.Author == nil && imported.Author != nil {
		existing.Author = imported.Author
	}
	if existing.ConservationStatus == nil && imported.ConservationStatus != nil {
		existing.ConservationStatus = imported.ConservationStatus
	}
	if existing.Subgenus == nil && imported.Subgenus != nil {
		existing.Subgenus = imported.Subgenus
	}
	if existing.Section == nil && imported.Section != nil {
		existing.Section = imported.Section
	}
	if existing.Subsection == nil && imported.Subsection != nil {
		existing.Subsection = imported.Subsection
	}
	if existing.Complex == nil && imported.Complex != nil {
		existing.Complex = imported.Complex
	}
	if existing.Parent1 == nil && imported.Parent1 != nil {
		existing.Parent1 = imported.Parent1
	}
	if existing.Parent2 == nil && imported.Parent2 != nil {
		existing.Parent2 = imported.Parent2
	}
}

func init() {
	importBulkCmd.Flags().Int64Var(&sourceID, "source-id", 0, "Source ID to attribute the data to (required)")
	importBulkCmd.MarkFlagRequired("source-id")
	rootCmd.AddCommand(importBulkCmd)
}
