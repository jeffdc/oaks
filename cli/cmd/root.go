package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/config"
	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/embedded"
	"github.com/jeff/oaks/cli/internal/schema"
)

var (
	dbPath           string
	schemaPath       string
	profileFlag      string
	forceLocal       bool
	forceRemote      bool
	skipVersionCheck bool

	// Resolved configuration (loaded on init)
	cfg             *config.Config
	resolvedProfile *config.ResolvedProfile

	// Embedded server for --local mode
	embeddedServer *embedded.Server
)

var rootCmd = &cobra.Command{
	Use:   "oak",
	Short: "Oak Compendium CLI - Manage taxonomic data for oak species",
	Long: `Oak Compendium CLI is a tool for managing taxonomic and identification
data for oak (Quercus) species. It provides commands for creating, editing,
searching, and importing oak species data with source attribution.`,
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&dbPath, "database", "d", "oak_compendium.db", "Path to the database file")
	rootCmd.PersistentFlags().StringVarP(&schemaPath, "schema", "s", "schema/oak_schema.json", "Path to the schema file")
	rootCmd.PersistentFlags().StringVarP(&profileFlag, "profile", "p", "", "API profile to use (from ~/.oak/config.yaml)")
	rootCmd.PersistentFlags().BoolVar(&forceLocal, "local", false, "Use embedded API server for local database operations")
	rootCmd.PersistentFlags().BoolVar(&forceRemote, "remote", false, "Force remote API mode (requires API profile)")
	rootCmd.PersistentFlags().BoolVar(&skipVersionCheck, "skip-version-check", false, "Skip API version compatibility check")

	// Load config and resolve profile before any command runs
	rootCmd.PersistentPreRunE = func(cmd *cobra.Command, args []string) error {
		// Validate --local and --remote are mutually exclusive
		if forceLocal && forceRemote {
			return fmt.Errorf("--local and --remote flags are mutually exclusive")
		}

		var err error
		cfg, err = config.Load("")
		if err != nil {
			return fmt.Errorf("failed to load config: %w", err)
		}

		// If --local is set, always use embedded server (even if a profile is configured)
		if forceLocal {
			embeddedServer, err = embedded.Start(embedded.Config{
				DBPath: dbPath,
				Quiet:  true,
			})
			if err != nil {
				return fmt.Errorf("failed to start embedded server: %w", err)
			}

			resolvedProfile = &config.ResolvedProfile{
				Name:   "embedded",
				URL:    embeddedServer.URL(),
				Key:    embeddedServer.APIKey(),
				Source: config.SourceEmbedded,
			}
			return nil
		}

		resolvedProfile, err = config.Resolve(cfg, profileFlag)
		if err != nil {
			return err
		}

		// If --remote is set but no API is configured, error
		if forceRemote && resolvedProfile.IsLocal() {
			return fmt.Errorf("--remote requires API configuration. Create ~/.oak/config.yaml with profiles or set OAK_API_URL")
		}

		// If no remote profile resolved, start embedded server for local operations
		// This allows all commands to use the unified API client path
		if resolvedProfile.IsLocal() {
			embeddedServer, err = embedded.Start(embedded.Config{
				DBPath: dbPath,
				Quiet:  true,
			})
			if err != nil {
				return fmt.Errorf("failed to start embedded server: %w", err)
			}

			resolvedProfile = &config.ResolvedProfile{
				Name:   "local",
				URL:    embeddedServer.URL(),
				Key:    embeddedServer.APIKey(),
				Source: config.SourceEmbedded,
			}
		}

		return nil
	}

	// Shutdown embedded server after command completes
	rootCmd.PersistentPostRunE = func(cmd *cobra.Command, args []string) error {
		if embeddedServer != nil {
			if err := embeddedServer.Shutdown(); err != nil {
				return fmt.Errorf("failed to shutdown embedded server: %w", err)
			}
			embeddedServer = nil
		}
		return nil
	}
}

// getDB creates a new database connection
func getDB() (*db.Database, error) {
	return db.New(dbPath)
}

// getSchema creates a new schema validator
func getSchema() (*schema.Validator, error) {
	return schema.FromFile(schemaPath)
}

// readImportFile validates and reads a file for import.
// Validates that the path exists, is a regular file, and is readable.
func readImportFile(filePath string) ([]byte, error) {
	info, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("file not found: %s", filePath)
		}
		return nil, fmt.Errorf("cannot access file: %w", err)
	}

	if info.IsDir() {
		return nil, fmt.Errorf("path is a directory, not a file: %s", filePath)
	}

	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("path is not a regular file: %s", filePath)
	}

	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	return data, nil
}

// isRemoteMode returns true if operating against a remote API.
// Note: With embedded server now used by default, this always returns true.
// Use isActualRemote() to check if connecting to an actual remote server.
func isRemoteMode() bool {
	return resolvedProfile != nil && !resolvedProfile.IsLocal()
}

// isActualRemote returns true if operating against an actual remote server
// (not the embedded local server). Use this for confirmation prompts.
func isActualRemote() bool {
	return resolvedProfile != nil && resolvedProfile.Source != config.SourceEmbedded
}

// getAPIClient creates a new API client from the resolved profile.
// Returns an error if operating in local mode.
func getAPIClient() (*client.Client, error) {
	if resolvedProfile == nil || resolvedProfile.IsLocal() {
		return nil, fmt.Errorf("cannot create API client: operating in local mode")
	}

	opts := []client.Option{}
	if skipVersionCheck {
		opts = append(opts, client.WithSkipVersionCheck(true))
	}

	return client.New(resolvedProfile, opts...)
}

// confirmRemoteOperation prompts the user to confirm a destructive operation
// when operating against a remote profile. Returns true if confirmed.
// For local operations, returns true without prompting.
func confirmRemoteOperation(action, resource string) bool {
	if resolvedProfile == nil || resolvedProfile.IsLocal() {
		return true
	}

	fmt.Printf("%s %s on [%s]? (y/N): ", action, resource, resolvedProfile.Name)

	reader := bufio.NewReader(os.Stdin)
	response, err := reader.ReadString('\n')
	if err != nil {
		return false // Treat read errors as "no"
	}

	response = strings.TrimSpace(strings.ToLower(response))
	return response == "y" || response == "yes"
}

// getProfile returns the resolved profile. Useful for commands that need
// to check whether they're operating locally or remotely.
func getProfile() *config.ResolvedProfile {
	return resolvedProfile
}

// getConfig returns the loaded configuration.
func getConfig() *config.Config {
	return cfg
}
