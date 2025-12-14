use anyhow::{anyhow, Result};
use crate::db::Database;
use crate::editor;
use crate::schema::SchemaValidator;

/// Execute the 'oak edit' command
pub fn execute(db: &Database, validator: &SchemaValidator, name: &str) -> Result<()> {
    // Get existing entry
    let entry = db.get_oak_entry(name)?
        .ok_or_else(|| anyhow!("Entry '{}' not found. Use 'oak new' to create it.", name))?;

    println!("Editing Oak entry: {}", name);

    // Open editor with existing data
    let updated_entry = editor::edit_oak_entry(&entry, validator)?;

    // Save to database
    db.save_oak_entry(&updated_entry)?;

    println!("✓ Successfully updated entry for '{}'", updated_entry.scientific_name);

    Ok(())
}
