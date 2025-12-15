package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

var (
	idOnly     bool
	searchType string
)

var findCmd = &cobra.Command{
	Use:   "find <query>",
	Short: "Search for Oak entries or Sources",
	Long: `Search for Oak entries and/or Sources by name pattern.
Use -i/--id-only to output only IDs for pipelining.`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		query := args[0]

		database, err := getDB()
		if err != nil {
			return err
		}
		defer database.Close()

		searchOaks := searchType == "both" || searchType == "oak"
		searchSources := searchType == "both" || searchType == "source"

		if searchOaks {
			entries, err := database.SearchOakEntries(query)
			if err != nil {
				return err
			}

			if !idOnly && len(entries) > 0 {
				fmt.Println("Oak Entries:")
			}
			for _, name := range entries {
				if idOnly {
					fmt.Println(name)
				} else {
					fmt.Printf("  %s\n", name)
				}
			}
		}

		if searchSources {
			sources, err := database.SearchSources(query)
			if err != nil {
				return err
			}

			if !idOnly && len(sources) > 0 {
				if searchOaks {
					fmt.Println()
				}
				fmt.Println("Sources:")
			}
			for _, id := range sources {
				if idOnly {
					fmt.Println(id)
				} else {
					fmt.Printf("  %s\n", id)
				}
			}
		}

		return nil
	},
}

func init() {
	findCmd.Flags().BoolVarP(&idOnly, "id-only", "i", false, "Output only IDs (for pipelining)")
	findCmd.Flags().StringVarP(&searchType, "type", "t", "both", "Search type: oak, source, or both")
	rootCmd.AddCommand(findCmd)
}
