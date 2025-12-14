use anyhow::{anyhow, Result};
use std::path::Path;
use crate::schema::SchemaValidator;

/// Execute the 'oak add-value' command
pub fn execute(schema_path: &Path, validator: &SchemaValidator, field: &str, value: &str) -> Result<()> {
    // Check if field has enumeration validation
    let allowed = validator.get_allowed_values(field);
    if allowed.is_none() {
        let valid_fields = validator.get_enumerated_fields();
        return Err(anyhow!(
            "Field '{}' does not have enumeration validation. Valid fields: {}",
            field,
            valid_fields.join(", ")
        ));
    }

    eprintln!("Adding value '{}' to field '{}'", value, field);

    // Create a mutable copy of the validator
    let mut validator_mut = SchemaValidator::from_file(schema_path)?;

    // Add the value
    validator_mut.add_enumeration_value(field, value)?;

    // Save the updated schema
    validator_mut.save_to_file(schema_path)?;

    println!("✓ Successfully added value '{}' to field '{}'", value, field);

    Ok(())
}
