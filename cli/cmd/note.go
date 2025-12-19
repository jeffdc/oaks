package cmd

import (
	"fmt"
	"os"
	"text/tabwriter"

	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/spf13/cobra"
)

var noteSourceID int64

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

func init() {
	noteCmd.Flags().Int64Var(&noteSourceID, "source-id", 0, "Source ID to attribute the notes to (required)")
	noteCmd.MarkFlagRequired("source-id")

	noteCmd.AddCommand(noteListCmd)
	rootCmd.AddCommand(noteCmd)
}

func runNote(cmd *cobra.Command, args []string) error {
	speciesName := args[0]

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
	speciesName := args[0]

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
			fmt.Fprintf(w, "Range:\t%s\n", truncate(*ss.Range, 80))
		}
		if ss.GrowthHabit != nil && *ss.GrowthHabit != "" {
			fmt.Fprintf(w, "Growth habit:\t%s\n", truncate(*ss.GrowthHabit, 80))
		}
		if ss.Leaves != nil && *ss.Leaves != "" {
			fmt.Fprintf(w, "Leaves:\t%s\n", truncate(*ss.Leaves, 80))
		}
		if ss.Flowers != nil && *ss.Flowers != "" {
			fmt.Fprintf(w, "Flowers:\t%s\n", truncate(*ss.Flowers, 80))
		}
		if ss.Fruits != nil && *ss.Fruits != "" {
			fmt.Fprintf(w, "Fruits:\t%s\n", truncate(*ss.Fruits, 80))
		}
		if ss.Bark != nil && *ss.Bark != "" {
			fmt.Fprintf(w, "Bark:\t%s\n", truncate(*ss.Bark, 80))
		}
		if ss.Twigs != nil && *ss.Twigs != "" {
			fmt.Fprintf(w, "Twigs:\t%s\n", truncate(*ss.Twigs, 80))
		}
		if ss.Buds != nil && *ss.Buds != "" {
			fmt.Fprintf(w, "Buds:\t%s\n", truncate(*ss.Buds, 80))
		}
		if ss.HardinessHabitat != nil && *ss.HardinessHabitat != "" {
			fmt.Fprintf(w, "Hardiness/habitat:\t%s\n", truncate(*ss.HardinessHabitat, 80))
		}
		if ss.Miscellaneous != nil && *ss.Miscellaneous != "" {
			fmt.Fprintf(w, "Miscellaneous:\t%s\n", truncate(*ss.Miscellaneous, 80))
		}
		if ss.URL != nil && *ss.URL != "" {
			fmt.Fprintf(w, "URL:\t%s\n", *ss.URL)
		}

		w.Flush()
		fmt.Println()
	}

	return nil
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen-3] + "..."
}
