use anyhow::{anyhow, Result};
use crate::db::Database;
use crate::editor;

/// Execute the 'oak source new' command
pub fn new(db: &Database) -> Result<()> {
    // Create new source interactively
    let source = editor::new_source()?;

    // Check if source ID already exists
    if db.get_source(&source.source_id)?.is_some() {
        return Err(anyhow!("Source ID '{}' already exists.", source.source_id));
    }

    // Save to database
    db.insert_source(&source)?;

    // Output the source ID to stdout for pipelining
    println!("{}", source.source_id);

    Ok(())
}

/// Execute the 'oak source edit' command
pub fn edit(db: &Database, id: &str) -> Result<()> {
    // Get existing source
    let source = db.get_source(id)?
        .ok_or_else(|| anyhow!("Source '{}' not found.", id))?;

    eprintln!("Editing source: {}", id);

    // Open editor with existing data
    let updated_source = editor::edit_source(&source)?;

    // Ensure source_id hasn't changed
    if updated_source.source_id != source.source_id {
        return Err(anyhow!("Cannot change source_id. Original: '{}', New: '{}'",
            source.source_id, updated_source.source_id));
    }

    // Save to database
    db.update_source(&updated_source)?;

    eprintln!("✓ Successfully updated source '{}'", updated_source.source_id);

    Ok(())
}

/// Execute the 'oak source list' command
pub fn list(db: &Database) -> Result<()> {
    let sources = db.list_sources()?;

    if sources.is_empty() {
        println!("No sources found.");
        return Ok(());
    }

    // Print header
    println!("{:<20} {:<15} {}", "Source ID", "Type", "Name");
    println!("{}", "=".repeat(80));

    // Print sources
    for source in sources {
        println!("{:<20} {:<15} {}", source.source_id, source.source_type, source.name);
    }

    Ok(())
}
