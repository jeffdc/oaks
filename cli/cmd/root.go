package cmd

import (
	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/schema"
	"github.com/spf13/cobra"
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
