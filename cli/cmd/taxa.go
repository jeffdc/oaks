package cmd

import (
	"fmt"
	"os"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

// TaxaFile represents the structure of the taxa YAML file
type TaxaFile struct {
	Subgenera   []TaxonEntry `yaml:"subgenera"`
	Sections    []TaxonEntry `yaml:"sections"`
	Subsections []TaxonEntry `yaml:"subsections"`
	Complexes   []TaxonEntry `yaml:"complexes"`
}

// TaxonEntry represents a single taxon in the YAML file
type TaxonEntry struct {
	Name   string  `yaml:"name"`
	Parent *string `yaml:"parent"`
	Author *string `yaml:"author"`
	Notes  *string `yaml:"notes"`
}

var taxaCmd = &cobra.Command{
	Use:   "taxa",
	Short: "Manage taxonomy reference data",
	Long:  `Commands for managing the taxonomy reference table (subgenera, sections, subsections, complexes).`,
}

var taxaImportCmd = &cobra.Command{
	Use:   "import <file>",
	Short: "Import taxa from YAML file",
	Long: `Import taxonomy reference data from a YAML file.

The file should have sections for subgenera, sections, subsections, and complexes.
Each entry can have: name, parent, author, notes.

Example:
  oak taxa import data/taxa.yaml`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaImport,
}

var taxaListCmd = &cobra.Command{
	Use:   "list [level]",
	Short: "List taxa",
	Long: `List all taxa, optionally filtered by level.

Levels: subgenus, section, subsection, complex

Examples:
  oak taxa list
  oak taxa list subgenus
  oak taxa list section`,
	Args: cobra.MaximumNArgs(1),
	RunE: runTaxaList,
}

var (
	taxaImportClear bool
)

func init() {
	rootCmd.AddCommand(taxaCmd)
	taxaCmd.AddCommand(taxaImportCmd)
	taxaCmd.AddCommand(taxaListCmd)

	taxaImportCmd.Flags().BoolVar(&taxaImportClear, "clear", false, "Clear existing taxa before import")
}

func runTaxaImport(cmd *cobra.Command, args []string) error {
	filePath := args[0]

	// Read YAML file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var taxaFile TaxaFile
	if err := yaml.Unmarshal(data, &taxaFile); err != nil {
		return fmt.Errorf("failed to parse YAML: %w", err)
	}

	// Open database
	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Clear existing if requested
	if taxaImportClear {
		if err := database.ClearTaxa(); err != nil {
			return fmt.Errorf("failed to clear taxa: %w", err)
		}
		fmt.Fprintln(cmd.ErrOrStderr(), "Cleared existing taxa")
	}

	// Import counts
	var imported, skipped, errors int

	// Helper to import a list of taxa at a given level
	importLevel := func(entries []TaxonEntry, level models.TaxonLevel) {
		for _, entry := range entries {
			if entry.Name == "" {
				continue
			}

			taxon := &models.Taxon{
				Name:   entry.Name,
				Level:  level,
				Parent: entry.Parent,
				Author: entry.Author,
				Notes:  entry.Notes,
			}

			err := database.InsertTaxon(taxon)
			if err != nil {
				// Check if it's a duplicate
				existing, _ := database.GetTaxon(entry.Name, level)
				if existing != nil {
					skipped++
					fmt.Fprintf(cmd.ErrOrStderr(), "  Skipped (exists): %s [%s]\n", entry.Name, level)
				} else {
					errors++
					fmt.Fprintf(cmd.ErrOrStderr(), "  Error: %s [%s]: %v\n", entry.Name, level, err)
				}
			} else {
				imported++
				fmt.Fprintf(cmd.ErrOrStderr(), "  Imported: %s [%s]\n", entry.Name, level)
			}
		}
	}

	fmt.Fprintln(cmd.ErrOrStderr(), "Importing subgenera...")
	importLevel(taxaFile.Subgenera, models.TaxonLevelSubgenus)

	fmt.Fprintln(cmd.ErrOrStderr(), "Importing sections...")
	importLevel(taxaFile.Sections, models.TaxonLevelSection)

	fmt.Fprintln(cmd.ErrOrStderr(), "Importing subsections...")
	importLevel(taxaFile.Subsections, models.TaxonLevelSubsection)

	fmt.Fprintln(cmd.ErrOrStderr(), "Importing complexes...")
	importLevel(taxaFile.Complexes, models.TaxonLevelComplex)

	fmt.Fprintf(cmd.ErrOrStderr(), "\nDone: %d imported, %d skipped, %d errors\n", imported, skipped, errors)

	return nil
}

func runTaxaList(cmd *cobra.Command, args []string) error {
	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	var level *models.TaxonLevel
	if len(args) > 0 {
		l := models.TaxonLevel(args[0])
		switch l {
		case models.TaxonLevelSubgenus, models.TaxonLevelSection,
			models.TaxonLevelSubsection, models.TaxonLevelComplex:
			level = &l
		default:
			return fmt.Errorf("invalid level: %s (use: subgenus, section, subsection, complex)", args[0])
		}
	}

	taxa, err := database.ListTaxa(level)
	if err != nil {
		return fmt.Errorf("failed to list taxa: %w", err)
	}

	if len(taxa) == 0 {
		fmt.Fprintln(cmd.ErrOrStderr(), "No taxa found")
		return nil
	}

	// Group by level for display
	currentLevel := ""
	for _, t := range taxa {
		if string(t.Level) != currentLevel {
			currentLevel = string(t.Level)
			fmt.Printf("\n=== %s ===\n", currentLevel)
		}

		parent := ""
		if t.Parent != nil {
			parent = fmt.Sprintf(" (parent: %s)", *t.Parent)
		}
		author := ""
		if t.Author != nil {
			author = fmt.Sprintf(" [%s]", *t.Author)
		}
		fmt.Printf("  %s%s%s\n", t.Name, parent, author)
	}
	fmt.Println()

	return nil
}
