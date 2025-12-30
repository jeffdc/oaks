package editor

import (
	"testing"

	"github.com/jeff/oaks/cli/internal/models"
)

func TestParseFrontmatter(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		wantFM   string
		wantBody string
		wantErr  bool
	}{
		{
			name:     "valid frontmatter",
			input:    "---\nfoo: bar\n---\n\n# Body\n\nContent here",
			wantFM:   "foo: bar",
			wantBody: "# Body\n\nContent here",
			wantErr:  false,
		},
		{
			name:     "no frontmatter",
			input:    "# Just body",
			wantFM:   "",
			wantBody: "# Just body",
			wantErr:  false,
		},
		{
			name:    "unclosed frontmatter",
			input:   "---\nfoo: bar\n",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fm, body, err := parseFrontmatter(tt.input)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseFrontmatter() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if fm != tt.wantFM {
					t.Errorf("frontmatter = %q, want %q", fm, tt.wantFM)
				}
				if body != tt.wantBody {
					t.Errorf("body = %q, want %q", body, tt.wantBody)
				}
			}
		})
	}
}

func TestExtractSection(t *testing.T) {
	body := `# Range

Eastern North America

# Leaves

8-20 cm long, obovate

# Fruits

Acorns 15-25mm`

	tests := []struct {
		heading string
		want    string
	}{
		{"Range", "Eastern North America"},
		{"Leaves", "8-20 cm long, obovate"},
		{"Fruits", "Acorns 15-25mm"},
		{"Missing", ""},
	}

	for _, tt := range tests {
		t.Run(tt.heading, func(t *testing.T) {
			got := extractSection(body, tt.heading)
			if got != tt.want {
				t.Errorf("extractSection(%q) = %q, want %q", tt.heading, got, tt.want)
			}
		})
	}
}

func TestOakEntryRoundTrip(t *testing.T) {
	author := "L. 1753"
	subgenus := "Quercus"
	section := "Quercus"

	original := &models.OakEntry{
		ScientificName:      "alba",
		Author:              &author,
		IsHybrid:            false,
		Subgenus:            &subgenus,
		Section:             &section,
		Hybrids:             []string{"bebbiana", "jackiana"},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
	}

	md := oakEntryToMarkdown(original)
	parsed, err := parseOakEntryMarkdown(md)
	if err != nil {
		t.Fatalf("parseOakEntryMarkdown() error = %v", err)
	}

	if parsed.ScientificName != original.ScientificName {
		t.Errorf("ScientificName = %q, want %q", parsed.ScientificName, original.ScientificName)
	}
	if *parsed.Author != *original.Author {
		t.Errorf("Author = %q, want %q", *parsed.Author, *original.Author)
	}
	if parsed.IsHybrid != original.IsHybrid {
		t.Errorf("IsHybrid = %v, want %v", parsed.IsHybrid, original.IsHybrid)
	}
	if len(parsed.Hybrids) != len(original.Hybrids) {
		t.Errorf("Hybrids len = %d, want %d", len(parsed.Hybrids), len(original.Hybrids))
	}
}

func TestSpeciesSourceRoundTrip(t *testing.T) {
	rng := "Eastern North America"
	leaves := "8-20 cm long"
	url := "https://example.com"

	original := &models.SpeciesSource{
		ID:             1,
		ScientificName: "alba",
		SourceID:       3,
		LocalNames:     []string{"white oak", "eastern white oak"},
		Range:          &rng,
		Leaves:         &leaves,
		URL:            &url,
		IsPreferred:    true,
	}

	md := speciesSourceToMarkdown(original, "Oak Compendium")
	parsed, err := parseSpeciesSourceMarkdown(md, original)
	if err != nil {
		t.Fatalf("parseSpeciesSourceMarkdown() error = %v", err)
	}

	if parsed.ScientificName != original.ScientificName {
		t.Errorf("ScientificName = %q, want %q", parsed.ScientificName, original.ScientificName)
	}
	if parsed.SourceID != original.SourceID {
		t.Errorf("SourceID = %d, want %d", parsed.SourceID, original.SourceID)
	}
	if len(parsed.LocalNames) != len(original.LocalNames) {
		t.Errorf("LocalNames len = %d, want %d", len(parsed.LocalNames), len(original.LocalNames))
	}
	if *parsed.Range != *original.Range {
		t.Errorf("Range = %q, want %q", *parsed.Range, *original.Range)
	}
	if *parsed.Leaves != *original.Leaves {
		t.Errorf("Leaves = %q, want %q", *parsed.Leaves, *original.Leaves)
	}
	if parsed.IsPreferred != original.IsPreferred {
		t.Errorf("IsPreferred = %v, want %v", parsed.IsPreferred, original.IsPreferred)
	}
}

func TestSourceRoundTrip(t *testing.T) {
	desc := "Comprehensive oak database"
	notes := "Primary morphological source"
	author := "Le Hardÿ de Beaulieu"
	year := 2023
	url := "https://oaksoftheworld.fr"

	original := &models.Source{
		ID:          2,
		SourceType:  "Website",
		Name:        "Oaks of the World",
		Description: &desc,
		Author:      &author,
		Year:        &year,
		URL:         &url,
		Notes:       &notes,
	}

	md := sourceToMarkdown(original)
	parsed, err := parseSourceMarkdown(md)
	if err != nil {
		t.Fatalf("parseSourceMarkdown() error = %v", err)
	}

	if parsed.ID != original.ID {
		t.Errorf("ID = %d, want %d", parsed.ID, original.ID)
	}
	if parsed.SourceType != original.SourceType {
		t.Errorf("SourceType = %q, want %q", parsed.SourceType, original.SourceType)
	}
	if parsed.Name != original.Name {
		t.Errorf("Name = %q, want %q", parsed.Name, original.Name)
	}
	if *parsed.Description != *original.Description {
		t.Errorf("Description = %q, want %q", *parsed.Description, *original.Description)
	}
	if *parsed.Notes != *original.Notes {
		t.Errorf("Notes = %q, want %q", *parsed.Notes, *original.Notes)
	}
}
