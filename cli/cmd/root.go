package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/schema"
)

var (
	dbPath     string
	schemaPath string
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
