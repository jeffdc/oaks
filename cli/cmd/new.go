package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
)

var newCmd = &cobra.Command{
	Use:   "new <name>",
	Short: "Create a new Oak entry",
	Long: `Creates a new Oak entry by opening your $EDITOR with a template.

In remote mode (when an API profile is configured), creates the entry
on the remote API after confirmation. In local mode (default), creates
the entry in the local database.

Examples:
  oak new alba             # Create in local database
  oak new alba --remote    # Create on remote API
  oak new alba --local     # Force local creation`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := args[0]

		if isRemoteMode() {
			return runNewRemote(name)
		}
		return runNewLocal(name)
	},
}

func init() {
	rootCmd.AddCommand(newCmd)
}

func runNewLocal(name string) error {
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
}

func runNewRemote(name string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	validator, err := getSchema()
	if err != nil {
		return err
	}

	// Check if entry already exists on remote
	_, err = apiClient.GetSpecies(name)
	if err == nil {
		return fmt.Errorf("oak entry '%s' already exists on [%s]. Use 'oak edit' to modify it", name, apiClient.ProfileName())
	}
	if !client.IsNotFoundError(err) {
		return fmt.Errorf("API error: %w", err)
	}

	entry, err := editor.NewOakEntry(name, validator)
	if err != nil {
		return err
	}

	// Confirm remote creation
	if !confirmRemoteOperation("Create", entry.ScientificName) {
		fmt.Println("Canceled")
		return nil
	}

	// Convert to API request
	req := modelToSpeciesRequest(entry)
	_, err = apiClient.CreateSpecies(req)
	if err != nil {
		return fmt.Errorf("API error: %w", err)
	}

	fmt.Printf("Created oak entry on [%s]: %s\n", apiClient.ProfileName(), entry.ScientificName)
	return nil
}

// modelToSpeciesRequest converts an internal OakEntry to an API SpeciesRequest.
func modelToSpeciesRequest(e *models.OakEntry) *client.SpeciesRequest {
	return &client.SpeciesRequest{
		ScientificName:     e.ScientificName,
		Author:             e.Author,
		IsHybrid:           e.IsHybrid,
		ConservationStatus: e.ConservationStatus,
		Subgenus:           e.Subgenus,
		Section:            e.Section,
		Subsection:         e.Subsection,
		Complex:            e.Complex,
		Parent1:            e.Parent1,
		Parent2:            e.Parent2,
		Synonyms:           e.Synonyms,
	}
}

// clientEntryToModel converts an API OakEntry to an internal OakEntry.
func clientEntryToModel(e *client.OakEntry) *models.OakEntry {
	return &models.OakEntry{
		ScientificName:      e.ScientificName,
		Author:              e.Author,
		IsHybrid:            e.IsHybrid,
		ConservationStatus:  e.ConservationStatus,
		Subgenus:            e.Subgenus,
		Section:             e.Section,
		Subsection:          e.Subsection,
		Complex:             e.Complex,
		Parent1:             e.Parent1,
		Parent2:             e.Parent2,
		Hybrids:             e.Hybrids,
		CloselyRelatedTo:    e.CloselyRelatedTo,
		SubspeciesVarieties: e.SubspeciesVarieties,
		Synonyms:            e.Synonyms,
		ExternalLinks:       clientLinksToModel(e.ExternalLinks),
	}
}

// clientLinksToModel converts API ExternalLinks to internal ExternalLinks.
func clientLinksToModel(links []client.ExternalLink) []models.ExternalLink {
	if links == nil {
		return nil
	}
	result := make([]models.ExternalLink, len(links))
	for i, l := range links {
		result[i] = models.ExternalLink{
			Name: l.Name,
			URL:  l.URL,
			Logo: l.Logo,
		}
	}
	return result
}
