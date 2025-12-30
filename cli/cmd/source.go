package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
)

var sourceCmd = &cobra.Command{
	Use:   "source",
	Short: "Manage sources",
	Long:  `Commands for managing source references.`,
}

var (
	srcNewType  string
	srcNewName  string
	srcNewURL   string
	srcNewDesc  string
	srcDelForce bool
)

var sourceNewCmd = &cobra.Command{
	Use:   "new",
	Short: "Create a new source",
	Long: `Create a new source entry.

If --type and --name are provided, creates non-interactively.
Otherwise, opens $EDITOR for interactive creation.

Examples:
  oak source new
  oak source new --type database --name "iNaturalist" --url "https://www.inaturalist.org"`,
	RunE: func(cmd *cobra.Command, args []string) error {
		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		var source *models.Source

		// If required flags are provided, create non-interactively
		if srcNewType != "" && srcNewName != "" {
			source = models.NewSource(srcNewType, srcNewName)
			if srcNewURL != "" {
				source.URL = &srcNewURL
			}
			if srcNewDesc != "" {
				source.Description = &srcNewDesc
			}
		} else if srcNewType != "" || srcNewName != "" {
			return fmt.Errorf("for non-interactive mode, both --type and --name are required")
		} else {
			// Interactive mode
			var err error
			source, err = editor.NewSource()
			if err != nil {
				return err
			}
		}

		id, err := database.InsertSource(source)
		if err != nil {
			return err
		}

		fmt.Printf("Created source with ID: %d\n", id)
		return nil
	},
}

var sourceEditCmd = &cobra.Command{
	Use:   "edit <id>",
	Short: "Edit an existing source",
	Long:  `Edit an existing source by opening it in your $EDITOR.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id, err := strconv.ParseInt(args[0], 10, 64)
		if err != nil {
			return fmt.Errorf("invalid source ID: %s", args[0])
		}

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		existing, err := database.GetSource(id)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("source with ID %d not found", id)
		}

		edited, err := editor.EditSource(existing)
		if err != nil {
			return err
		}

		// Preserve the ID (cannot be changed)
		edited.ID = existing.ID

		if err := database.UpdateSource(edited); err != nil {
			return err
		}

		fmt.Printf("Updated source: %d\n", edited.ID)
		return nil
	},
}

var sourceListCmd = &cobra.Command{
	Use:   "list",
	Short: "List all sources",
	Long:  `Display all existing sources in a table format.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runSourceList()
	},
}

func runSourceList() error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	sources, err := apiClient.ListSources()
	if err != nil {
		return fmt.Errorf("API error: %w", err)
	}

	// Convert to models for printing
	modelSources := make([]*models.Source, len(sources))
	for i, s := range sources {
		modelSources[i] = clientSourceToModel(s)
	}

	printSourceList(modelSources)
	return nil
}

func printSourceList(sources []*models.Source) {
	if len(sources) == 0 {
		fmt.Println("No sources found.")
		return
	}

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "ID\tTYPE\tNAME")
	fmt.Fprintln(w, "--\t----\t----")
	for _, s := range sources {
		name := s.Name
		if len(name) > 50 {
			name = name[:47] + "..."
		}
		fmt.Fprintf(w, "%d\t%s\t%s\n", s.ID, s.SourceType, name)
	}
	w.Flush()
}

var sourceShowCmd = &cobra.Command{
	Use:   "show <id>",
	Short: "Show source details",
	Long:  `Display detailed information about a specific source.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id, err := strconv.ParseInt(args[0], 10, 64)
		if err != nil {
			return fmt.Errorf("invalid source ID: %s", args[0])
		}
		return runSourceShow(id)
	},
}

func runSourceShow(id int64) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	source, err := apiClient.GetSource(id)
	if err != nil {
		if client.IsNotFoundError(err) {
			return fmt.Errorf("source with ID %d not found", id)
		}
		return fmt.Errorf("API error: %w", err)
	}

	printSource(clientSourceToModel(source))
	return nil
}

var sourceDeleteCmd = &cobra.Command{
	Use:   "delete <id>",
	Short: "Delete a source",
	Long: `Delete a source by ID.

Note: This will fail if the source is referenced by any species notes.
Delete those notes first, or use a different source.

Examples:
  oak source delete 5`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		id, err := strconv.ParseInt(args[0], 10, 64)
		if err != nil {
			return fmt.Errorf("invalid source ID: %s", args[0])
		}

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		source, err := database.GetSource(id)
		if err != nil {
			return err
		}
		if source == nil {
			return fmt.Errorf("source with ID %d not found", id)
		}

		// Confirm deletion unless --force
		if !srcDelForce {
			fmt.Printf("Delete source %d (%s)? (y/N): ", id, source.Name)
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

		if err := database.DeleteSource(id); err != nil {
			return err
		}

		fmt.Printf("Deleted source: %d\n", id)
		return nil
	},
}

func printSource(s *models.Source) {
	fmt.Printf("ID:          %d\n", s.ID)
	fmt.Printf("Type:        %s\n", s.SourceType)
	fmt.Printf("Name:        %s\n", s.Name)
	if s.Description != nil {
		fmt.Printf("Description: %s\n", *s.Description)
	}
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

// clientSourceToModel converts a client.Source to models.Source.
func clientSourceToModel(s *client.Source) *models.Source {
	return &models.Source{
		ID:          s.ID,
		SourceType:  s.SourceType,
		Name:        s.Name,
		Description: s.Description,
		Author:      s.Author,
		Year:        s.Year,
		URL:         s.URL,
		ISBN:        s.ISBN,
		DOI:         s.DOI,
		Notes:       s.Notes,
		License:     s.License,
		LicenseURL:  s.LicenseURL,
	}
}

func init() {
	sourceNewCmd.Flags().StringVar(&srcNewType, "type", "", "Source type (required for non-interactive)")
	sourceNewCmd.Flags().StringVar(&srcNewName, "name", "", "Source name (required for non-interactive)")
	sourceNewCmd.Flags().StringVar(&srcNewURL, "url", "", "Source URL (optional)")
	sourceNewCmd.Flags().StringVar(&srcNewDesc, "description", "", "Source description (optional)")

	sourceCmd.AddCommand(sourceNewCmd)
	sourceCmd.AddCommand(sourceEditCmd)
	sourceCmd.AddCommand(sourceListCmd)
	sourceCmd.AddCommand(sourceShowCmd)
	sourceCmd.AddCommand(sourceDeleteCmd)

	sourceDeleteCmd.Flags().BoolVar(&srcDelForce, "force", false, "Skip confirmation prompt")

	rootCmd.AddCommand(sourceCmd)
}
