package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/editor"
	"github.com/jeff/oaks/cli/internal/models"
	"github.com/jeff/oaks/cli/internal/names"
)

var newCmd = &cobra.Command{
	Use:   "new <name>",
	Short: "Create a new Oak entry",
	Long: `Creates a new Oak entry by opening your $EDITOR with a template.

When connected to a remote API profile, prompts for confirmation before
creating. Local operations (default or --local) proceed without confirmation.

Examples:
  oak new alba             # Create in local database
  oak new alba --remote    # Create on remote API (with confirmation)
  oak new alba --local     # Force local creation`,
	Args: cobra.ExactArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		name := names.NormalizeHybridName(args[0])
		return runNew(name)
	},
}

func init() {
	rootCmd.AddCommand(newCmd)
}

func runNew(name string) error {
	apiClient, err := getAPIClient()
	if err != nil {
		return err
	}

	// Verify auth before doing any work (only for actual remote servers)
	if isActualRemote() {
		if err := apiClient.VerifyAuth(); err != nil {
			return fmt.Errorf("authentication failed: %w", err)
		}
	}

	validator, err := getSchema()
	if err != nil {
		return err
	}

	// Check if entry already exists
	_, err = apiClient.GetSpecies(name)
	if err == nil {
		if isActualRemote() {
			return fmt.Errorf("oak entry '%s' already exists on [%s]. Use 'oak edit' to modify it", name, apiClient.ProfileName())
		}
		return fmt.Errorf("oak entry '%s' already exists. Use 'oak edit' to modify it", name)
	}
	if !client.IsNotFoundError(err) {
		return fmt.Errorf("failed to check existing entry: %w", err)
	}

	entry, err := editor.NewOakEntry(name, validator)
	if err != nil {
		return err
	}

	// Confirm only for actual remote servers
	if isActualRemote() && !confirmRemoteOperation("Create", entry.ScientificName) {
		fmt.Println("Canceled")
		return nil
	}

	// Convert to API request and create
	req := modelToSpeciesRequest(entry)
	_, err = apiClient.CreateSpecies(req)
	if err != nil {
		return fmt.Errorf("failed to create entry: %w", err)
	}

	if isActualRemote() {
		fmt.Printf("Created oak entry on [%s]: %s\n", apiClient.ProfileName(), entry.ScientificName)
	} else {
		fmt.Printf("Created oak entry: %s\n", entry.ScientificName)
	}
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
