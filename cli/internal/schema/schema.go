package schema

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/jeff/oaks/cli/internal/models"
	"github.com/santhosh-tekuri/jsonschema/v5"
)

// Validator handles JSON schema validation for Oak entries
type Validator struct {
	schema       *jsonschema.Schema
	enumerations map[string][]string
	schemaPath   string
}

// schemaWithEnums represents the schema file structure
type schemaWithEnums struct {
	Enumerations map[string][]string `json:"enumerations"`
}

// FromFile creates a new Validator from a schema file
func FromFile(schemaPath string) (*Validator, error) {
	data, err := os.ReadFile(schemaPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read schema file: %w", err)
	}

	// Parse enumerations from schema
	var schemaData schemaWithEnums
	if err := json.Unmarshal(data, &schemaData); err != nil {
		return nil, fmt.Errorf("failed to parse schema: %w", err)
	}

	// Compile JSON Schema
	compiler := jsonschema.NewCompiler()
	if err := compiler.AddResource(schemaPath, strings.NewReader(string(data))); err != nil {
		return nil, fmt.Errorf("failed to add schema resource: %w", err)
	}

	schema, err := compiler.Compile(schemaPath)
	if err != nil {
		return nil, fmt.Errorf("failed to compile schema: %w", err)
	}

	return &Validator{
		schema:       schema,
		enumerations: schemaData.Enumerations,
		schemaPath:   schemaPath,
	}, nil
}

// ValidateOakEntry validates an OakEntry against the schema
func (v *Validator) ValidateOakEntry(entry *models.OakEntry) error {
	// First, validate against JSON Schema
	data, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("failed to marshal entry: %w", err)
	}

	var obj interface{}
	if err := json.Unmarshal(data, &obj); err != nil {
		return fmt.Errorf("failed to unmarshal entry: %w", err)
	}

	if err := v.schema.Validate(obj); err != nil {
		return fmt.Errorf("schema validation failed: %w", err)
	}

	// Validate enumerations
	if err := v.validateEnumerations(entry); err != nil {
		return err
	}

	return nil
}

// validateEnumerations checks field values against allowed enumerations
func (v *Validator) validateEnumerations(entry *models.OakEntry) error {
	var errors []string

	validateField := func(fieldName string, dataPoints []models.DataPoint) {
		allowedValues, hasEnum := v.enumerations[fieldName]
		if !hasEnum {
			return
		}

		allowed := make(map[string]bool)
		for _, val := range allowedValues {
			allowed[val] = true
		}

		for _, dp := range dataPoints {
			if !allowed[dp.Value] {
				errors = append(errors, fmt.Sprintf(
					"invalid value '%s' for field '%s'. Allowed values: %s",
					dp.Value, fieldName, strings.Join(allowedValues, ", "),
				))
			}
		}
	}

	validateField("leaf_shape", entry.LeafShape)
	validateField("leaf_color", entry.LeafColor)
	validateField("bud_shape", entry.BudShape)
	validateField("bark_texture", entry.BarkTexture)

	if len(errors) > 0 {
		return fmt.Errorf("enumeration validation failed:\n  - %s", strings.Join(errors, "\n  - "))
	}

	return nil
}

// AddEnumValue adds a new permitted value to a field's enumeration
func (v *Validator) AddEnumValue(field, value string) error {
	// Check if field has enumerations
	existing, ok := v.enumerations[field]
	if !ok {
		return fmt.Errorf("field '%s' does not have enumeration constraints", field)
	}

	// Check if value already exists
	for _, val := range existing {
		if val == value {
			return fmt.Errorf("value '%s' already exists for field '%s'", value, field)
		}
	}

	// Read the schema file
	data, err := os.ReadFile(v.schemaPath)
	if err != nil {
		return fmt.Errorf("failed to read schema file: %w", err)
	}

	var schemaMap map[string]interface{}
	if err := json.Unmarshal(data, &schemaMap); err != nil {
		return fmt.Errorf("failed to parse schema: %w", err)
	}

	// Update the enumerations
	enums, ok := schemaMap["enumerations"].(map[string]interface{})
	if !ok {
		return fmt.Errorf("invalid schema: missing enumerations")
	}

	fieldEnum, ok := enums[field].([]interface{})
	if !ok {
		return fmt.Errorf("invalid schema: field '%s' enumerations not found", field)
	}

	fieldEnum = append(fieldEnum, value)
	enums[field] = fieldEnum
	schemaMap["enumerations"] = enums

	// Write back the schema
	output, err := json.MarshalIndent(schemaMap, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal schema: %w", err)
	}

	if err := os.WriteFile(v.schemaPath, output, 0644); err != nil {
		return fmt.Errorf("failed to write schema file: %w", err)
	}

	// Update in-memory enumerations
	v.enumerations[field] = append(v.enumerations[field], value)

	return nil
}

// GetEnumValues returns the allowed values for a field
func (v *Validator) GetEnumValues(field string) ([]string, bool) {
	vals, ok := v.enumerations[field]
	return vals, ok
}

// GetAllEnumFields returns all fields that have enumeration constraints
func (v *Validator) GetAllEnumFields() []string {
	fields := make([]string, 0, len(v.enumerations))
	for field := range v.enumerations {
		fields = append(fields, field)
	}
	return fields
}
