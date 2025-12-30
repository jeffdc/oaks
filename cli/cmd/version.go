package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Show CLI and API version information",
	Long: `Display the CLI version and, if connected to an API server,
the API server version as well.

Examples:
  oak version              # Show CLI version (and API version if configured)
  oak version --remote     # Force connection to API to show server version`,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Printf("CLI version: %s\n", client.CLIVersion)

		// If we have an API profile, try to get the API version
		if isRemoteMode() {
			apiClient, err := getAPIClient()
			if err != nil {
				fmt.Printf("API: connection error: %v\n", err)
				return nil
			}

			health, err := apiClient.Health()
			if err != nil {
				fmt.Printf("API [%s]: connection error: %v\n", resolvedProfile.Name, err)
				return nil
			}

			fmt.Printf("API [%s]: %s\n", resolvedProfile.Name, health.Version.API)
			if health.Version.MinClient != "" {
				fmt.Printf("API minimum client: %s\n", health.Version.MinClient)
			}
		} else {
			fmt.Println("API: not configured (local mode)")
		}

		return nil
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
