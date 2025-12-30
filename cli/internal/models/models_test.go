package models

import (
	"encoding/json"
	"testing"
)

func TestTaxonLevelConstants(t *testing.T) {
	tests := []struct {
		level TaxonLevel
		want  string
	}{
		{TaxonLevelSubgenus, "subgenus"},
		{TaxonLevelSection, "section"},
		{TaxonLevelSubsection, "subsection"},
		{TaxonLevelComplex, "complex"},
	}

	for _, tt := range tests {
		if string(tt.level) != tt.want {
			t.Errorf("TaxonLevel = %q, want %q", string(tt.level), tt.want)
		}
	}
}

func TestNewOakEntry(t *testing.T) {
	entry := NewOakEntry("alba")

	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %q, want %q", entry.ScientificName, "alba")
	}
	if entry.IsHybrid {
		t.Error("expected IsHybrid = false")
	}
	if entry.Hybrids == nil {
		t.Error("expected non-nil Hybrids slice")
	}
	if len(entry.Hybrids) != 0 {
		t.Errorf("expected empty Hybrids, got %d elements", len(entry.Hybrids))
	}
	if entry.CloselyRelatedTo == nil {
		t.Error("expected non-nil CloselyRelatedTo slice")
	}
	if entry.SubspeciesVarieties == nil {
		t.Error("expected non-nil SubspeciesVarieties slice")
	}
	if entry.Synonyms == nil {
		t.Error("expected non-nil Synonyms slice")
	}
	if entry.ExternalLinks == nil {
		t.Error("expected non-nil ExternalLinks slice")
	}
}

func TestNewSpeciesSource(t *testing.T) {
	ss := NewSpeciesSource("alba", 3)

	if ss.ScientificName != "alba" {
		t.Errorf("ScientificName = %q, want %q", ss.ScientificName, "alba")
	}
	if ss.SourceID != 3 {
		t.Errorf("SourceID = %d, want %d", ss.SourceID, 3)
	}
	if ss.IsPreferred {
		t.Error("expected IsPreferred = false")
	}
	if ss.LocalNames == nil {
		t.Error("expected non-nil LocalNames slice")
	}
	if len(ss.LocalNames) != 0 {
		t.Errorf("expected empty LocalNames, got %d elements", len(ss.LocalNames))
	}
}

func TestNewSource(t *testing.T) {
	s := NewSource("Website", "Oaks of the World")

	if s.SourceType != "Website" {
		t.Errorf("SourceType = %q, want %q", s.SourceType, "Website")
	}
	if s.Name != "Oaks of the World" {
		t.Errorf("Name = %q, want %q", s.Name, "Oaks of the World")
	}
	if s.ID != 0 {
		t.Errorf("ID = %d, want 0", s.ID)
	}
}

func TestTaxonJSON(t *testing.T) {
	parent := "Quercus"
	author := "Oerst."
	taxon := &Taxon{
		Name:   "Lobatae",
		Level:  TaxonLevelSection,
		Parent: &parent,
		Author: &author,
		Links: []TaxonLink{
			{Label: "iNaturalist", URL: "https://inaturalist.org/taxa/12345"},
		},
	}

	data, err := json.Marshal(taxon)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed Taxon
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.Name != taxon.Name {
		t.Errorf("Name = %q, want %q", parsed.Name, taxon.Name)
	}
	if parsed.Level != taxon.Level {
		t.Errorf("Level = %q, want %q", parsed.Level, taxon.Level)
	}
	if *parsed.Parent != *taxon.Parent {
		t.Errorf("Parent = %q, want %q", *parsed.Parent, *taxon.Parent)
	}
	if len(parsed.Links) != 1 {
		t.Errorf("Links len = %d, want 1", len(parsed.Links))
	}
}

func TestOakEntryJSON(t *testing.T) {
	author := "L. 1753"
	subgenus := "Quercus"
	entry := &OakEntry{
		ScientificName:      "alba",
		Author:              &author,
		IsHybrid:            false,
		Subgenus:            &subgenus,
		Hybrids:             []string{"bebbiana"},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks: []ExternalLink{
			{Name: "Wikipedia", URL: "https://en.wikipedia.org/wiki/Quercus_alba", Logo: "wikipedia"},
		},
	}

	data, err := json.Marshal(entry)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed OakEntry
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.ScientificName != entry.ScientificName {
		t.Errorf("ScientificName = %q, want %q", parsed.ScientificName, entry.ScientificName)
	}
	if *parsed.Author != *entry.Author {
		t.Errorf("Author = %q, want %q", *parsed.Author, *entry.Author)
	}
	if len(parsed.Hybrids) != 1 {
		t.Errorf("Hybrids len = %d, want 1", len(parsed.Hybrids))
	}
	if len(parsed.ExternalLinks) != 1 {
		t.Errorf("ExternalLinks len = %d, want 1", len(parsed.ExternalLinks))
	}
	if parsed.ExternalLinks[0].Logo != "wikipedia" {
		t.Errorf("Logo = %q, want %q", parsed.ExternalLinks[0].Logo, "wikipedia")
	}
}

func TestSpeciesSourceJSON(t *testing.T) {
	rng := "Eastern North America"
	leaves := "8-20 cm"
	ss := &SpeciesSource{
		ID:             1,
		ScientificName: "alba",
		SourceID:       3,
		LocalNames:     []string{"white oak", "eastern white oak"},
		Range:          &rng,
		Leaves:         &leaves,
		IsPreferred:    true,
	}

	data, err := json.Marshal(ss)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed SpeciesSource
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.ScientificName != ss.ScientificName {
		t.Errorf("ScientificName = %q, want %q", parsed.ScientificName, ss.ScientificName)
	}
	if len(parsed.LocalNames) != 2 {
		t.Errorf("LocalNames len = %d, want 2", len(parsed.LocalNames))
	}
	if *parsed.Range != rng {
		t.Errorf("Range = %q, want %q", *parsed.Range, rng)
	}
	if !parsed.IsPreferred {
		t.Error("expected IsPreferred = true")
	}
}

func TestSourceJSON(t *testing.T) {
	desc := "Test description"
	year := 2024
	s := &Source{
		ID:          1,
		SourceType:  "Website",
		Name:        "Test Source",
		Description: &desc,
		Year:        &year,
	}

	data, err := json.Marshal(s)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed Source
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.Name != s.Name {
		t.Errorf("Name = %q, want %q", parsed.Name, s.Name)
	}
	if *parsed.Year != year {
		t.Errorf("Year = %d, want %d", *parsed.Year, year)
	}
}

func TestExternalLinkJSON(t *testing.T) {
	link := ExternalLink{
		Name: "iNaturalist",
		URL:  "https://inaturalist.org/taxa/12345",
		Logo: "inaturalist",
	}

	data, err := json.Marshal(link)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed ExternalLink
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.Name != link.Name {
		t.Errorf("Name = %q, want %q", parsed.Name, link.Name)
	}
	if parsed.URL != link.URL {
		t.Errorf("URL = %q, want %q", parsed.URL, link.URL)
	}
	if parsed.Logo != link.Logo {
		t.Errorf("Logo = %q, want %q", parsed.Logo, link.Logo)
	}
}

func TestTaxonLinkJSON(t *testing.T) {
	link := TaxonLink{
		Label: "Wikipedia",
		URL:   "https://en.wikipedia.org/wiki/Lobatae",
	}

	data, err := json.Marshal(link)
	if err != nil {
		t.Fatalf("json.Marshal failed: %v", err)
	}

	var parsed TaxonLink
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("json.Unmarshal failed: %v", err)
	}

	if parsed.Label != link.Label {
		t.Errorf("Label = %q, want %q", parsed.Label, link.Label)
	}
	if parsed.URL != link.URL {
		t.Errorf("URL = %q, want %q", parsed.URL, link.URL)
	}
}
