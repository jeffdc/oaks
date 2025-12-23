package schema

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/jeff/oaks/cli/internal/models"
)

// testSchemaPath returns a path to a test schema file
func testSchemaPath(t *testing.T) string {
	t.Helper()
	// Use the actual schema file from the repo
	return filepath.Join("..", "..", "schema", "oak_schema.json")
}

// createTempSchema creates a temporary schema file for testing modifications
func createTempSchema(t *testing.T) (string, func()) {
	t.Helper()

	content := `{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Test Schema",
  "type": "object",
  "required": ["scientific_name"],
  "properties": {
    "scientific_name": {
      "type": "string",
      "minLength": 1
    }
  },
  "enumerations": {
    "leaf_shape": ["lobed", "entire"],
    "bark_texture": ["rough", "smooth"]
  }
}`

	tmpDir := t.TempDir()
	schemaPath := filepath.Join(tmpDir, "test_schema.json")

	if err := os.WriteFile(schemaPath, []byte(content), 0644); err != nil {
		t.Fatalf("failed to write temp schema: %v", err)
	}

	cleanup := func() {
		os.Remove(schemaPath)
	}

	return schemaPath, cleanup
}

func TestFromFile(t *testing.T) {
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}
	if v == nil {
		t.Fatal("expected non-nil validator")
	}
	if v.schema == nil {
		t.Error("expected non-nil schema")
	}
	if len(v.enumerations) == 0 {
		t.Error("expected non-empty enumerations")
	}
}

func TestFromFileInvalidPath(t *testing.T) {
	_, err := FromFile("/nonexistent/path/schema.json")
	if err == nil {
		t.Error("expected error for invalid path")
	}
}

func TestFromFileInvalidJSON(t *testing.T) {
	tmpDir := t.TempDir()
	schemaPath := filepath.Join(tmpDir, "invalid.json")

	if err := os.WriteFile(schemaPath, []byte("not valid json"), 0644); err != nil {
		t.Fatalf("failed to write file: %v", err)
	}

	_, err := FromFile(schemaPath)
	if err == nil {
		t.Error("expected error for invalid JSON")
	}
}

func TestValidateOakEntry(t *testing.T) {
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Valid entry
	entry := &models.OakEntry{
		ScientificName:      "alba",
		IsHybrid:            false,
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	if err := v.ValidateOakEntry(entry); err != nil {
		t.Errorf("ValidateOakEntry failed for valid entry: %v", err)
	}
}

func TestValidateOakEntryMissingName(t *testing.T) {
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Entry with empty name
	entry := &models.OakEntry{
		ScientificName:      "",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	if err := v.ValidateOakEntry(entry); err == nil {
		t.Error("expected validation error for empty scientific_name")
	}
}

func TestGetEnumValues(t *testing.T) {
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Get existing enum
	vals, ok := v.GetEnumValues("leaf_shape")
	if !ok {
		t.Error("expected leaf_shape enum to exist")
	}
	if len(vals) == 0 {
		t.Error("expected non-empty leaf_shape values")
	}

	// Check for expected values
	hasLobed := false
	for _, val := range vals {
		if val == "lobed" {
			hasLobed = true
			break
		}
	}
	if !hasLobed {
		t.Error("expected 'lobed' in leaf_shape values")
	}

	// Get non-existent enum
	_, ok = v.GetEnumValues("nonexistent_field")
	if ok {
		t.Error("expected nonexistent_field to not exist")
	}
}

func TestGetAllEnumFields(t *testing.T) {
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	fields := v.GetAllEnumFields()
	if len(fields) == 0 {
		t.Error("expected non-empty enum fields")
	}

	// Check for expected fields
	expectedFields := []string{"leaf_shape", "leaf_color", "bark_texture", "bud_shape"}
	for _, expected := range expectedFields {
		found := false
		for _, field := range fields {
			if field == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("expected field %q in enum fields", expected)
		}
	}
}

func TestAddEnumValue(t *testing.T) {
	schemaPath, cleanup := createTempSchema(t)
	defer cleanup()

	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Add new value
	if err := v.AddEnumValue("leaf_shape", "serrated"); err != nil {
		t.Fatalf("AddEnumValue failed: %v", err)
	}

	// Verify in-memory
	vals, _ := v.GetEnumValues("leaf_shape")
	hasSerrated := false
	for _, val := range vals {
		if val == "serrated" {
			hasSerrated = true
			break
		}
	}
	if !hasSerrated {
		t.Error("expected 'serrated' in leaf_shape values after add")
	}

	// Verify persisted (reload from file)
	v2, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile reload failed: %v", err)
	}
	vals2, _ := v2.GetEnumValues("leaf_shape")
	hasSerrated = false
	for _, val := range vals2 {
		if val == "serrated" {
			hasSerrated = true
			break
		}
	}
	if !hasSerrated {
		t.Error("expected 'serrated' to be persisted in schema file")
	}
}

func TestAddEnumValueDuplicate(t *testing.T) {
	schemaPath, cleanup := createTempSchema(t)
	defer cleanup()

	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Try to add existing value
	err = v.AddEnumValue("leaf_shape", "lobed")
	if err == nil {
		t.Error("expected error when adding duplicate value")
	}
}

func TestAddEnumValueNonExistentField(t *testing.T) {
	schemaPath, cleanup := createTempSchema(t)
	defer cleanup()

	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	// Try to add to non-existent field
	err = v.AddEnumValue("nonexistent_field", "some_value")
	if err == nil {
		t.Error("expected error for non-existent field")
	}
}

func TestValidateEnumerations(t *testing.T) {
	// This is currently a no-op since OakEntry doesn't have enumerated fields
	// But we test it to ensure it doesn't error
	schemaPath := testSchemaPath(t)
	v, err := FromFile(schemaPath)
	if err != nil {
		t.Fatalf("FromFile failed: %v", err)
	}

	entry := &models.OakEntry{
		ScientificName:      "alba",
		Hybrids:             []string{},
		CloselyRelatedTo:    []string{},
		SubspeciesVarieties: []string{},
		Synonyms:            []string{},
		ExternalLinks:       []models.ExternalLink{},
	}

	// validateEnumerations is called internally by ValidateOakEntry
	if err := v.ValidateOakEntry(entry); err != nil {
		t.Errorf("ValidateOakEntry failed: %v", err)
	}
}
