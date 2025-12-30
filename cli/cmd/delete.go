package cmd

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/spf13/cobra"
)

var (
	forceDelete bool
)

var deleteCmd = &cobra.Command{
	Use:   "delete <name>",
	Short: "Delete an Oak entry",
	Long:  `Delete an Oak entry from the database. Requires confirmation unless --force is used.`,
	Args:  cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		existing, err := database.GetOakEntry(name)
		if err != nil {
			return err
		}
		if existing == nil {
			return fmt.Errorf("oak entry '%s' not found", name)
		}

		if !forceDelete {
			fmt.Printf("Are you sure you want to delete '%s'? [y/N]: ", name)
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

		if err := database.DeleteOakEntry(name); err != nil {
			return err
		}

		fmt.Printf("Deleted oak entry: %s\n", name)
		return nil
	},
}

func init() {
	deleteCmd.Flags().BoolVarP(&forceDelete, "force", "f", false, "Skip confirmation prompt")
	rootCmd.AddCommand(deleteCmd)
}
