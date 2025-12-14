use anyhow::{anyhow, Context, Result};
use jsonschema::JSONSchema;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

use crate::models::OakEntry;

/// Schema validator for Oak entries
pub struct SchemaValidator {
    schema: JSONSchema,
    schema_value: Value,
    enumerations: HashMap<String, Vec<String>>,
}

impl SchemaValidator {
    /// Load the schema from a file
    pub fn from_file<P: AsRef<Path>>(path: P) -> Result<Self> {
        let schema_content = fs::read_to_string(path.as_ref())
            .context("Failed to read schema file")?;

        let schema_value: Value = serde_json::from_str(&schema_content)
            .context("Failed to parse schema JSON")?;

        let schema = JSONSchema::compile(&schema_value)
            .map_err(|e| anyhow!("Failed to compile schema: {}", e))?;

        // Extract enumerations from the schema
        let enumerations = schema_value
            .get("enumerations")
            .and_then(|e| e.as_object())
            .map(|obj| {
                obj.iter()
                    .filter_map(|(k, v)| {
                        v.as_array().map(|arr| {
                            (
                                k.clone(),
                                arr.iter()
                                    .filter_map(|v| v.as_str().map(String::from))
                                    .collect(),
                            )
                        })
                    })
                    .collect()
            })
            .unwrap_or_default();

        Ok(Self {
            schema,
            schema_value,
            enumerations,
        })
    }

    /// Validate an oak entry
    pub fn validate(&self, entry: &OakEntry) -> Result<()> {
        // Convert to JSON for validation
        let json_value = serde_json::to_value(entry)
            .context("Failed to serialize entry")?;

        // Validate against schema
        if let Err(errors) = self.schema.validate(&json_value) {
            let error_messages: Vec<String> = errors
                .map(|e| format!("  - {}", e))
                .collect();

            return Err(anyhow!(
                "Validation failed:\n{}",
                error_messages.join("\n")
            ));
        }

        // Validate enumeration values
        self.validate_enumerations(entry)?;

        Ok(())
    }

    /// Validate that enumerated field values are in the allowed list
    fn validate_enumerations(&self, entry: &OakEntry) -> Result<()> {
        let mut errors = Vec::new();

        // Helper to check field values
        let mut check_field = |field_name: &str, values: &[crate::models::DataPoint]| {
            if let Some(allowed) = self.enumerations.get(field_name) {
                for dp in values {
                    if !allowed.contains(&dp.value) {
                        errors.push(format!(
                            "Invalid value '{}' for field '{}'. Allowed values: {}",
                            dp.value,
                            field_name,
                            allowed.join(", ")
                        ));
                    }
                }
            }
        };

        check_field("leaf_color", &entry.leaf_color);
        check_field("bud_shape", &entry.bud_shape);
        check_field("leaf_shape", &entry.leaf_shape);
        check_field("bark_texture", &entry.bark_texture);

        if !errors.is_empty() {
            return Err(anyhow!(
                "Enumeration validation failed:\n  - {}",
                errors.join("\n  - ")
            ));
        }

        Ok(())
    }

    /// Add a new enumeration value to a field
    pub fn add_enumeration_value(&mut self, field: &str, value: &str) -> Result<()> {
        if !self.enumerations.contains_key(field) {
            return Err(anyhow!("Field '{}' does not have enumeration validation", field));
        }

        let values = self.enumerations.get_mut(field).unwrap();
        if values.contains(&value.to_string()) {
            return Err(anyhow!(
                "Value '{}' already exists for field '{}'",
                value,
                field
            ));
        }

        values.push(value.to_string());
        values.sort();

        Ok(())
    }

    /// Save the schema back to file (used after adding enumeration values)
    pub fn save_to_file<P: AsRef<Path>>(&self, path: P) -> Result<()> {
        // Update the enumerations in the schema value
        let mut schema = self.schema_value.clone();
        if let Some(obj) = schema.as_object_mut() {
            let enum_obj: HashMap<String, Value> = self
                .enumerations
                .iter()
                .map(|(k, v)| {
                    let values: Vec<Value> = v.iter().map(|s| json!(s)).collect();
                    (k.clone(), json!(values))
                })
                .collect();

            obj.insert("enumerations".to_string(), json!(enum_obj));
        }

        let json_string = serde_json::to_string_pretty(&schema)
            .context("Failed to serialize schema")?;

        fs::write(path, json_string)
            .context("Failed to write schema file")?;

        Ok(())
    }

    /// Get the list of allowed values for a field
    pub fn get_allowed_values(&self, field: &str) -> Option<&[String]> {
        self.enumerations.get(field).map(|v| v.as_slice())
    }

    /// Get all enumerated fields
    pub fn get_enumerated_fields(&self) -> Vec<&str> {
        self.enumerations.keys().map(|s| s.as_str()).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::DataPoint;

    #[test]
    fn test_validate_valid_entry() {
        let validator = SchemaValidator::from_file("schema/oak_schema.json").unwrap();

        let entry = OakEntry {
            scientific_name: "Quercus robur".to_string(),
            leaf_shape: vec![DataPoint {
                value: "lobed".to_string(),
                source_id: "src1".to_string(),
                page_number: None,
            }],
            ..OakEntry::new("Quercus robur".to_string())
        };

        assert!(validator.validate(&entry).is_ok());
    }

    #[test]
    fn test_validate_invalid_enum() {
        let validator = SchemaValidator::from_file("schema/oak_schema.json").unwrap();

        let entry = OakEntry {
            scientific_name: "Quercus robur".to_string(),
            leaf_shape: vec![DataPoint {
                value: "square".to_string(), // Invalid value
                source_id: "src1".to_string(),
                page_number: None,
            }],
            ..OakEntry::new("Quercus robur".to_string())
        };

        assert!(validator.validate(&entry).is_err());
    }
}
