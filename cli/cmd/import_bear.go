package cmd

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
)

var bearSourceID int64

var importBearCmd = &cobra.Command{
	Use:   "import-bear",
	Short: "Import data from Bear app notes",
	Long: `Import oak species data from Bear app notes.

This command reads the Bear app SQLite database and imports notes
tagged with the Quercus taxonomy pattern into the oak compendium.

Bear Notes Location:
  ~/Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite

Tag Format:
  #Quercus/Subgenus/Section/species     - Regular species
  #Quercus/Subgenus/Section/x/hybrid    - Hybrids

Note Template Fields:
  ## Common Name(s): → local_names
  ### Leaf:          → leaves
  ### Acorn:         → fruits
  ### Bark:          → bark
  ### Buds:          → buds
  ### Form:          → growth_habit
  ## Range & Habitat: → range
  ## Field Notes:    → miscellaneous
  ## Resources:      → miscellaneous (appended)

Examples:
  oak import-bear --source-id 3
  oak import-bear --source-id 3 --dry-run`,
	RunE: runImportBear,
}

var bearDryRun bool

func init() {
	importBearCmd.Flags().Int64Var(&bearSourceID, "source-id", 3, "Source ID to attribute the data to")
	importBearCmd.Flags().BoolVar(&bearDryRun, "dry-run", false, "Show what would be imported without making changes")
	rootCmd.AddCommand(importBearCmd)
}

// BearNote represents a note from Bear
type BearNote struct {
	ID         int64
	Title      string
	Text       string
	TaxonomyTag string
}

// ParsedNote contains parsed fields from a Bear note
type ParsedNote struct {
	SpeciesName     string
	IsHybrid        bool
	Subgenus        string
	Section         string
	CommonNames     []string
	Leaves          string
	Fruits          string // From Acorn section
	Bark            string
	Buds            string
	GrowthHabit     string // From Form section
	Range           string
	FieldNotes      string
	Resources       string
}

func runImportBear(cmd *cobra.Command, args []string) error {
	// Get Bear database path
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}
	bearDBPath := filepath.Join(home, "Library", "Group Containers", "9K33E3U3T4.net.shinyfrog.bear", "Application Data", "database.sqlite")

	// Check if Bear database exists
	if _, err := os.Stat(bearDBPath); os.IsNotExist(err) {
		return fmt.Errorf("Bear database not found at %s", bearDBPath)
	}

	// Open Bear database (read-only)
	bearDB, err := sql.Open("sqlite3", bearDBPath+"?mode=ro")
	if err != nil {
		return fmt.Errorf("failed to open Bear database: %w", err)
	}
	defer bearDB.Close()

	// Open oak compendium database
	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	// Verify source exists
	source, err := database.GetSource(bearSourceID)
	if err != nil {
		return err
	}
	if source == nil {
		return fmt.Errorf("source with ID %d not found", bearSourceID)
	}

	fmt.Printf("Importing from Bear to source: %s (ID: %d)\n", source.Name, bearSourceID)
	if bearDryRun {
		fmt.Println("DRY RUN - no changes will be made\n")
	}

	// Query notes with Quercus taxonomy tags
	notes, err := queryBearNotes(bearDB)
	if err != nil {
		return fmt.Errorf("failed to query Bear notes: %w", err)
	}

	fmt.Printf("Found %d Quercus notes in Bear\n\n", len(notes))

	imported := 0
	skipped := 0
	errors := 0

	for _, note := range notes {
		parsed := parseNoteContent(note)
		if parsed.SpeciesName == "" {
			fmt.Printf("  SKIP: %s (no species name from tag)\n", note.Title)
			skipped++
			continue
		}

		// Check if species exists in oak_entries
		existing, err := database.GetOakEntry(parsed.SpeciesName)
		if err != nil {
			fmt.Printf("  ERROR: %s: %v\n", parsed.SpeciesName, err)
			errors++
			continue
		}

		if existing == nil {
			// Try with × prefix for hybrids
			if parsed.IsHybrid {
				existing, err = database.GetOakEntry("× " + parsed.SpeciesName)
				if err != nil {
					fmt.Printf("  ERROR: %s: %v\n", parsed.SpeciesName, err)
					errors++
					continue
				}
			}
		}

		if existing == nil {
			fmt.Printf("  SKIP: %s (not found in oak_entries)\n", parsed.SpeciesName)
			skipped++
			continue
		}

		// Check if source has any content worth importing
		if !hasContent(parsed) {
			fmt.Printf("  SKIP: %s (no content to import)\n", parsed.SpeciesName)
			skipped++
			continue
		}

		// Build SpeciesSource
		speciesSource := buildSpeciesSource(existing.ScientificName, parsed, bearSourceID)

		if bearDryRun {
			fmt.Printf("  WOULD IMPORT: %s\n", existing.ScientificName)
			printParsedContent(parsed)
			imported++
		} else {
			if err := database.SaveSpeciesSource(speciesSource); err != nil {
				fmt.Printf("  ERROR: %s: %v\n", existing.ScientificName, err)
				errors++
				continue
			}
			fmt.Printf("  IMPORTED: %s\n", existing.ScientificName)
			imported++
		}
	}

	fmt.Printf("\nImport complete:\n")
	fmt.Printf("  Imported: %d\n", imported)
	fmt.Printf("  Skipped:  %d\n", skipped)
	fmt.Printf("  Errors:   %d\n", errors)

	return nil
}

func queryBearNotes(db *sql.DB) ([]BearNote, error) {
	// Query notes that have Quercus species-level tags
	// Use subquery to get the most specific (longest) tag for each note
	// This avoids getting both parent tags and species tags for the same note
	query := `
		WITH species_tags AS (
			SELECT n.Z_PK as note_id, n.ZTITLE as title, n.ZTEXT as text, t.ZTITLE as tag,
				   LENGTH(t.ZTITLE) as tag_len
			FROM ZSFNOTE n
			JOIN Z_5TAGS nt ON n.Z_PK = nt.Z_5NOTES
			JOIN ZSFNOTETAG t ON nt.Z_13TAGS = t.Z_PK
			WHERE (
				-- Species pattern: Quercus/Subgenus/Section/species (4 parts)
				(t.ZTITLE LIKE 'Quercus/%/%/%'
				 AND t.ZTITLE NOT LIKE 'Quercus/%/x')
				OR
				-- Hybrid pattern: Quercus/Subgenus/x/hybrid or Quercus/Subgenus/Section/x/hybrid
				(t.ZTITLE LIKE 'Quercus/%/x/%')
			)
			AND n.ZTRASHED = 0
		),
		most_specific AS (
			SELECT note_id, MAX(tag_len) as max_len
			FROM species_tags
			GROUP BY note_id
		)
		SELECT st.note_id, st.title, st.text, st.tag
		FROM species_tags st
		JOIN most_specific ms ON st.note_id = ms.note_id AND st.tag_len = ms.max_len
		ORDER BY st.title
	`

	rows, err := db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notes []BearNote
	for rows.Next() {
		var note BearNote
		var text sql.NullString
		if err := rows.Scan(&note.ID, &note.Title, &text, &note.TaxonomyTag); err != nil {
			return nil, err
		}
		if text.Valid {
			note.Text = text.String
		}
		notes = append(notes, note)
	}

	return notes, rows.Err()
}

func parseNoteContent(note BearNote) ParsedNote {
	parsed := ParsedNote{}

	// Parse taxonomy tag to get species info
	// Format: Quercus/Subgenus/Section/species or Quercus/Subgenus/x/hybrid or Quercus/Subgenus/Section/x/hybrid
	parts := strings.Split(note.TaxonomyTag, "/")
	if len(parts) >= 4 {
		parsed.Subgenus = parts[1]

		// Check for hybrid pattern
		for i, part := range parts {
			if strings.EqualFold(part, "x") && i < len(parts)-1 {
				parsed.IsHybrid = true
				parsed.SpeciesName = parts[i+1]
				if i >= 2 {
					parsed.Section = parts[i-1]
				}
				break
			}
		}

		// Regular species
		if !parsed.IsHybrid {
			parsed.Section = parts[2]
			parsed.SpeciesName = parts[len(parts)-1]
		}
	}

	// Parse markdown sections
	text := note.Text

	// Common Names - after "## Common Name(s):" header
	parsed.CommonNames = parseCommonNames(text)

	// Leaf section
	parsed.Leaves = parseSection(text, "### Leaf:")

	// Acorn section → fruits
	parsed.Fruits = parseSection(text, "### Acorn:")

	// Bark section
	parsed.Bark = parseSection(text, "### Bark:")

	// Buds section
	parsed.Buds = parseSection(text, "### Buds:")

	// Form section → growth_habit
	parsed.GrowthHabit = parseSection(text, "### Form:")

	// Range & Habitat section
	parsed.Range = parseSection(text, "## Range & Habitat:")

	// Field Notes section
	parsed.FieldNotes = parseSection(text, "## Field Notes:")

	// Resources section
	parsed.Resources = parseSection(text, "## Resources:")

	return parsed
}

func parseCommonNames(text string) []string {
	// Find content after "## Common Name(s):" until the next "##"
	pattern := regexp.MustCompile(`(?i)##\s*Common Name\(s\):\s*\n([^#]*)`)
	match := pattern.FindStringSubmatch(text)
	if len(match) < 2 {
		return nil
	}

	content := strings.TrimSpace(match[1])
	if content == "" {
		return nil
	}

	// Split by newlines and/or commas
	var names []string
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Split by comma if present
		for _, name := range strings.Split(line, ",") {
			name = strings.TrimSpace(name)
			if name != "" {
				names = append(names, name)
			}
		}
	}

	return names
}

func parseSection(text, header string) string {
	// Escape special regex chars in header
	escapedHeader := regexp.QuoteMeta(header)

	// Find content after header until the next ## or ### or end
	// Use case-insensitive matching
	pattern := regexp.MustCompile(`(?i)` + escapedHeader + `[^\n]*\n((?:[^#]|#[^#])*)`)
	match := pattern.FindStringSubmatch(text)
	if len(match) < 2 {
		return ""
	}

	content := strings.TrimSpace(match[1])

	// Remove placeholder text in parentheses like "(Shape, lobes, bristle tips...)"
	placeholderPattern := regexp.MustCompile(`^\([^)]+\)\s*`)
	content = placeholderPattern.ReplaceAllString(content, "")

	return strings.TrimSpace(content)
}

func hasContent(parsed ParsedNote) bool {
	return len(parsed.CommonNames) > 0 ||
		parsed.Leaves != "" ||
		parsed.Fruits != "" ||
		parsed.Bark != "" ||
		parsed.Buds != "" ||
		parsed.GrowthHabit != "" ||
		parsed.Range != "" ||
		parsed.FieldNotes != "" ||
		parsed.Resources != ""
}

func buildSpeciesSource(scientificName string, parsed ParsedNote, sourceID int64) *models.SpeciesSource {
	ss := &models.SpeciesSource{
		ScientificName: scientificName,
		SourceID:       sourceID,
		LocalNames:     parsed.CommonNames,
		IsPreferred:    false, // Bear notes are supplemental, not primary
	}

	if ss.LocalNames == nil {
		ss.LocalNames = []string{}
	}

	if parsed.Leaves != "" {
		ss.Leaves = &parsed.Leaves
	}
	if parsed.Fruits != "" {
		ss.Fruits = &parsed.Fruits
	}
	if parsed.Bark != "" {
		ss.Bark = &parsed.Bark
	}
	if parsed.Buds != "" {
		ss.Buds = &parsed.Buds
	}
	if parsed.GrowthHabit != "" {
		ss.GrowthHabit = &parsed.GrowthHabit
	}
	if parsed.Range != "" {
		ss.Range = &parsed.Range
	}

	// Combine Field Notes and Resources into miscellaneous
	misc := ""
	if parsed.FieldNotes != "" {
		misc = "Field Notes:\n" + parsed.FieldNotes
	}
	if parsed.Resources != "" {
		if misc != "" {
			misc += "\n\n"
		}
		misc += "Resources:\n" + parsed.Resources
	}
	if misc != "" {
		ss.Miscellaneous = &misc
	}

	return ss
}

func printParsedContent(parsed ParsedNote) {
	if len(parsed.CommonNames) > 0 {
		fmt.Printf("    Common Names: %v\n", parsed.CommonNames)
	}
	if parsed.Leaves != "" {
		fmt.Printf("    Leaves: %s\n", truncateStr(parsed.Leaves, 50))
	}
	if parsed.Fruits != "" {
		fmt.Printf("    Fruits: %s\n", truncateStr(parsed.Fruits, 50))
	}
	if parsed.Bark != "" {
		fmt.Printf("    Bark: %s\n", truncateStr(parsed.Bark, 50))
	}
	if parsed.Buds != "" {
		fmt.Printf("    Buds: %s\n", truncateStr(parsed.Buds, 50))
	}
	if parsed.GrowthHabit != "" {
		fmt.Printf("    Growth Habit: %s\n", truncateStr(parsed.GrowthHabit, 50))
	}
	if parsed.Range != "" {
		fmt.Printf("    Range: %s\n", truncateStr(parsed.Range, 50))
	}
	if parsed.FieldNotes != "" {
		fmt.Printf("    Field Notes: %s\n", truncateStr(parsed.FieldNotes, 50))
	}
	if parsed.Resources != "" {
		fmt.Printf("    Resources: %s\n", truncateStr(parsed.Resources, 50))
	}
}

func truncateStr(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}
