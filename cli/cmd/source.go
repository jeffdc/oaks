package cmd

import (
	"fmt"
	"text/tabwriter"
	"os"

	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
)

var sourceCmd = &cobra.Command{
	Use:   "source",
	Short: "Manage sources",
	Long:  `Commands for managing source references.`,
}

var (
	srcNewID   string
	srcNewType string
	srcNewName string
	srcNewURL  string
)

var sourceNewCmd = &cobra.Command{
	Use:   "new",
	Short: "Create a new source",
	Long: `Create a new source entry.

If --id, --type, and --name are provided, creates non-interactively.
Otherwise, opens $EDITOR for interactive creation.

Examples:
  oak source new
  oak source new --id inat --type database --name "iNaturalist" --url "https://www.inaturalist.org"`,
	RunE: func(cmd *cobra.Command, args []string) error {
		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		var source *models.Source

		// If required flags are provided, create non-interactively
		if srcNewID != "" && srcNewType != "" && srcNewName != "" {
			source = models.NewSource(srcNewID, srcNewType, srcNewName)
			if srcNewURL != "" {
				source.URL = &srcNewURL
			}
		} else if srcNewID != "" || srcNewType != "" || srcNewName != "" {
			return fmt.Errorf("for non-interactive mode, all of --id, --type, and --name are required")
		} else {
			// Interactive mode
			var err error
			source, err = editor.NewSource()
			if err != nil {
				return err
			}
		}

		if err := database.InsertSource(source); err != nil {
			return err
		}

		fmt.Printf("Created source: %s\n", source.SourceID)
		return nil
	},
}

var sourceEditCmd = &cobra.Command{
	Use:   "edit <id>",
	Short: "Edit an existing source",
	Long:  `Edit an existing source by opening it in your $EDITOR.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		sourceID := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		existing, err := database.GetSource(sourceID)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("source '%s' not found", sourceID)
		}

		edited, err := editor.EditSource(existing)
		if err != nil {
			return err
		}

		// If the source_id changed, we need to handle that
		if edited.SourceID != existing.SourceID {
			// For now, just update in place (source_id is immutable)
			edited.SourceID = existing.SourceID
			fmt.Fprintln(os.Stderr, "Warning: source_id cannot be changed. Keeping original ID.")
		}

		if err := database.UpdateSource(edited); err != nil {
			return err
		}

		fmt.Printf("Updated source: %s\n", edited.SourceID)
		return nil
	},
}

var sourceListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all sources",
	Long:  `Display all existing sources in a table format.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		sources, err := database.ListSources()
		if err != nil {
			return err
		}

		if len(sources) == 0 {
			fmt.Println("No sources found.")
			return nil
		}

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
		fmt.Fprintln(w, "ID\tTYPE\tNAME")
		fmt.Fprintln(w, "--\t----\t----")
		for _, s := range sources {
			name := s.Name
			if len(name) > 50 {
				name = name[:47] + "..."
			}
			fmt.Fprintf(w, "%s\t%s\t%s\n", s.SourceID, s.SourceType, name)
		}
		w.Flush()

		return nil
	},
}

var sourceShowCmd = &cobra.Command{
	Use:   "show <id>",
	Short: "Show source details",
	Long:  `Display detailed information about a specific source.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		sourceID := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		source, err := database.GetSource(sourceID)
		if err != nil {
			return err
		}
		if source == nil {
			return fmt.Errorf("source '%s' not found", sourceID)
		}

		printSource(source)
		return nil
	},
}

func printSource(s *models.Source) {
	fmt.Printf("Source ID:   %s\n", s.SourceID)
	fmt.Printf("Type:        %s\n", s.SourceType)
	fmt.Printf("Name:        %s\n", s.Name)
	if s.Author != nil {
		fmt.Printf("Author:      %s\n", *s.Author)
	}
	if s.Year != nil {
		fmt.Printf("Year:        %d\n", *s.Year)
	}
	if s.URL != nil {
		fmt.Printf("URL:         %s\n", *s.URL)
	}
	if s.ISBN != nil {
		fmt.Printf("ISBN:        %s\n", *s.ISBN)
	}
	if s.DOI != nil {
		fmt.Printf("DOI:         %s\n", *s.DOI)
	}
	if s.Notes != nil {
		fmt.Printf("Notes:       %s\n", *s.Notes)
	}
}

func init() {
	sourceNewCmd.Flags().StringVar(&srcNewID, "id", "", "Source ID (required for non-interactive)")
	sourceNewCmd.Flags().StringVar(&srcNewType, "type", "", "Source type (required for non-interactive)")
	sourceNewCmd.Flags().StringVar(&srcNewName, "name", "", "Source name (required for non-interactive)")
	sourceNewCmd.Flags().StringVar(&srcNewURL, "url", "", "Source URL (optional)")

	sourceCmd.AddCommand(sourceNewCmd)
	sourceCmd.AddCommand(sourceEditCmd)
	sourceCmd.AddCommand(sourceListCmd)
	sourceCmd.AddCommand(sourceShowCmd)
	rootCmd.AddCommand(sourceCmd)
}
