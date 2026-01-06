package db

import (
	"testing"

	"github.com/jeff/oaks/api/internal/models"
)

func TestGetStats(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Empty database
	stats, err := db.GetStats()
	if err != nil {
		t.Fatalf("GetStats failed: %v", err)
	}
	if stats.SpeciesCount != 0 {
		t.Errorf("expected 0 species, got %d", stats.SpeciesCount)
	}
	if stats.HybridCount != 0 {
		t.Errorf("expected 0 hybrids, got %d", stats.HybridCount)
	}
	if stats.TaxaCount != 0 {
		t.Errorf("expected 0 taxa, got %d", stats.TaxaCount)
	}
	if stats.SourceCount != 0 {
		t.Errorf("expected 0 sources, got %d", stats.SourceCount)
	}

	// Add species (non-hybrid)
	species := &models.Species{
		ScientificName:      "alba",
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(species); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Add hybrid
	parent1 := "alba"
	hybrid := &models.Species{
		ScientificName:      "× bebbiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveSpecies (hybrid) failed: %v", err)
	}

	// Add taxon
	taxon := &models.Taxon{
		Name:  "Quercus",
		Level: models.TaxonLevelSubgenus,
		Links: []models.TaxonLink{},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Add source
	source := &models.Source{
		SourceType: "website",
		Name:       "Test Source",
	}
	if _, err := db.InsertSource(source); err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	// Verify counts
	stats, err = db.GetStats()
	if err != nil {
		t.Fatalf("GetStats failed: %v", err)
	}
	if stats.SpeciesCount != 1 {
		t.Errorf("expected 1 species, got %d", stats.SpeciesCount)
	}
	if stats.HybridCount != 1 {
		t.Errorf("expected 1 hybrid, got %d", stats.HybridCount)
	}
	if stats.TaxaCount != 1 {
		t.Errorf("expected 1 taxon, got %d", stats.TaxaCount)
	}
	if stats.SourceCount != 1 {
		t.Errorf("expected 1 source, got %d", stats.SourceCount)
	}
}

func TestGetSpeciesWithSources(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create species
	species := &models.Species{
		ScientificName:      "alba",
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(species); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create sources
	source1 := &models.Source{SourceType: "website", Name: "Source 1"}
	source2 := &models.Source{SourceType: "book", Name: "Source 2"}
	id1, _ := db.InsertSource(source1)
	id2, _ := db.InsertSource(source2)

	// Create species sources
	ss1 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       id1,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	ss1.Range = strPtr("Eastern North America")

	ss2 := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       id2,
		LocalNames:     []string{"eastern white oak"},
		IsPreferred:    false,
	}
	ss2.Leaves = strPtr("Lobed leaves")

	if err := db.SaveSpeciesSource(ss1); err != nil {
		t.Fatalf("SaveSpeciesSource 1 failed: %v", err)
	}
	if err := db.SaveSpeciesSource(ss2); err != nil {
		t.Fatalf("SaveSpeciesSource 2 failed: %v", err)
	}

	// Get species with sources
	result, err := db.GetSpeciesWithSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesWithSources failed: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.ScientificName != "alba" {
		t.Errorf("expected 'alba', got '%s'", result.ScientificName)
	}
	if len(result.Sources) != 2 {
		t.Errorf("expected 2 sources, got %d", len(result.Sources))
	}

	// Preferred source should be first
	if !result.Sources[0].IsPreferred {
		t.Error("first source should be preferred")
	}
	if result.Sources[0].SourceName != "Source 1" {
		t.Errorf("expected first source to be 'Source 1', got '%s'", result.Sources[0].SourceName)
	}
}

func TestGetSpeciesWithSourcesNotFound(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	result, err := db.GetSpeciesWithSources("nonexistent")
	if err != nil {
		t.Fatalf("GetSpeciesWithSources failed: %v", err)
	}
	if result != nil {
		t.Errorf("expected nil for non-existent species, got %+v", result)
	}
}

func TestGetSpeciesWithSourcesNoSources(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create species without sources
	species := &models.Species{
		ScientificName:      "alba",
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(species); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	result, err := db.GetSpeciesWithSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesWithSources failed: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.Sources == nil {
		t.Error("expected empty slice, got nil")
	}
	if len(result.Sources) != 0 {
		t.Errorf("expected 0 sources, got %d", len(result.Sources))
	}
}

func TestGetHybridsReferencingParent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create parent species
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	rubra := &models.Species{
		ScientificName:      "rubra",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	for _, s := range []*models.Species{alba, rubra} {
		if err := db.SaveSpecies(s); err != nil {
			t.Fatalf("SaveSpecies failed: %v", err)
		}
	}

	// Create hybrids
	parent1 := "alba"
	parent2 := "rubra"
	hybrid1 := &models.Species{
		ScientificName:      "× bebbiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Parent2:             &parent2,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	hybrid2 := &models.Species{
		ScientificName:      "× jackiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	for _, s := range []*models.Species{hybrid1, hybrid2} {
		if err := db.SaveSpecies(s); err != nil {
			t.Fatalf("SaveSpecies failed: %v", err)
		}
	}

	// Find hybrids referencing alba
	hybrids, err := db.GetHybridsReferencingParent("alba")
	if err != nil {
		t.Fatalf("GetHybridsReferencingParent failed: %v", err)
	}
	if len(hybrids) != 2 {
		t.Errorf("expected 2 hybrids referencing alba, got %d", len(hybrids))
	}

	// Find hybrids referencing rubra
	hybrids, err = db.GetHybridsReferencingParent("rubra")
	if err != nil {
		t.Fatalf("GetHybridsReferencingParent failed: %v", err)
	}
	if len(hybrids) != 1 {
		t.Errorf("expected 1 hybrid referencing rubra, got %d", len(hybrids))
	}

	// Find hybrids referencing non-parent
	hybrids, err = db.GetHybridsReferencingParent("stellata")
	if err != nil {
		t.Fatalf("GetHybridsReferencingParent failed: %v", err)
	}
	if len(hybrids) != 0 {
		t.Errorf("expected 0 hybrids referencing stellata, got %d", len(hybrids))
	}
}

func TestUnifiedSearch(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create species
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{"white oak synonym"},
		ExternalLinks:       []models.ExternalLink{},
	}
	alba.Author = strPtr("L. 1753")
	if err := db.SaveSpecies(alba); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create taxon
	taxon := &models.Taxon{
		Name:  "Quercus",
		Level: models.TaxonLevelSubgenus,
		Links: []models.TaxonLink{},
	}
	if err := db.InsertTaxon(taxon); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Create source
	source := &models.Source{
		SourceType: "website",
		Name:       "Oak Reference Database",
	}
	source.Author = strPtr("Dr. Oak")
	if _, err := db.InsertSource(source); err != nil {
		t.Fatalf("InsertSource failed: %v", err)
	}

	// Search for "alba" - should find species
	results, err := db.UnifiedSearch("alba", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Species) != 1 {
		t.Errorf("expected 1 species for 'alba', got %d", len(results.Species))
	}
	if results.Counts.Species != 1 {
		t.Errorf("expected species count 1, got %d", results.Counts.Species)
	}

	// Search for "Quercus" - should find taxon
	results, err = db.UnifiedSearch("Quercus", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Taxa) != 1 {
		t.Errorf("expected 1 taxon for 'Quercus', got %d", len(results.Taxa))
	}

	// Search for "Oak" - should find source
	results, err = db.UnifiedSearch("Oak", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Sources) != 1 {
		t.Errorf("expected 1 source for 'Oak', got %d", len(results.Sources))
	}

	// Search for author
	results, err = db.UnifiedSearch("Dr. Oak", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Sources) != 1 {
		t.Errorf("expected 1 source for author search, got %d", len(results.Sources))
	}
}

func TestUnifiedSearchWithLimit(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create multiple species
	for i := 0; i < 15; i++ {
		species := &models.Species{
			ScientificName:      "alba" + string(rune('a'+i)),
			IsHybrid:            false,
			Hybrids:             []string{},
			CloselyRelatedTo:    []string{},
			SubspeciesVarieties: []string{},
			Synonyms:            []string{},
			ExternalLinks:       []models.ExternalLink{},
		}
		if err := db.SaveSpecies(species); err != nil {
			t.Fatalf("SaveSpecies failed: %v", err)
		}
	}

	// Search with limit of 5
	results, err := db.UnifiedSearch("alba", 5)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Species) != 5 {
		t.Errorf("expected 5 species (limit), got %d", len(results.Species))
	}
}

func TestUnifiedSearchEmpty(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	results, err := db.UnifiedSearch("nonexistent", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if results.Species == nil {
		t.Error("expected empty slice for species, got nil")
	}
	if results.Taxa == nil {
		t.Error("expected empty slice for taxa, got nil")
	}
	if results.Sources == nil {
		t.Error("expected empty slice for sources, got nil")
	}
	if results.Counts.Total != 0 {
		t.Errorf("expected total count 0, got %d", results.Counts.Total)
	}
}

func TestUnifiedSearchByLocalNames(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create species
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(alba); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create source and species source with local names
	source := &models.Source{SourceType: "website", Name: "Test Source"}
	sourceID, _ := db.InsertSource(source)

	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak", "eastern white oak"},
		IsPreferred:    true,
	}
	if err := db.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("SaveSpeciesSource failed: %v", err)
	}

	// Search by local name
	results, err := db.UnifiedSearch("white oak", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Species) != 1 {
		t.Errorf("expected 1 species for local name search, got %d", len(results.Species))
	}
}

func TestUnifiedSearchBySynonym(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create species with synonym
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{"alba var. repanda"},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(alba); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Search by synonym
	results, err := db.UnifiedSearch("repanda", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Species) != 1 {
		t.Errorf("expected 1 species for synonym search, got %d", len(results.Species))
	}
}

func TestGetSpeciesReferences(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create alba as a reference target
	alba := &models.Species{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(alba); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create hybrid with alba as parent1
	parent1 := "alba"
	parent2 := "rubra"
	hybrid := &models.Species{
		ScientificName:      "× bebbiana",
		IsHybrid:            true,
		Parent1:             &parent1,
		Parent2:             &parent2,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(hybrid); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Create species with alba in closely_related_to
	related := &models.Species{
		ScientificName:      "stellata",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{"alba"},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}
	if err := db.SaveSpecies(related); err != nil {
		t.Fatalf("SaveSpecies failed: %v", err)
	}

	// Get references to alba
	refs, err := db.GetSpeciesReferences("alba")
	if err != nil {
		t.Fatalf("GetSpeciesReferences failed: %v", err)
	}

	// Should have hybrid (parent1) and stellata (closely_related_to)
	// Note: alba itself now has "× bebbiana" in its hybrids list due to bidirectional update
	if len(refs) < 2 {
		t.Errorf("expected at least 2 references, got %d", len(refs))
	}

	// Check that we have a parent1 reference
	hasParent1 := false
	for _, ref := range refs {
		if ref.ScientificName == "× bebbiana" && ref.ReferenceType == "parent1" {
			hasParent1 = true
		}
	}
	if !hasParent1 {
		t.Error("expected parent1 reference from × bebbiana")
	}

	// Check for closely_related_to reference
	hasRelated := false
	for _, ref := range refs {
		if ref.ScientificName == "stellata" && ref.ReferenceType == "closely_related_to" {
			hasRelated = true
		}
	}
	if !hasRelated {
		t.Error("expected closely_related_to reference from stellata")
	}
}

func TestGetSpeciesReferencesEmpty(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	refs, err := db.GetSpeciesReferences("nonexistent")
	if err != nil {
		t.Fatalf("GetSpeciesReferences failed: %v", err)
	}
	if refs == nil {
		t.Error("expected empty slice, got nil")
	}
	if len(refs) != 0 {
		t.Errorf("expected 0 references, got %d", len(refs))
	}
}

func TestComputeTaxaPaths(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Create taxonomy hierarchy
	// Subgenus: Quercus -> Section: Lobatae -> Subsection: Phellos -> Complex: phellos
	subgenus := &models.Taxon{Name: "Quercus", Level: models.TaxonLevelSubgenus, Links: []models.TaxonLink{}}
	if err := db.InsertTaxon(subgenus); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	parent1 := "Quercus"
	section := &models.Taxon{Name: "Lobatae", Level: models.TaxonLevelSection, Parent: &parent1, Links: []models.TaxonLink{}}
	if err := db.InsertTaxon(section); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	parent2 := "Lobatae"
	subsection := &models.Taxon{Name: "Phellos", Level: models.TaxonLevelSubsection, Parent: &parent2, Links: []models.TaxonLink{}}
	if err := db.InsertTaxon(subsection); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	parent3 := "Phellos"
	complex := &models.Taxon{Name: "phelloscomplex", Level: models.TaxonLevelComplex, Parent: &parent3, Links: []models.TaxonLink{}}
	if err := db.InsertTaxon(complex); err != nil {
		t.Fatalf("InsertTaxon failed: %v", err)
	}

	// Search for the specific complex - should compute path
	results, err := db.UnifiedSearch("phelloscomplex", 10)
	if err != nil {
		t.Fatalf("UnifiedSearch failed: %v", err)
	}
	if len(results.Taxa) != 1 {
		t.Fatalf("expected 1 taxon, got %d", len(results.Taxa))
	}

	taxon := results.Taxa[0]
	if len(taxon.Path) == 0 {
		t.Fatal("expected non-empty path")
	}
	// Path should end with the taxon name
	if taxon.Path[len(taxon.Path)-1] != "phelloscomplex" {
		t.Errorf("path should end with 'phelloscomplex', got %v", taxon.Path)
	}
}
