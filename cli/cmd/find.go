package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/names"
)

const searchTypeBoth = "both"

var (
	idOnly     bool
	searchType string
	findLimit  int
)

var findCmd = &cobra.Command{
	Use:   "find <query>",
	Short: "Search for Oak entries or Sources",
	Long: `Search for Oak entries and/or Sources by name pattern.
Use -i/--id-only to output only IDs for pipelining.

In remote mode (when an API profile is configured), searches the remote API.
In local mode (default), searches the local database.

Examples:
  oak find alba             # Search local database
  oak find alba --remote    # Search remote API
  oak find alba --local     # Force local search`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		query := names.NormalizeHybridName(args[0])

		if isRemoteMode() {
			return runFindRemote(query)
		}
		return runFindLocal(query)
	},
}

func init() {
	findCmd.Flags().BoolVarP(&idOnly, "id-only", "i", false, "Output only IDs (for pipelining)")
	findCmd.Flags().StringVarP(&searchType, "type", "t", searchTypeBoth, "Search type: oak, source, or both")
	findCmd.Flags().IntVar(&findLimit, "limit", 100, "Maximum number of results (remote mode only)")
	rootCmd.AddCommand(findCmd)
}

func runFindLocal(query string) error {
	database, err := getDB()
	if err != nil {
		return err
	}
	defer database.Close()

	searchOaks := searchType == searchTypeBoth || searchType == "oak"
	searchSources := searchType == searchTypeBoth || searchType == "source"

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
				fmt.Printf("  %d\n", id)
			}
		}
	}

	return nil
}

func runFindRemote(query string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	searchOaks := searchType == searchTypeBoth || searchType == "oak"
	searchSources := searchType == searchTypeBoth || searchType == "source"

	if searchOaks {
		result, err := apiClient.SearchSpecies(query, findLimit)
		if err != nil {
			return fmt.Errorf("API error: %w", err)
		}

		if !idOnly && result.Count > 0 {
			fmt.Printf("Oak Entries (%d results):\n", result.Count)
		}
		for _, entry := range result.Data {
			if idOnly {
				fmt.Println(entry.ScientificName)
			} else {
				fmt.Printf("  %s\n", entry.ScientificName)
			}
		}
	}

	if searchSources {
		sources, err := apiClient.ListSources()
		if err != nil {
			return fmt.Errorf("API error: %w", err)
		}

		// Filter sources by query (simple substring match for consistency with local)
		var matched []int64
		for _, s := range sources {
			if containsIgnoreCase(s.Name, query) {
				matched = append(matched, s.ID)
			}
		}

		if !idOnly && len(matched) > 0 {
			if searchOaks {
				fmt.Println()
			}
			fmt.Println("Sources:")
		}
		for _, id := range matched {
			if idOnly {
				fmt.Println(id)
			} else {
				fmt.Printf("  %d\n", id)
			}
		}
	}

	return nil
}

// containsIgnoreCase checks if s contains substr (case-insensitive).
func containsIgnoreCase(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr ||
			substr == "" ||
			findSubstringIgnoreCase(s, substr))
}

func findSubstringIgnoreCase(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if equalIgnoreCase(s[i:i+len(substr)], substr) {
			return true
		}
	}
	return false
}

func equalIgnoreCase(a, b string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := 0; i < len(a); i++ {
		ca, cb := a[i], b[i]
		if ca >= 'A' && ca <= 'Z' {
			ca += 'a' - 'A'
		}
		if cb >= 'A' && cb <= 'Z' {
			cb += 'a' - 'A'
		}
		if ca != cb {
			return false
		}
	}
	return true
}
