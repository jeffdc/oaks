package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"text/tabwriter"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/jeff/oaks/cli/internal/names"
)

var (
	noteSourceID    int64
	noteDeleteForce bool
)

var noteCmd = &cobra.Command{
	Use:   "note <species>",
	Short: "Add or edit source-attributed notes for a species",
	Long: `Add or edit source-attributed notes for a species.

This command opens your $EDITOR with a YAML template for entering
source-specific data about a species (leaves, range, local names, etc.).

If notes already exist for this species+source combination, they will
be loaded for editing. Otherwise, a new blank template is created.

The species must already exist in the database. Use 'oak new' first
to create the species entry if needed.

Examples:
  oak note phellos --source-id 3
  oak note "× bebbiana" --source-id 2`,
	Args: cobra.ExactArgs(1),
	RunE: runNote,
}

var noteListCmd = &cobra.Command{
	Use:   "list <species>",
	Short: "List all source notes for a species",
	Long:  `Display all source-attributed notes for a species.`,
	Args:  cobra.ExactArgs(1),
	RunE:  runNoteList,
}

var noteDeleteCmd = &cobra.Command{
	Use:   "delete <species> --source-id <id>",
	Short: "Delete source notes for a species",
	Long: `Delete source-attributed notes for a species.

Examples:
  oak note delete phellos --source-id 2
  oak note delete alba --source-id 3 --force`,
	Args: cobra.ExactArgs(1),
	RunE: runNoteDelete,
}

func init() {
	noteCmd.Flags().Int64Var(&noteSourceID, "source-id", 0, "Source ID to attribute the notes to (required)")
	_ = noteCmd.MarkFlagRequired("source-id")

	noteDeleteCmd.Flags().Int64Var(&noteSourceID, "source-id", 0, "Source ID of the notes to delete (required)")
	_ = noteDeleteCmd.MarkFlagRequired("source-id")
	noteDeleteCmd.Flags().BoolVar(&noteDeleteForce, "force", false, "Skip confirmation prompt")

	noteCmd.AddCommand(noteListCmd)
	noteCmd.AddCommand(noteDeleteCmd)
	rootCmd.AddCommand(noteCmd)
}

func runNote(cmd *cobra.Command, args []string) error {
	speciesName := names.NormalizeHybridName(args[0])

	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	// Verify species exists
	entry, err := database.GetOakEntry(speciesName)
	if err != nil {
		return err
	}
	if entry == nil {
		return fmt.Errorf("species '%s' not found. Create it first with: oak new %s", speciesName, speciesName)
	}

	// Verify source exists
	source, err := database.GetSource(noteSourceID)
	if err != nil {
		return err
	}
	if source == nil {
		return fmt.Errorf("source with ID %d not found. Create it first with: oak source new", noteSourceID)
	}

	// Check for existing notes
	existing, err := database.GetSpeciesSourceBySourceID(speciesName, noteSourceID)
	if err != nil {
		return err
	}

	var ss *models.SpeciesSource
	isNew := false
	if existing != nil {
		ss = existing
		fmt.Printf("Editing existing notes for %s from %s\n", speciesName, source.Name)
	} else {
		ss = models.NewSpeciesSource(speciesName, noteSourceID)
		isNew = true
		fmt.Printf("Adding new notes for %s from %s\n", speciesName, source.Name)
	}

	// Open editor
	edited, err := editor.EditSpeciesSource(ss, source.Name)
	if err != nil {
		return err
	}

	// Save
	if err := database.SaveSpeciesSource(edited); err != nil {
		return err
	}

	if isNew {
		fmt.Printf("Created notes for %s (source: %s)\n", speciesName, source.Name)
	} else {
		fmt.Printf("Updated notes for %s (source: %s)\n", speciesName, source.Name)
	}

	return nil
}

func runNoteList(cmd *cobra.Command, args []string) error {
	speciesName := names.NormalizeHybridName(args[0])

	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	// Verify species exists
	entry, err := database.GetOakEntry(speciesName)
	if err != nil {
		return err
	}
	if entry == nil {
		return fmt.Errorf("species '%s' not found", speciesName)
	}

	// Get all sources for this species
	sources, err := database.GetSpeciesSources(speciesName)
	if err != nil {
		return err
	}

	if len(sources) == 0 {
		fmt.Printf("No source notes found for %s\n", speciesName)
		return nil
	}

	fmt.Printf("Source notes for %s:\n\n", speciesName)

	for _, ss := range sources {
		// Get source name
		source, err := database.GetSource(ss.SourceID)
		if err != nil {
			return err
		}

		preferred := ""
		if ss.IsPreferred {
			preferred = " (preferred)"
		}

		fmt.Printf("=== Source: %s (ID: %d)%s ===\n", source.Name, ss.SourceID, preferred)

		w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)

		if len(ss.LocalNames) > 0 {
			fmt.Fprintf(w, "Local names:\t%v\n", ss.LocalNames)
		}
		if ss.Range != nil && *ss.Range != "" {
			fmt.Fprintf(w, "Range:\t%s\n", truncate(*ss.Range))
		}
		if ss.GrowthHabit != nil && *ss.GrowthHabit != "" {
			fmt.Fprintf(w, "Growth habit:\t%s\n", truncate(*ss.GrowthHabit))
		}
		if ss.Leaves != nil && *ss.Leaves != "" {
			fmt.Fprintf(w, "Leaves:\t%s\n", truncate(*ss.Leaves))
		}
		if ss.Flowers != nil && *ss.Flowers != "" {
			fmt.Fprintf(w, "Flowers:\t%s\n", truncate(*ss.Flowers))
		}
		if ss.Fruits != nil && *ss.Fruits != "" {
			fmt.Fprintf(w, "Fruits:\t%s\n", truncate(*ss.Fruits))
		}
		if ss.Bark != nil && *ss.Bark != "" {
			fmt.Fprintf(w, "Bark:\t%s\n", truncate(*ss.Bark))
		}
		if ss.Twigs != nil && *ss.Twigs != "" {
			fmt.Fprintf(w, "Twigs:\t%s\n", truncate(*ss.Twigs))
		}
		if ss.Buds != nil && *ss.Buds != "" {
			fmt.Fprintf(w, "Buds:\t%s\n", truncate(*ss.Buds))
		}
		if ss.HardinessHabitat != nil && *ss.HardinessHabitat != "" {
			fmt.Fprintf(w, "Hardiness/habitat:\t%s\n", truncate(*ss.HardinessHabitat))
		}
		if ss.Miscellaneous != nil && *ss.Miscellaneous != "" {
			fmt.Fprintf(w, "Miscellaneous:\t%s\n", truncate(*ss.Miscellaneous))
		}
		if ss.URL != nil && *ss.URL != "" {
			fmt.Fprintf(w, "URL:\t%s\n", *ss.URL)
		}

		w.Flush()
		fmt.Println()
	}

	return nil
}

func truncate(s string) string {
	const maxLen = 80
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}

func runNoteDelete(cmd *cobra.Command, args []string) error {
	speciesName := names.NormalizeHybridName(args[0])

	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	// Verify species exists
	entry, err := database.GetOakEntry(speciesName)
	if err != nil {
		return err
	}
	if entry == nil {
		return fmt.Errorf("species '%s' not found", speciesName)
	}

	// Verify source exists
	source, err := database.GetSource(noteSourceID)
	if err != nil {
		return err
	}
	if source == nil {
		return fmt.Errorf("source with ID %d not found", noteSourceID)
	}

	// Check notes exist
	existing, err := database.GetSpeciesSourceBySourceID(speciesName, noteSourceID)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("no notes found for %s from source %d (%s)", speciesName, noteSourceID, source.Name)
	}

	// Confirm deletion unless --force
	if !noteDeleteForce {
		fmt.Printf("Delete notes for %s from %s (source %d)? (y/N): ", speciesName, source.Name, noteSourceID)
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

	if err := database.DeleteSpeciesSource(speciesName, noteSourceID); err != nil {
		return err
	}

	fmt.Printf("Deleted notes for %s (source: %s)\n", speciesName, source.Name)
	return nil
}
