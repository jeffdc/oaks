use anyhow::{anyhow, Result};
use dialoguer::Confirm;
use crate::db::Database;

/// Execute the 'oak delete' command
pub fn execute(db: &Database, name: &str) -> Result<()> {
    // Check if entry exists
    if db.get_oak_entry(name)?.is_none() {
        return Err(anyhow!("Entry '{}' not found.", name));
    }

    // Require confirmation
    let confirmed = Confirm::new()
        .with_prompt(format!("Are you sure you want to delete '{}'?", name))
        .default(false)
        .interact()?;

    if !confirmed {
        println!("Deletion cancelled.");
        return Ok(());
    }

    // Delete the entry
    db.delete_oak_entry(name)?;

    println!("✓ Successfully deleted entry for '{}'", name);

    Ok(())
}
