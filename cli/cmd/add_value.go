package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var addValueCmd = &cobra.Command{
	Use:   "add-value <field> <value>",
	Short: "Add a new enumeration value to a field",
	Long: `Add a new permitted enumeration value to a validated field.
For example: oak add-value leaf_shape "deeply lobed"`,
	Args: cobra.ExactArgs(2),
	RunE: func(cmd *cobra.Command, args []string) error {
		field := args[0]
		value := args[1]

		validator, err := getSchema()
		if err != nil {
			return err
		}

		if err := validator.AddEnumValue(field, value); err != nil {
			return err
		}

		fmt.Printf("Added value '%s' to field '%s'\n", value, field)
		return nil
	},
}

func init() {
	rootCmd.AddCommand(addValueCmd)
}
