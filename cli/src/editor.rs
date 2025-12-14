use anyhow::{anyhow, Context, Result};
use std::env;
use std::fs;
use std::io::Write;
use std::process::Command;
use tempfile::NamedTempFile;

use crate::models::{OakEntry, Source};
use crate::schema::SchemaValidator;

/// Open the user's $EDITOR with the given content
/// Returns the edited content after the user closes the editor
fn open_editor(initial_content: &str) -> Result<String> {
    // Get the editor from environment or use a default
    let editor = env::var("EDITOR").unwrap_or_else(|_| "vi".to_string());

    // Create a temporary file with .yaml extension
    let mut temp_file = NamedTempFile::new()
        .context("Failed to create temporary file")?;

    // Write initial content
    temp_file
        .write_all(initial_content.as_bytes())
        .context("Failed to write to temporary file")?;

    let temp_path = temp_file.path().to_path_buf();

    // Spawn the editor and wait for it to complete
    let status = Command::new(&editor)
        .arg(&temp_path)
        .status()
        .context(format!("Failed to launch editor '{}'", editor))?;

    if !status.success() {
        return Err(anyhow!("Editor exited with non-zero status"));
    }

    // Read the edited content
    let edited_content = fs::read_to_string(&temp_path)
        .context("Failed to read edited content")?;

    Ok(edited_content)
}

/// Edit an Oak entry with validation loop
/// If validation fails, the editor is re-opened with the invalid content
pub fn edit_oak_entry(entry: &OakEntry, validator: &SchemaValidator) -> Result<OakEntry> {
    // Convert entry to YAML
    let mut yaml_content = serde_yaml::to_string(entry)
        .context("Failed to serialize entry to YAML")?;

    loop {
        // Open editor
        let edited_yaml = open_editor(&yaml_content)
            .context("Failed to open editor")?;

        // Parse the edited YAML
        let edited_entry: OakEntry = match serde_yaml::from_str(&edited_yaml) {
            Ok(entry) => entry,
            Err(e) => {
                eprintln!("\n❌ Failed to parse YAML: {}", e);
                eprintln!("Press Enter to re-open the editor and fix the error...");
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                yaml_content = edited_yaml;
                continue;
            }
        };

        // Validate the entry
        match validator.validate(&edited_entry) {
            Ok(_) => return Ok(edited_entry),
            Err(e) => {
                eprintln!("\n❌ Validation failed:");
                eprintln!("{}", e);
                eprintln!("\nPress Enter to re-open the editor and fix the errors...");
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                yaml_content = edited_yaml;
            }
        }
    }
}

/// Create a new Oak entry with validation loop
pub fn new_oak_entry(scientific_name: &str, validator: &SchemaValidator) -> Result<OakEntry> {
    let template = OakEntry::new(scientific_name.to_string());
    edit_oak_entry(&template, validator)
}

/// Edit a Source entry
pub fn edit_source(source: &Source) -> Result<Source> {
    // Convert source to YAML
    let mut yaml_content = serde_yaml::to_string(source)
        .context("Failed to serialize source to YAML")?;

    loop {
        // Open editor
        let edited_yaml = open_editor(&yaml_content)
            .context("Failed to open editor")?;

        // Parse the edited YAML
        let edited_source: Source = match serde_yaml::from_str(&edited_yaml) {
            Ok(src) => src,
            Err(e) => {
                eprintln!("\n❌ Failed to parse YAML: {}", e);
                eprintln!("Press Enter to re-open the editor and fix the error...");
                let mut input = String::new();
                std::io::stdin().read_line(&mut input)?;
                yaml_content = edited_yaml;
                continue;
            }
        };

        // Basic validation
        if edited_source.source_id.is_empty() {
            eprintln!("\n❌ source_id cannot be empty");
            eprintln!("Press Enter to re-open the editor and fix the error...");
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            yaml_content = edited_yaml;
            continue;
        }

        if edited_source.name.is_empty() {
            eprintln!("\n❌ name cannot be empty");
            eprintln!("Press Enter to re-open the editor and fix the error...");
            let mut input = String::new();
            std::io::stdin().read_line(&mut input)?;
            yaml_content = edited_yaml;
            continue;
        }

        return Ok(edited_source);
    }
}

/// Create a new source entry interactively
pub fn new_source() -> Result<Source> {
    use dialoguer::Input;

    println!("Creating new source...\n");

    let source_id: String = Input::new()
        .with_prompt("Source ID (unique identifier)")
        .interact_text()?;

    let source_type: String = Input::new()
        .with_prompt("Source Type (Book, Paper, Website, Observation, etc.)")
        .interact_text()?;

    let name: String = Input::new()
        .with_prompt("Name/Title")
        .interact_text()?;

    let author: String = Input::new()
        .with_prompt("Author (optional)")
        .allow_empty(true)
        .interact_text()?;

    let year_str: String = Input::new()
        .with_prompt("Year (optional)")
        .allow_empty(true)
        .interact_text()?;

    let year = if year_str.is_empty() {
        None
    } else {
        Some(year_str.parse().context("Invalid year")?)
    };

    let url: String = Input::new()
        .with_prompt("URL (optional)")
        .allow_empty(true)
        .interact_text()?;

    let isbn: String = Input::new()
        .with_prompt("ISBN (optional)")
        .allow_empty(true)
        .interact_text()?;

    let doi: String = Input::new()
        .with_prompt("DOI (optional)")
        .allow_empty(true)
        .interact_text()?;

    let notes: String = Input::new()
        .with_prompt("Notes (optional)")
        .allow_empty(true)
        .interact_text()?;

    let source = Source {
        source_id,
        source_type,
        name,
        author: if author.is_empty() { None } else { Some(author) },
        year,
        url: if url.is_empty() { None } else { Some(url) },
        isbn: if isbn.is_empty() { None } else { Some(isbn) },
        doi: if doi.is_empty() { None } else { Some(doi) },
        notes: if notes.is_empty() { None } else { Some(notes) },
    };

    Ok(source)
}
