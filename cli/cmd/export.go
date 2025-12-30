package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/export"
)

var exportCmd = &cobra.Command{
	Use:   "export [output-file]",
	Short: "Export database to JSON",
	Long: `Export the oak database to JSON format for web app consumption.

The output follows the denormalized format documented in CLAUDE.md,
with taxonomy embedded in each species and data grouped by source.

If no output file is specified, writes to stdout.

In remote mode (when an API profile is configured or --local is used),
fetches data from the API. Otherwise exports from the local database.

Examples:
  oak export                      # Export from local database to stdout
  oak export quercus_data.json    # Export to file
  oak export -o data.json         # Export to file using flag
  oak export --local data.json    # Export via embedded API
  oak export --remote data.json   # Export from remote API`,
	Args: cobra.MaximumNArgs(1),
	RunE: runExport,
}

var exportOutput string

func init() {
	rootCmd.AddCommand(exportCmd)
	exportCmd.Flags().StringVarP(&exportOutput, "output", "o", "", "Output file path")
}

func runExport(cmd *cobra.Command, args []string) error {
	// Determine output path
	outputPath := exportOutput
	if len(args) > 0 {
		outputPath = args[0]
	}

	if isRemoteMode() {
		return runExportRemote(cmd, outputPath)
	}
	return runExportLocal(cmd, outputPath)
}

func runExportLocal(cmd *cobra.Command, outputPath string) error {
	database, err := getDB()
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Build export data
	exportData, err := export.Build(database)
	if err != nil {
		return err
	}

	// Marshal to JSON
	jsonData, err := json.MarshalIndent(exportData, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}

	// Write output
	if outputPath == "" {
		fmt.Println(string(jsonData))
	} else {
		if err := os.WriteFile(outputPath, jsonData, 0o644); err != nil { //nolint:gosec // export must be readable
			return fmt.Errorf("failed to write output file: %w", err)
		}
		fmt.Fprintf(cmd.ErrOrStderr(), "Exported %d species to %s\n", exportData.Metadata.SpeciesCount, outputPath)
	}

	return nil
}

func runExportRemote(cmd *cobra.Command, outputPath string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	// Write output
	if outputPath == "" {
		// Export directly to stdout
		data, err := apiClient.Export()
		if err != nil {
			return fmt.Errorf("API error: %w", err)
		}
		fmt.Println(string(data))
	} else {
		// Export to file
		file, err := os.Create(outputPath)
		if err != nil {
			return fmt.Errorf("failed to create output file: %w", err)
		}
		defer file.Close()

		if err := apiClient.ExportToWriter(file); err != nil {
			return fmt.Errorf("API error: %w", err)
		}
		fmt.Fprintf(cmd.ErrOrStderr(), "Exported from [%s] to %s\n", apiClient.ProfileName(), outputPath)
	}

	return nil
}
