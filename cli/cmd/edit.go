package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/editor"
)

var editCmd = &cobra.Command{
	Use:   "edit <name>",
	Short: "Edit an existing Oak entry",
	Long: `Edit an existing Oak entry by opening it in your $EDITOR.

In remote mode (when an API profile is configured), fetches the entry
from the remote API, opens it in the editor, and pushes changes back
after confirmation. In local mode (default), edits the local database.

Examples:
  oak edit alba             # Edit in local database
  oak edit alba --remote    # Edit on remote API
  oak edit alba --local     # Force local edit`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]

		if isRemoteMode() {
			return runEditRemote(name)
		}
		return runEditLocal(name)
	},
}

func init() {
	rootCmd.AddCommand(editCmd)
}

func runEditLocal(name string) error {
	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	validator, err := getSchema()
	if err != nil {
		return err
	}

	existing, err := database.GetOakEntry(name)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("oak entry '%s' not found", name)
	}

	entry, err := editor.EditOakEntry(existing, validator)
	if err != nil {
		return err
	}

	if err := database.SaveOakEntry(entry); err != nil {
		return err
	}

	fmt.Printf("Updated oak entry: %s\n", entry.ScientificName)
	return nil
}

func runEditRemote(name string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	validator, err := getSchema()
	if err != nil {
		return err
	}

	// Fetch entry from remote
	remoteEntry, err := apiClient.GetSpecies(name)
	if err != nil {
		if client.IsNotFoundError(err) {
			return fmt.Errorf("oak entry '%s' not found on [%s]", name, apiClient.ProfileName())
		}
		return fmt.Errorf("API error: %w", err)
	}

	// Convert to internal model for editing
	existing := clientEntryToModel(remoteEntry)

	entry, err := editor.EditOakEntry(existing, validator)
	if err != nil {
		return err
	}

	// Confirm remote update
	if !confirmRemoteOperation("Update", entry.ScientificName) {
		fmt.Println("Canceled")
		return nil
	}

	// Convert to API request and update
	req := modelToSpeciesRequest(entry)
	_, err = apiClient.UpdateSpecies(name, req)
	if err != nil {
		return fmt.Errorf("API error: %w", err)
	}

	fmt.Printf("Updated oak entry on [%s]: %s\n", apiClient.ProfileName(), entry.ScientificName)
	return nil
}
