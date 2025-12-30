package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/names"
)

var editCmd = &cobra.Command{
	Use:   "edit <name>",
	Short: "Edit an existing Oak entry",
	Long: `Edit an existing Oak entry by opening it in your $EDITOR.

When connected to a remote API profile, prompts for confirmation before
saving changes. Local operations (default or --local) proceed without confirmation.

Examples:
  oak edit alba             # Edit in local database
  oak edit alba --remote    # Edit on remote API (with confirmation)
  oak edit alba --local     # Force local edit`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := names.NormalizeHybridName(args[0])
		return runEdit(name)
	},
}

func init() {
	rootCmd.AddCommand(editCmd)
}

func runEdit(name string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	// Verify auth before doing any work (only for actual remote servers)
	if isActualRemote() {
		if err := apiClient.VerifyAuth(); err != nil {
			return fmt.Errorf("authentication failed: %w", err)
		}
	}

	validator, err := getSchema()
	if err != nil {
		return err
	}

	// Fetch entry
	remoteEntry, err := apiClient.GetSpecies(name)
	if err != nil {
		if client.IsNotFoundError(err) {
			if isActualRemote() {
				return fmt.Errorf("oak entry '%s' not found on [%s]", name, apiClient.ProfileName())
			}
			return fmt.Errorf("oak entry '%s' not found", name)
		}
		return fmt.Errorf("failed to fetch entry: %w", err)
	}

	// Convert to internal model for editing
	existing := clientEntryToModel(remoteEntry)

	entry, err := editor.EditOakEntry(existing, validator)
	if err != nil {
		return err
	}

	// Confirm only for actual remote servers
	if isActualRemote() && !confirmRemoteOperation("Update", entry.ScientificName) {
		fmt.Println("Canceled")
		return nil
	}

	// Convert to API request and update
	req := modelToSpeciesRequest(entry)
	_, err = apiClient.UpdateSpecies(name, req)
	if err != nil {
		return fmt.Errorf("failed to update entry: %w", err)
	}

	if isActualRemote() {
		fmt.Printf("Updated oak entry on [%s]: %s\n", apiClient.ProfileName(), entry.ScientificName)
	} else {
		fmt.Printf("Updated oak entry: %s\n", entry.ScientificName)
	}
	return nil
}
