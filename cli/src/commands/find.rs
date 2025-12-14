use anyhow::{anyhow, Result};
use crate::db::Database;

/// Execute the 'oak find' command
pub fn execute(db: &Database, query: &str, id_only: bool, search_type: &str) -> Result<()> {
    let mut oak_results = Vec::new();
    let mut source_results = Vec::new();

    // Search based on type
    match search_type {
        "oak" => {
            oak_results = db.search_oak_entries(query)?;
        }
        "source" => {
            source_results = db.search_sources(query)?;
        }
        "both" => {
            oak_results = db.search_oak_entries(query)?;
            source_results = db.search_sources(query)?;
        }
        _ => {
            return Err(anyhow!("Invalid search type '{}'. Must be 'oak', 'source', or 'both'.", search_type));
        }
    }

    // Output results
    if id_only {
        // Pipeline mode: IDs only, one per line, to stdout
        // All other output goes to stderr
        for name in &oak_results {
            println!("{}", name);
        }
        for id in &source_results {
            println!("{}", id);
        }
    } else {
        // Human-readable mode
        if !oak_results.is_empty() {
            eprintln!("Oak Entries:");
            for name in &oak_results {
                eprintln!("  - {}", name);
            }
        }

        if !source_results.is_empty() {
            eprintln!("Sources:");
            for id in &source_results {
                eprintln!("  - {}", id);
            }
        }

        if oak_results.is_empty() && source_results.is_empty() {
            eprintln!("No results found for query '{}'", query);
        }
    }

    Ok(())
}
