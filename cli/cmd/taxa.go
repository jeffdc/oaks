package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
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

In remote mode (when an API profile is configured), fetches from the remote API.
In local mode (default), fetches from the local database.

Examples:
  oak taxa list
  oak taxa list subgenus
  oak taxa list section`,
	Args: cobra.MaximumNArgs(1),
	RunE: runTaxaList,
}

var taxaNewCmd = &cobra.Command{
	Use:   "new <name> --level <level>",
	Short: "Create a new taxon",
	Long: `Create a new taxon entry by opening it in your $EDITOR.

Levels: subgenus, section, subsection, complex

Examples:
  oak taxa new Lobatae --level section
  oak taxa new Albae --level subsection`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaNew,
}

var taxaEditCmd = &cobra.Command{
	Use:   "edit <name> --level <level>",
	Short: "Edit an existing taxon",
	Long: `Edit an existing taxon by opening it in your $EDITOR.

Examples:
  oak taxa edit Lobatae --level section
  oak taxa edit Quercus --level subgenus`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaEdit,
}

var taxaDeleteCmd = &cobra.Command{
	Use:   "delete <name> --level <level>",
	Short: "Delete a taxon",
	Long: `Delete a taxon from the reference table.

Examples:
  oak taxa delete Lobatae --level section`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaDelete,
}

var taxaShowCmd = &cobra.Command{
	Use:   "show <name> --level <level>",
	Short: "Show taxon details",
	Long: `Display detailed information about a specific taxon.

In remote mode (when an API profile is configured), fetches from the remote API.
In local mode (default), fetches from the local database.

Examples:
  oak taxa show Lobatae --level section
  oak taxa show Quercus --level subgenus`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaShow,
}

var taxaFindCmd = &cobra.Command{
	Use:   "find <query>",
	Short: "Search taxa by name",
	Long: `Search for taxa matching a name pattern.

Examples:
  oak taxa find alba
  oak taxa find Lobat`,
	Args: cobra.ExactArgs(1),
	RunE: runTaxaFind,
}

var (
	taxaImportClear bool
	taxaLevel       string
	taxaDeleteForce bool
)

func init() {
	rootCmd.AddCommand(taxaCmd)
	taxaCmd.AddCommand(taxaImportCmd)
	taxaCmd.AddCommand(taxaListCmd)
	taxaCmd.AddCommand(taxaNewCmd)
	taxaCmd.AddCommand(taxaEditCmd)
	taxaCmd.AddCommand(taxaDeleteCmd)
	taxaCmd.AddCommand(taxaShowCmd)
	taxaCmd.AddCommand(taxaFindCmd)

	taxaImportCmd.Flags().BoolVar(&taxaImportClear, "clear", false, "Clear existing taxa before import")

	// Level flag for new, edit, delete, show
	taxaNewCmd.Flags().StringVar(&taxaLevel, "level", "", "Taxon level (subgenus, section, subsection, complex)")
	_ = taxaNewCmd.MarkFlagRequired("level")

	taxaEditCmd.Flags().StringVar(&taxaLevel, "level", "", "Taxon level (subgenus, section, subsection, complex)")
	_ = taxaEditCmd.MarkFlagRequired("level")

	taxaDeleteCmd.Flags().StringVar(&taxaLevel, "level", "", "Taxon level (subgenus, section, subsection, complex)")
	_ = taxaDeleteCmd.MarkFlagRequired("level")
	taxaDeleteCmd.Flags().BoolVar(&taxaDeleteForce, "force", false, "Skip confirmation prompt")

	taxaShowCmd.Flags().StringVar(&taxaLevel, "level", "", "Taxon level (subgenus, section, subsection, complex)")
	_ = taxaShowCmd.MarkFlagRequired("level")
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
	if isRemoteMode() {
		return runTaxaListRemote(cmd)
	}
	return runTaxaListLocal(cmd)
}

func runTaxaListLocal(cmd *cobra.Command) error {
	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	taxa, err := database.ListTaxa(nil)
	if err != nil {
		return fmt.Errorf("failed to list taxa: %w", err)
	}

	printTaxaTree(cmd, taxa)
	return nil
}

func runTaxaListRemote(cmd *cobra.Command) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	resp, err := apiClient.ListTaxa(nil)
	if err != nil {
		return fmt.Errorf("API error: %w", err)
	}

	// Convert to models
	taxa := make([]*models.Taxon, len(resp.Data))
	for i, t := range resp.Data {
		taxa[i] = clientTaxonToModel(t)
	}

	printTaxaTree(cmd, taxa)
	return nil
}

func printTaxaTree(cmd *cobra.Command, taxa []*models.Taxon) {
	if len(taxa) == 0 {
		fmt.Fprintln(cmd.ErrOrStderr(), "No taxa found")
		return
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
			sectionComplexes := complexesByParent[sec.Name]
			totalChildren := len(subsections) + len(sectionComplexes)
			childIdx := 0

			for _, subsec := range subsections {
				subsecPrefix := secChildPrefix + "├── "
				subsecChildPrefix := secChildPrefix + "│   "
				childIdx++
				if childIdx == totalChildren {
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

			// Show complexes directly under section (no subsection)
			for _, cpx := range sectionComplexes {
				cpxPrefix := secChildPrefix + "├── "
				childIdx++
				if childIdx == totalChildren {
					cpxPrefix = secChildPrefix + "└── "
				}
				fmt.Printf("%s%s (complex)%s\n", cpxPrefix, cpx.Name, fmtAuthor(cpx))
			}
		}
	}
	fmt.Println()
}

// parseTaxonLevel converts a string to a TaxonLevel
func parseTaxonLevel(s string) (models.TaxonLevel, error) {
	switch strings.ToLower(s) {
	case "subgenus":
		return models.TaxonLevelSubgenus, nil
	case "section":
		return models.TaxonLevelSection, nil
	case "subsection":
		return models.TaxonLevelSubsection, nil
	case "complex":
		return models.TaxonLevelComplex, nil
	default:
		return "", fmt.Errorf("invalid level: %s (must be subgenus, section, subsection, or complex)", s)
	}
}

func runTaxaNew(cmd *cobra.Command, args []string) error {
	name := args[0]

	level, err := parseTaxonLevel(taxaLevel)
	if err != nil {
		return err
	}

	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Check if already exists
	existing, err := database.GetTaxon(name, level)
	if err != nil {
		return err
	}
	if existing != nil {
		return fmt.Errorf("taxon already exists: %s [%s]", name, level)
	}

	taxon, err := editor.NewTaxon(name, level)
	if err != nil {
		return err
	}

	if err := database.InsertTaxon(taxon); err != nil {
		return err
	}

	fmt.Printf("Created taxon: %s [%s]\n", taxon.Name, taxon.Level)
	return nil
}

func runTaxaEdit(cmd *cobra.Command, args []string) error {
	name := args[0]

	level, err := parseTaxonLevel(taxaLevel)
	if err != nil {
		return err
	}

	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	existing, err := database.GetTaxon(name, level)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("taxon not found: %s [%s]", name, level)
	}

	edited, err := editor.EditTaxon(existing)
	if err != nil {
		return err
	}

	if err := database.UpdateTaxon(edited); err != nil {
		return err
	}

	fmt.Printf("Updated taxon: %s [%s]\n", edited.Name, edited.Level)
	return nil
}

func runTaxaDelete(cmd *cobra.Command, args []string) error {
	name := args[0]

	level, err := parseTaxonLevel(taxaLevel)
	if err != nil {
		return err
	}

	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Check if exists
	existing, err := database.GetTaxon(name, level)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("taxon not found: %s [%s]", name, level)
	}

	// Confirm deletion unless --force
	if !taxaDeleteForce {
		fmt.Printf("Delete taxon %s [%s]? (y/N): ", name, level)
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" {
			fmt.Println("Canceled")
			return nil
		}
	}

	if err := database.DeleteTaxon(name, level); err != nil {
		return err
	}

	fmt.Printf("Deleted taxon: %s [%s]\n", name, level)
	return nil
}

func runTaxaShow(cmd *cobra.Command, args []string) error {
	name := args[0]

	level, err := parseTaxonLevel(taxaLevel)
	if err != nil {
		return err
	}

	if isRemoteMode() {
		return runTaxaShowRemote(name, level)
	}
	return runTaxaShowLocal(name, level)
}

func runTaxaShowLocal(name string, level models.TaxonLevel) error {
	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	taxon, err := database.GetTaxon(name, level)
	if err != nil {
		return err
	}
	if taxon == nil {
		return fmt.Errorf("taxon not found: %s [%s]", name, level)
	}

	printTaxon(taxon)
	return nil
}

func runTaxaShowRemote(name string, level models.TaxonLevel) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	// Note: client.GetTaxon takes level first, then name
	taxon, err := apiClient.GetTaxon(client.TaxonLevel(level), name)
	if err != nil {
		if client.IsNotFoundError(err) {
			return fmt.Errorf("taxon not found: %s [%s]", name, level)
		}
		return fmt.Errorf("API error: %w", err)
	}

	printTaxon(clientTaxonToModel(taxon))
	return nil
}

func printTaxon(t *models.Taxon) {
	fmt.Printf("Name:   %s\n", t.Name)
	fmt.Printf("Level:  %s\n", t.Level)
	if t.Parent != nil {
		fmt.Printf("Parent: %s\n", *t.Parent)
	}
	if t.Author != nil {
		fmt.Printf("Author: %s\n", *t.Author)
	}
	if t.Notes != nil && *t.Notes != "" {
		fmt.Printf("Notes:  %s\n", *t.Notes)
	}
	if len(t.Links) > 0 {
		fmt.Println("Links:")
		for _, link := range t.Links {
			fmt.Printf("  - %s: %s\n", link.Label, link.URL)
		}
	}
}

func runTaxaFind(cmd *cobra.Command, args []string) error {
	query := args[0]

	database, err := db.New(dbPath)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	taxa, err := database.SearchTaxa(query)
	if err != nil {
		return err
	}

	if len(taxa) == 0 {
		fmt.Println("No taxa found matching:", query)
		return nil
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "NAME\tLEVEL\tPARENT\tAUTHOR")
	fmt.Fprintln(w, "----\t-----\t------\t------")
	for _, t := range taxa {
		parent := ""
		if t.Parent != nil {
			parent = *t.Parent
		}
		author := ""
		if t.Author != nil {
			author = *t.Author
		}
		fmt.Fprintf(w, "%s\t%s\t%s\t%s\n", t.Name, t.Level, parent, author)
	}
	w.Flush()

	return nil
}

// clientTaxonToModel converts a client.Taxon to models.Taxon.
func clientTaxonToModel(t *client.Taxon) *models.Taxon {
	// Convert links
	var links []models.TaxonLink
	if len(t.Links) > 0 {
		links = make([]models.TaxonLink, len(t.Links))
		for i, l := range t.Links {
			links[i] = models.TaxonLink{Label: l.Label, URL: l.URL}
		}
	}

	return &models.Taxon{
		Name:   t.Name,
		Level:  models.TaxonLevel(t.Level),
		Parent: t.Parent,
		Author: t.Author,
		Notes:  t.Notes,
		Links:  links,
	}
}
