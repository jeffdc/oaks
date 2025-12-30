package cmd

import (
	"fmt"
	"sort"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/config"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Manage CLI configuration",
	Long:  `View and manage CLI configuration including API profiles.`,
}

var configShowCmd = &cobra.Command{
	Use:   "show",
	Short: "Show active configuration",
	Long: `Display the currently active profile configuration.

Shows the resolved profile (from flag, environment, or config file),
the API URL, and the resolution source.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		profile := getProfile()
		if profile == nil {
			return fmt.Errorf("configuration not loaded")
		}

		fmt.Println("Active Configuration:")
		fmt.Println()

		if profile.IsLocal() {
			fmt.Println("  Mode:    local database")
			fmt.Println("  Source:  (no API profile configured)")
		} else {
			fmt.Printf("  Profile: %s\n", profile.Name)
			fmt.Printf("  URL:     %s\n", profile.URL)
			fmt.Printf("  Key:     %s\n", config.MaskKey(profile.Key))
			fmt.Printf("  Source:  %s\n", formatSource(profile.Source))
		}

		return nil
	},
}

var configListCmd = &cobra.Command{
	Use:   "list",
	Short: "List configured profiles",
	Long: `Display all configured API profiles from ~/.oak/config.yaml.

The default profile (if set) is marked with an asterisk (*).`,
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg := getConfig()
		if cfg == nil {
			return fmt.Errorf("configuration not loaded")
		}

		if len(cfg.Profiles) == 0 {
			fmt.Println("No profiles configured.")
			fmt.Println()
			fmt.Println("Create ~/.oak/config.yaml with profiles:")
			fmt.Println()
			fmt.Println("  profiles:")
			fmt.Println("    prod:")
			fmt.Println("      url: https://api.oakcompendium.com")
			fmt.Println("      key: your-api-key")
			fmt.Println("    local-server:")
			fmt.Println("      url: http://localhost:8080")
			fmt.Println("      key: dev-key")
			fmt.Println()
			fmt.Println("  # default_profile: prod  # Uncomment to default to remote")
			return nil
		}

		// Sort profile names for consistent output
		names := cfg.ProfileNames()
		sort.Strings(names)

		fmt.Println("Configured Profiles:")
		fmt.Println()

		for _, name := range names {
			profile := cfg.Profiles[name]
			marker := "  "
			if name == cfg.DefaultProfile {
				marker = "* "
			}
			fmt.Printf("%s%s\n", marker, name)
			fmt.Printf("    URL: %s\n", profile.URL)
			fmt.Printf("    Key: %s\n", config.MaskKey(profile.Key))
		}

		if cfg.DefaultProfile != "" {
			fmt.Println()
			fmt.Printf("Default: %s\n", cfg.DefaultProfile)
		}

		return nil
	},
}

// formatSource returns a human-readable description of the profile resolution source.
func formatSource(source string) string {
	switch source {
	case config.SourceFlag:
		return "--profile flag"
	case config.SourceEnv:
		return "OAK_PROFILE environment variable"
	case config.SourceConfig:
		return "default_profile in config file"
	case config.SourceLegacyEnv:
		return "OAK_API_URL environment variable"
	case config.SourceLocal:
		return "local database (default)"
	default:
		return source
	}
}

func init() {
	rootCmd.AddCommand(configCmd)
	configCmd.AddCommand(configShowCmd)
	configCmd.AddCommand(configListCmd)
}
