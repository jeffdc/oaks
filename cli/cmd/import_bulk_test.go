package cmd

import (
	"reflect"
	"testing"

	"github.com/jeff/oaks/cli/internal/models"
)

func TestMergeStringSlices(t *testing.T) {
	tests := []struct {
		name     string
		base     []string
		add      []string
		expected []string
	}{
		{
			name:     "empty add",
			base:     []string{"a", "b"},
			add:      []string{},
			expected: []string{"a", "b"},
		},
		{
			name:     "empty base",
			base:     []string{},
			add:      []string{"a", "b"},
			expected: []string{"a", "b"},
		},
		{
			name:     "both empty",
			base:     []string{},
			add:      []string{},
			expected: []string{},
		},
		{
			name:     "nil base",
			base:     nil,
			add:      []string{"a"},
			expected: []string{"a"},
		},
		{
			name:     "nil add",
			base:     []string{"a"},
			add:      nil,
			expected: []string{"a"},
		},
		{
			name:     "no duplicates",
			base:     []string{"a", "b"},
			add:      []string{"c", "d"},
			expected: []string{"a", "b", "c", "d"},
		},
		{
			name:     "with duplicates",
			base:     []string{"a", "b"},
			add:      []string{"b", "c"},
			expected: []string{"a", "b", "c"},
		},
		{
			name:     "all duplicates",
			base:     []string{"a", "b"},
			add:      []string{"a", "b"},
			expected: []string{"a", "b"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := mergeStringSlices(tt.base, tt.add)
			if !reflect.DeepEqual(got, tt.expected) {
				t.Errorf("mergeStringSlices(%v, %v) = %v, want %v", tt.base, tt.add, got, tt.expected)
			}
		})
	}
}

func TestMergeEntries_Synonyms(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName: "alba",
		Synonyms:       []string{"syn1", "syn2"},
	}
	imported := &models.OakEntry{
		ScientificName: "alba",
		Synonyms:       []string{"syn2", "syn3"}, // syn2 is duplicate
	}

	mergeEntries(existing, imported)

	// Should have syn1, syn2, syn3 (no duplicates)
	if len(existing.Synonyms) != 3 {
		t.Errorf("expected 3 synonyms, got %d: %v", len(existing.Synonyms), existing.Synonyms)
	}
	// Check all expected values are present
	syns := make(map[string]bool)
	for _, s := range existing.Synonyms {
		syns[s] = true
	}
	for _, expected := range []string{"syn1", "syn2", "syn3"} {
		if !syns[expected] {
			t.Errorf("expected synonym %q not found in %v", expected, existing.Synonyms)
		}
	}
}

func TestMergeEntries_Hybrids(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName: "alba",
		Hybrids:        []string{"bebbiana"},
	}
	imported := &models.OakEntry{
		ScientificName: "alba",
		Hybrids:        []string{"bebbiana", "jackiana"}, // bebbiana is duplicate
	}

	mergeEntries(existing, imported)

	if len(existing.Hybrids) != 2 {
		t.Errorf("expected 2 hybrids, got %d: %v", len(existing.Hybrids), existing.Hybrids)
	}
}

func TestMergeEntries_CloselyRelatedTo(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName:   "alba",
		CloselyRelatedTo: []string{"stellata"},
	}
	imported := &models.OakEntry{
		ScientificName:   "alba",
		CloselyRelatedTo: []string{"bicolor", "stellata"},
	}

	mergeEntries(existing, imported)

	if len(existing.CloselyRelatedTo) != 2 {
		t.Errorf("expected 2 closely related, got %d: %v", len(existing.CloselyRelatedTo), existing.CloselyRelatedTo)
	}
}

func TestMergeEntries_SubspeciesVarieties(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName:      "alba",
		SubspeciesVarieties: []string{"var. latiloba"},
	}
	imported := &models.OakEntry{
		ScientificName:      "alba",
		SubspeciesVarieties: []string{"var. latiloba", "var. repanda"},
	}

	mergeEntries(existing, imported)

	if len(existing.SubspeciesVarieties) != 2 {
		t.Errorf("expected 2 subspecies/varieties, got %d: %v", len(existing.SubspeciesVarieties), existing.SubspeciesVarieties)
	}
}

func TestMergeEntries_SingleValueFields_ExistingNil(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName: "alba",
		// All pointer fields are nil
	}
	author := "L. 1753"
	status := "LC"
	subgenus := "Quercus"
	section := "Quercus"
	subsection := "Albae"
	cmplx := "Alba"
	parent1 := "rubra"
	parent2 := "velutina"

	imported := &models.OakEntry{
		ScientificName:     "alba",
		Author:             &author,
		ConservationStatus: &status,
		Subgenus:           &subgenus,
		Section:            &section,
		Subsection:         &subsection,
		Complex:            &cmplx,
		Parent1:            &parent1,
		Parent2:            &parent2,
	}

	mergeEntries(existing, imported)

	// All fields should be updated from imported since existing was nil
	if existing.Author == nil || *existing.Author != author {
		t.Errorf("Author not merged: got %v, want %q", existing.Author, author)
	}
	if existing.ConservationStatus == nil || *existing.ConservationStatus != status {
		t.Errorf("ConservationStatus not merged: got %v, want %q", existing.ConservationStatus, status)
	}
	if existing.Subgenus == nil || *existing.Subgenus != subgenus {
		t.Errorf("Subgenus not merged: got %v, want %q", existing.Subgenus, subgenus)
	}
	if existing.Section == nil || *existing.Section != section {
		t.Errorf("Section not merged: got %v, want %q", existing.Section, section)
	}
	if existing.Subsection == nil || *existing.Subsection != subsection {
		t.Errorf("Subsection not merged: got %v, want %q", existing.Subsection, subsection)
	}
	if existing.Complex == nil || *existing.Complex != cmplx {
		t.Errorf("Complex not merged: got %v, want %q", existing.Complex, cmplx)
	}
	if existing.Parent1 == nil || *existing.Parent1 != parent1 {
		t.Errorf("Parent1 not merged: got %v, want %q", existing.Parent1, parent1)
	}
	if existing.Parent2 == nil || *existing.Parent2 != parent2 {
		t.Errorf("Parent2 not merged: got %v, want %q", existing.Parent2, parent2)
	}
}

func TestMergeEntries_SingleValueFields_ExistingNotNil(t *testing.T) {
	existingAuthor := "Existing Author"
	existing := &models.OakEntry{
		ScientificName: "alba",
		Author:         &existingAuthor,
	}

	importedAuthor := "Imported Author"
	imported := &models.OakEntry{
		ScientificName: "alba",
		Author:         &importedAuthor,
	}

	mergeEntries(existing, imported)

	// Existing value should be preserved (not overwritten)
	if existing.Author == nil || *existing.Author != existingAuthor {
		t.Errorf("Author should not be overwritten: got %v, want %q", existing.Author, existingAuthor)
	}
}

func TestMergeEntries_EmptySlices(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName: "alba",
		Synonyms:       []string{},
		Hybrids:        []string{},
	}
	imported := &models.OakEntry{
		ScientificName: "alba",
		Synonyms:       []string{"syn1"},
		Hybrids:        []string{},
	}

	mergeEntries(existing, imported)

	if len(existing.Synonyms) != 1 {
		t.Errorf("expected 1 synonym, got %d", len(existing.Synonyms))
	}
	if len(existing.Hybrids) != 0 {
		t.Errorf("expected 0 hybrids, got %d", len(existing.Hybrids))
	}
}

func TestMergeEntries_NilSlices(t *testing.T) {
	existing := &models.OakEntry{
		ScientificName: "alba",
		// Synonyms is nil
	}
	imported := &models.OakEntry{
		ScientificName: "alba",
		Synonyms:       []string{"syn1"},
	}

	mergeEntries(existing, imported)

	if len(existing.Synonyms) != 1 {
		t.Errorf("expected 1 synonym, got %d", len(existing.Synonyms))
	}
}
