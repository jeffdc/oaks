package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/names"
)

var (
	forceDelete bool
)

var deleteCmd = &cobra.Command{
	Use:   "delete <name>",
	Short: "Delete an Oak entry",
	Long: `Delete an Oak entry from the database. Requires confirmation unless --force is used.

In remote mode (when an API profile is configured), deletes the entry
from the remote API with profile confirmation. In local mode (default),
deletes from the local database.

Examples:
  oak delete alba             # Delete from local database
  oak delete alba --remote    # Delete from remote API
  oak delete alba --local     # Force local deletion
  oak delete alba --force     # Skip confirmation prompt`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := names.NormalizeHybridName(args[0])

		if isRemoteMode() {
			return runDeleteRemote(name)
		}
		return runDeleteLocal(name)
	},
}

func init() {
	deleteCmd.Flags().BoolVarP(&forceDelete, "force", "f", false, "Skip confirmation prompt")
	rootCmd.AddCommand(deleteCmd)
}

func runDeleteLocal(name string) error {
	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	existing, err := database.GetOakEntry(name)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("oak entry '%s' not found", name)
	}

	if !forceDelete {
		fmt.Printf("Are you sure you want to delete '%s'? [y/N]: ", name)
		reader := bufio.NewReader(os.Stdin)
		response, err := reader.ReadString('\n')
		if err != nil {
			return err
		}
		response = strings.TrimSpace(strings.ToLower(response))
		if response != "y" && response != "yes" { //nolint:goconst // user-facing confirmation
			fmt.Println("Canceled")
			return nil
		}
	}

	if err := database.DeleteOakEntry(name); err != nil {
		return err
	}

	fmt.Printf("Deleted oak entry: %s\n", name)
	return nil
}

func runDeleteRemote(name string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	// Verify entry exists on remote
	_, err = apiClient.GetSpecies(name)
	if err != nil {
		if client.IsNotFoundError(err) {
			return fmt.Errorf("oak entry '%s' not found on [%s]", name, apiClient.ProfileName())
		}
		return fmt.Errorf("API error: %w", err)
	}

	// Confirmation prompt - always shows profile name for remote deletions
	if !forceDelete {
		fmt.Printf("Delete %s from [%s]? (y/N): ", name, apiClient.ProfileName())
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

	if err := apiClient.DeleteSpecies(name); err != nil {
		return fmt.Errorf("API error: %w", err)
	}

	fmt.Printf("Deleted oak entry from [%s]: %s\n", apiClient.ProfileName(), name)
	return nil
}
