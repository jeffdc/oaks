package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var exportCmd = &cobra.Command{
	Use:   "export [output-file]",
	Short: "Export database to JSON",
	Long: `Export the oak database to JSON format for web app consumption.

The output follows the denormalized format documented in CLAUDE.md,
with taxonomy embedded in each species and data grouped by source.

If no output file is specified, writes to stdout.

Examples:
  oak export                      # Export to stdout
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
		if isActualRemote() {
			fmt.Fprintf(cmd.ErrOrStderr(), "Exported from [%s] to %s\n", apiClient.ProfileName(), outputPath)
		} else {
			fmt.Fprintf(cmd.ErrOrStderr(), "Exported to %s\n", outputPath)
		}
	}

	return nil
}
