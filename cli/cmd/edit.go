package cmd

import (
	"fmt"

	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/spf13/cobra"
)

var editCmd = &cobra.Command{
	Use:   "edit <name>",
	Short: "Edit an existing Oak entry",
	Long:  `Edit an existing Oak entry by opening it in your $EDITOR.`,
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

		existing, err := database.GetOakEntry(name)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("oak entry '%s' not found", name)
		}

		entry, err := editor.EditOakEntry(existing, validator)
		if err != nil {
			return err
		}

		if err := database.SaveOakEntry(entry); err != nil {
			return err
		}

		fmt.Printf("Updated oak entry: %s\n", entry.ScientificName)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(editCmd)
}
