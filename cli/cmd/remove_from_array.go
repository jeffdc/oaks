package cmd

import (
	"fmt"
	"strings"

	"github.com/spf13/cobra"
)

var (
	arrayField string
	arrayValue string
)

// validArrayFields lists the fields that support array removal
var validArrayFields = []string{"hybrids", "synonyms", "closely_related_to", "subspecies_varieties"}

var removeFromArrayCmd = &cobra.Command{
	Use:   "remove-from-array <species>",
	Short: "Remove a value from an array field",
	Long: `Remove a value from one of the array fields on a species entry.

Supported fields: hybrids, synonyms, closely_related_to, subspecies_varieties

Examples:
  oak remove-from-array alba --field=hybrids --value=saulei
  oak remove-from-array robur --field=synonyms --value="pedunculata"`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		speciesName := args[0]

		// Validate field
		validField := false
		for _, f := range validArrayFields {
			if arrayField == f {
				validField = true
				break
			}
		}
		if !validField {
			return fmt.Errorf("invalid field '%s'. Valid fields: %s", arrayField, strings.Join(validArrayFields, ", "))
		}

		if arrayValue == "" {
			return fmt.Errorf("--value is required")
		}

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		// Get existing entry
		entry, err := database.GetOakEntry(speciesName)
		if err != nil {
			return err
		}
		if entry == nil {
			return fmt.Errorf("species '%s' not found", speciesName)
		}

		// Find and remove the value from the appropriate field
		var found bool
		switch arrayField {
		case "hybrids":
			entry.Hybrids, found = removeFromSlice(entry.Hybrids, arrayValue)
		case "synonyms":
			entry.Synonyms, found = removeFromSlice(entry.Synonyms, arrayValue)
		case "closely_related_to":
			entry.CloselyRelatedTo, found = removeFromSlice(entry.CloselyRelatedTo, arrayValue)
		case "subspecies_varieties":
			entry.SubspeciesVarieties, found = removeFromSlice(entry.SubspeciesVarieties, arrayValue)
		}

		if !found {
			return fmt.Errorf("value '%s' not found in %s for species '%s'", arrayValue, arrayField, speciesName)
		}

		// Save the updated entry
		if err := database.SaveOakEntry(entry); err != nil {
			return err
		}

		fmt.Printf("Removed '%s' from %s for species '%s'\n", arrayValue, arrayField, speciesName)
		return nil
	},
}

// removeFromSlice removes the first occurrence of value from slice
// Returns the modified slice and whether the value was found
func removeFromSlice(slice []string, value string) ([]string, bool) {
	for i, v := range slice {
		if v == value {
			return append(slice[:i], slice[i+1:]...), true
		}
	}
	return slice, false
}

func init() {
	removeFromArrayCmd.Flags().StringVarP(&arrayField, "field", "f", "", "Array field to remove from (required)")
	removeFromArrayCmd.Flags().StringVarP(&arrayValue, "value", "v", "", "Value to remove (required)")
	removeFromArrayCmd.MarkFlagRequired("field")
	removeFromArrayCmd.MarkFlagRequired("value")
	rootCmd.AddCommand(removeFromArrayCmd)
}
