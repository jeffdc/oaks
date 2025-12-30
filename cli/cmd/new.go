package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/editor"
)

var newCmd = &cobra.Command{
	Use:   "new <name>",
	Short: "Create a new Oak entry",
	Long:  `Creates a new Oak entry by opening your $EDITOR with a template.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		validator, err := getSchema()
		if err != nil {
			return err
		}

		// Check if entry already exists
		existing, err := database.GetOakEntry(name)
		if err != nil {
			return err
		}
		if existing != nil {
			return fmt.Errorf("oak entry '%s' already exists. Use 'oak edit' to modify it", name)
		}

		entry, err := editor.NewOakEntry(name, validator)
		if err != nil {
			return err
		}

		if err := database.SaveOakEntry(entry); err != nil {
			return err
		}

		fmt.Printf("Created oak entry: %s\n", entry.ScientificName)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(newCmd)
}
