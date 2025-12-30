package export

import (
	"fmt"
	"time"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/models"
)

// Build creates an export File from the database.
func Build(database *db.Database) (*File, error) {
	// Get all oak entries
	entries, err := database.ListOakEntries()
	if err != nil {
		return nil, fmt.Errorf("failed to list oak entries: %w", err)
	}

	// Get all sources for lookup
	sources, err := database.ListSources()
	if err != nil {
		return nil, fmt.Errorf("failed to list sources: %w", err)
	}
	sourceMap := make(map[int64]*models.Source)
	for _, s := range sources {
		sourceMap[s.ID] = s
	}

	// Build export data with metadata
	now := time.Now().UTC()
	exportData := &File{
		Metadata: Metadata{
			Version:      now.Format("2006-01-02T15:04:05Z"), // ISO 8601 UTC timestamp as version
			ExportedAt:   now.Format(time.RFC3339),
			SpeciesCount: len(entries),
		},
		Sources: make([]Source, 0, len(sources)),
		Species: make([]Species, 0, len(entries)),
	}

	// Build top-level sources array with full metadata
	for _, s := range sources {
		exportData.Sources = append(exportData.Sources, Source{
			ID:          s.ID,
			SourceType:  s.SourceType,
			Name:        s.Name,
			Description: s.Description,
			Author:      s.Author,
			Year:        s.Year,
			URL:         s.URL,
			ISBN:        s.ISBN,
			DOI:         s.DOI,
			Notes:       s.Notes,
			License:     s.License,
			LicenseURL:  s.LicenseURL,
		})
	}

	for _, entry := range entries {
		// Convert external links to export format
		var exportLinks []ExternalLink
		if len(entry.ExternalLinks) > 0 {
			exportLinks = make([]ExternalLink, len(entry.ExternalLinks))
			for i, link := range entry.ExternalLinks {
				exportLinks[i] = ExternalLink{
					Name: link.Name,
					URL:  link.URL,
					Logo: link.Logo,
				}
			}
		}

		species := Species{
			Name:               entry.ScientificName,
			Author:             entry.Author,
			IsHybrid:           entry.IsHybrid,
			ConservationStatus: entry.ConservationStatus,
			Taxonomy: Taxonomy{
				Genus:      "Quercus",
				Subgenus:   entry.Subgenus,
				Section:    entry.Section,
				Subsection: entry.Subsection,
				Complex:    entry.Complex,
			},
			Parent1:             entry.Parent1,
			Parent2:             entry.Parent2,
			Hybrids:             nonEmptySlice(entry.Hybrids),
			CloselyRelatedTo:    nonEmptySlice(entry.CloselyRelatedTo),
			SubspeciesVarieties: nonEmptySlice(entry.SubspeciesVarieties),
			Synonyms:            nonEmptySlice(entry.Synonyms),
			ExternalLinks:       exportLinks,
			Sources:             []SourceData{},
		}

		// Get species_sources data for this entry
		speciesSources, err := database.GetSpeciesSources(entry.ScientificName)
		if err != nil {
			return nil, fmt.Errorf("failed to get species sources for %s: %w", entry.ScientificName, err)
		}

		// Convert species_sources to export format
		for _, ss := range speciesSources {
			sd := SourceData{
				SourceID:         ss.SourceID,
				SourceName:       fmt.Sprintf("Source %d", ss.SourceID),
				IsPreferred:      ss.IsPreferred,
				LocalNames:       nonEmptySlice(ss.LocalNames),
				Range:            ss.Range,
				GrowthHabit:      ss.GrowthHabit,
				Leaves:           ss.Leaves,
				Flowers:          ss.Flowers,
				Fruits:           ss.Fruits,
				Bark:             ss.Bark,
				Twigs:            ss.Twigs,
				Buds:             ss.Buds,
				HardinessHabitat: ss.HardinessHabitat,
				Miscellaneous:    ss.Miscellaneous,
				URL:              ss.URL,
			}

			if source, ok := sourceMap[ss.SourceID]; ok {
				sd.SourceName = source.Name
				sd.SourceURL = source.URL
				sd.License = source.License
				sd.LicenseURL = source.LicenseURL
			}

			species.Sources = append(species.Sources, sd)
		}

		exportData.Species = append(exportData.Species, species)
	}

	return exportData, nil
}

func nonEmptySlice(s []string) []string {
	if len(s) == 0 {
		return nil
	}
	return s
}
