package cmd

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
)

var generateBearNotesCmd = &cobra.Command{
	Use:   "generate-bear-notes",
	Short: "Generate markdown files for species not in Bear",
	Long: `Generate markdown note files for all oak species that don't already
exist in the Bear app. Files are created in the tmp/bear-notes directory.

The generated files follow the Bear note template format with taxonomy tags.

Examples:
  oak generate-bear-notes
  oak generate-bear-notes --output ../tmp/bear-notes`,
	RunE: runGenerateBearNotes,
}

var bearNotesOutputDir string

func init() {
	generateBearNotesCmd.Flags().StringVar(&bearNotesOutputDir, "output", "../tmp/bear-notes", "Output directory for generated markdown files")
	rootCmd.AddCommand(generateBearNotesCmd)
}

// SpeciesForBear holds species data needed for Bear note generation
type SpeciesForBear struct {
	ScientificName string
	IsHybrid       bool
	Subgenus       *string
	Section        *string
	Subsection     *string
	Complex        *string
}

func runGenerateBearNotes(cmd *cobra.Command, args []string) error {
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

	// Open oak compendium database directly
	oakDB, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open oak compendium database: %w", err)
	}
	defer oakDB.Close()

	// Get species already in Bear
	bearSpecies, err := getBearSpeciesNames(bearDB)
	if err != nil {
		return fmt.Errorf("failed to get Bear species: %w", err)
	}
	fmt.Printf("Found %d species already in Bear\n", len(bearSpecies))

	// Get all species from oak_compendium
	allSpecies, err := getAllSpeciesForBear(oakDB)
	if err != nil {
		return fmt.Errorf("failed to get species from database: %w", err)
	}
	fmt.Printf("Found %d species in oak_compendium\n", len(allSpecies))

	// Create output directory
	if err := os.MkdirAll(bearNotesOutputDir, 0o755); err != nil {
		return fmt.Errorf("failed to create output directory: %w", err)
	}

	// Generate markdown files for species not in Bear
	generated := 0
	skipped := 0

	for _, species := range allSpecies {
		// Normalize name for comparison
		normalizedName := normalizeSpeciesName(species.ScientificName)
		if bearSpecies[normalizedName] {
			skipped++
			continue
		}

		// Generate markdown content
		content := generateBearNoteContent(species)

		// Create filename (sanitize for filesystem)
		filename := sanitizeFilename(species.ScientificName) + ".md"
		filepath := filepath.Join(bearNotesOutputDir, filename)

		if err := os.WriteFile(filepath, []byte(content), 0o644); err != nil { //nolint:gosec // notes must be readable
			fmt.Fprintf(os.Stderr, "Error writing %s: %v\n", filename, err)
			continue
		}

		generated++
	}

	fmt.Printf("\nGeneration complete:\n")
	fmt.Printf("  Generated: %d files\n", generated)
	fmt.Printf("  Skipped (already in Bear): %d\n", skipped)
	fmt.Printf("  Output directory: %s\n", bearNotesOutputDir)

	return nil
}

func getBearSpeciesNames(db *sql.DB) (map[string]bool, error) {
	query := `
		SELECT DISTINCT n.ZTITLE
		FROM ZSFNOTE n
		JOIN Z_5TAGS nt ON n.Z_PK = nt.Z_5NOTES
		JOIN ZSFNOTETAG t ON nt.Z_13TAGS = t.Z_PK
		WHERE t.ZTITLE LIKE 'Quercus/%'
		  AND n.ZTRASHED = 0
	`

	rows, err := db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	species := make(map[string]bool)
	for rows.Next() {
		var title string
		if err := rows.Scan(&title); err != nil {
			return nil, err
		}
		// Normalize: "Quercus alba" -> "alba", "Quercus x deamii" -> "× deamii"
		normalized := normalizeSpeciesName(title)
		species[normalized] = true
	}

	return species, rows.Err()
}

func normalizeSpeciesName(name string) string {
	// Remove "Quercus " prefix
	name = strings.TrimPrefix(name, "Quercus ")
	// Normalize hybrid notation: replace ASCII x with Unicode ×
	name = strings.ReplaceAll(name, "x ", "× ")
	// Trim and lowercase for comparison
	return strings.ToLower(strings.TrimSpace(name))
}

func getAllSpeciesForBear(db *sql.DB) ([]SpeciesForBear, error) {
	query := `
		SELECT scientific_name, is_hybrid, subgenus, section, subsection, complex
		FROM oak_entries
		ORDER BY scientific_name
	`

	rows, err := db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var species []SpeciesForBear
	for rows.Next() {
		var s SpeciesForBear
		if err := rows.Scan(&s.ScientificName, &s.IsHybrid, &s.Subgenus, &s.Section, &s.Subsection, &s.Complex); err != nil {
			return nil, err
		}
		species = append(species, s)
	}

	return species, rows.Err()
}

func generateBearNoteContent(species SpeciesForBear) string {
	var sb strings.Builder

	// Title
	displayName := species.ScientificName
	if species.IsHybrid && !strings.HasPrefix(displayName, "×") {
		displayName = "× " + displayName
	}
	sb.WriteString(fmt.Sprintf("# Quercus %s\n\n", displayName))

	// Common Names
	sb.WriteString("## Common Name(s):\n\n")

	// Taxonomy tag
	sb.WriteString("## Taxonomy:\n")
	tag := buildTaxonomyTag(species)
	sb.WriteString(tag + "\n\n")

	// Identification sections
	sb.WriteString("## Identification:\n\n")
	sb.WriteString("### Leaf:\n\n")
	sb.WriteString("### Acorn:\n\n")
	sb.WriteString("### Bark:\n\n")
	sb.WriteString("### Buds:\n\n")
	sb.WriteString("### Form:\n\n")

	// Other sections
	sb.WriteString("## Range & Habitat:\n\n")
	sb.WriteString("## Field Notes:\n\n")
	sb.WriteString("## Resources:\n\n")
	sb.WriteString("## Photos:\n")

	return sb.String()
}

func buildTaxonomyTag(species SpeciesForBear) string {
	parts := []string{"#Quercus"}

	// Subgenus (default to Quercus if not specified)
	if species.Subgenus != nil && *species.Subgenus != "" {
		parts = append(parts, *species.Subgenus)
	} else {
		parts = append(parts, "Quercus")
	}

	// Section (if present)
	if species.Section != nil && *species.Section != "" {
		parts = append(parts, *species.Section)
	}

	// Subsection (if present)
	if species.Subsection != nil && *species.Subsection != "" {
		parts = append(parts, *species.Subsection)
	}

	// Complex (if present)
	if species.Complex != nil && *species.Complex != "" {
		parts = append(parts, *species.Complex)
	}

	// For hybrids, add /x/ before the species name
	if species.IsHybrid {
		parts = append(parts, "x")
	}

	// Species name (without × prefix)
	speciesName := strings.TrimPrefix(species.ScientificName, "× ")
	speciesName = strings.TrimSpace(speciesName)
	parts = append(parts, speciesName)

	return strings.Join(parts, "/")
}

func sanitizeFilename(name string) string {
	// Replace problematic characters
	name = strings.ReplaceAll(name, "×", "x")
	name = strings.ReplaceAll(name, " ", "_")
	name = strings.ReplaceAll(name, "/", "_")
	name = strings.ReplaceAll(name, "\\", "_")
	name = strings.ReplaceAll(name, ":", "_")
	name = strings.ReplaceAll(name, "*", "_")
	name = strings.ReplaceAll(name, "?", "_")
	name = strings.ReplaceAll(name, "\"", "_")
	name = strings.ReplaceAll(name, "<", "_")
	name = strings.ReplaceAll(name, ">", "_")
	name = strings.ReplaceAll(name, "|", "_")
	return name
}
