use anyhow::{anyhow, Result};
use crate::db::Database;
use crate::editor;
use crate::schema::SchemaValidator;

/// Execute the 'oak new' command
pub fn execute(db: &Database, validator: &SchemaValidator, name: &str) -> Result<()> {
    // Check if entry already exists
    if db.get_oak_entry(name)?.is_some() {
        return Err(anyhow!("Entry '{}' already exists. Use 'oak edit' to modify it.", name));
    }

    println!("Creating new Oak entry: {}", name);

    // Open editor with template
    let entry = editor::new_oak_entry(name, validator)?;

    // Save to database
    db.save_oak_entry(&entry)?;

    println!("✓ Successfully created entry for '{}'", entry.scientific_name);

    Ok(())
}
