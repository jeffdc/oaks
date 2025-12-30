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

When connected to a remote API profile, shows the profile name in confirmation.
Use --force to skip all confirmation prompts.

Examples:
  oak delete alba             # Delete from local database (with confirmation)
  oak delete alba --remote    # Delete from remote API (with confirmation)
  oak delete alba --local     # Force local deletion (with confirmation)
  oak delete alba --force     # Skip confirmation prompt`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := names.NormalizeHybridName(args[0])
		return runDelete(name)
	},
}

func init() {
	deleteCmd.Flags().BoolVarP(&forceDelete, "force", "f", false, "Skip confirmation prompt")
	rootCmd.AddCommand(deleteCmd)
}

func runDelete(name string) error {
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

	// Verify entry exists
	_, err = apiClient.GetSpecies(name)
	if err != nil {
		if client.IsNotFoundError(err) {
			if isActualRemote() {
				return fmt.Errorf("oak entry '%s' not found on [%s]", name, apiClient.ProfileName())
			}
			return fmt.Errorf("oak entry '%s' not found", name)
		}
		return fmt.Errorf("failed to fetch entry: %w", err)
	}

	// Confirmation prompt
	if !forceDelete {
		var prompt string
		if isActualRemote() {
			prompt = fmt.Sprintf("Delete %s from [%s]? (y/N): ", name, apiClient.ProfileName())
		} else {
			prompt = fmt.Sprintf("Are you sure you want to delete '%s'? [y/N]: ", name)
		}
		fmt.Print(prompt)
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

	if err := apiClient.DeleteSpecies(name); err != nil {
		return fmt.Errorf("failed to delete entry: %w", err)
	}

	if isActualRemote() {
		fmt.Printf("Deleted oak entry from [%s]: %s\n", apiClient.ProfileName(), name)
	} else {
		fmt.Printf("Deleted oak entry: %s\n", name)
	}
	return nil
}
