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

// TaxonLink represents an external link in the YAML file
type TaxonLinkEntry struct {
	Label string `yaml:"label"`
	URL   string `yaml:"url"`
}

// TaxonEntry represents a single taxon in the YAML file
type TaxonEntry struct {
	Name   string           `yaml:"name"`
	Parent *string          `yaml:"parent"`
	Author *string          `yaml:"author"`
	Notes  *string          `yaml:"notes"`
	Links  []TaxonLinkEntry `yaml:"links"`
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

	// Helper to convert YAML links to model links
	convertLinks := func(entries []TaxonLinkEntry) []models.TaxonLink {
		if len(entries) == 0 {
			return nil
		}
		links := make([]models.TaxonLink, len(entries))
		for i, e := range entries {
			links[i] = models.TaxonLink{Label: e.Label, URL: e.URL}
		}
		return links
	}

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
				Links:  convertLinks(entry.Links),
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

	// Get all taxa
	taxa, err := database.ListTaxa(nil)
	if err != nil {
		return fmt.Errorf("failed to list taxa: %w", err)
	}

	if len(taxa) == 0 {
		fmt.Fprintln(cmd.ErrOrStderr(), "No taxa found")
		return nil
	}

	// Organize by level
	subgenera := []*models.Taxon{}
	sectionsByParent := make(map[string][]*models.Taxon)
	subsectionsByParent := make(map[string][]*models.Taxon)
	complexesByParent := make(map[string][]*models.Taxon)

	for _, t := range taxa {
		switch t.Level {
		case models.TaxonLevelSubgenus:
			subgenera = append(subgenera, t)
		case models.TaxonLevelSection:
			parent := ""
			if t.Parent != nil {
				parent = *t.Parent
			}
			sectionsByParent[parent] = append(sectionsByParent[parent], t)
		case models.TaxonLevelSubsection:
			parent := ""
			if t.Parent != nil {
				parent = *t.Parent
			}
			subsectionsByParent[parent] = append(subsectionsByParent[parent], t)
		case models.TaxonLevelComplex:
			parent := ""
			if t.Parent != nil {
				parent = *t.Parent
			}
			complexesByParent[parent] = append(complexesByParent[parent], t)
		}
	}

	// Helper to format author
	fmtAuthor := func(t *models.Taxon) string {
		if t.Author != nil && *t.Author != "" {
			return fmt.Sprintf(" [%s]", *t.Author)
		}
		return ""
	}

	// Print hierarchical tree
	fmt.Println("Quercus (genus)")
	for _, sg := range subgenera {
		fmt.Printf("├── %s (subgenus)%s\n", sg.Name, fmtAuthor(sg))

		sections := sectionsByParent[sg.Name]
		for i, sec := range sections {
			secPrefix := "│   ├── "
			secChildPrefix := "│   │   "
			if i == len(sections)-1 {
				secPrefix = "│   └── "
				secChildPrefix = "│       "
			}
			fmt.Printf("%s%s (section)%s\n", secPrefix, sec.Name, fmtAuthor(sec))

			subsections := subsectionsByParent[sec.Name]
			for j, subsec := range subsections {
				subsecPrefix := secChildPrefix + "├── "
				subsecChildPrefix := secChildPrefix + "│   "
				if j == len(subsections)-1 {
					subsecPrefix = secChildPrefix + "└── "
					subsecChildPrefix = secChildPrefix + "    "
				}
				fmt.Printf("%s%s (subsection)%s\n", subsecPrefix, subsec.Name, fmtAuthor(subsec))

				complexes := complexesByParent[subsec.Name]
				for k, cpx := range complexes {
					cpxPrefix := subsecChildPrefix + "├── "
					if k == len(complexes)-1 {
						cpxPrefix = subsecChildPrefix + "└── "
					}
					fmt.Printf("%s%s (complex)%s\n", cpxPrefix, cpx.Name, fmtAuthor(cpx))
				}
			}
		}
	}
	fmt.Println()

	return nil
}
