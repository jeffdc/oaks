use anyhow::{anyhow, Context, Result};
use dialoguer::Select;
use std::fs;
use std::path::Path;

use crate::db::Database;
use crate::editor;
use crate::models::{DataPoint, OakEntry};
use crate::schema::SchemaValidator;

/// Represents a conflict between database and import data
#[derive(Debug)]
struct Conflict {
    field_name: String,
    db_value: String,
    import_value: String,
}

/// Execute the 'oak import-bulk' command
pub fn execute(
    db: &Database,
    validator: &SchemaValidator,
    file_path: &Path,
    source_id: &str,
) -> Result<()> {
    // Verify source exists
    if db.get_source(source_id)?.is_none() {
        return Err(anyhow!(
            "Source '{}' not found. Create it first with 'oak source new'.",
            source_id
        ));
    }

    eprintln!("Importing data from: {}", file_path.display());
    eprintln!("Attributing to source: {}", source_id);

    // Read and parse the import file
    let content = fs::read_to_string(file_path).context("Failed to read import file")?;

    let entries: Vec<OakEntry> = if file_path.extension().and_then(|s| s.to_str()) == Some("json") {
        serde_json::from_str(&content).context("Failed to parse JSON import file")?
    } else {
        // Assume YAML
        serde_yaml::from_str(&content).context("Failed to parse YAML import file")?
    };

    eprintln!("Found {} entries to import", entries.len());

    let mut imported_count = 0;
    let mut skipped_count = 0;
    let mut updated_count = 0;

    // Process each entry
    for import_entry in entries {
        eprintln!("\nProcessing: {}", import_entry.scientific_name);

        // Validate the entry
        if let Err(e) = validator.validate(&import_entry) {
            eprintln!(
                "⚠ Validation failed for '{}': {}",
                import_entry.scientific_name, e
            );
            eprintln!("Skipping entry.");
            skipped_count += 1;
            continue;
        }

        // Check if entry exists
        let existing_entry = db.get_oak_entry(&import_entry.scientific_name)?;

        if let Some(mut existing) = existing_entry {
            // Detect conflicts
            let conflicts = detect_conflicts(&existing, &import_entry, source_id);

            if conflicts.is_empty() {
                // No conflicts, merge the data
                merge_entries(&mut existing, &import_entry, source_id);
                db.save_oak_entry(&existing)?;
                eprintln!("✓ Merged data for '{}'", existing.scientific_name);
                updated_count += 1;
            } else {
                // Handle conflicts
                eprintln!(
                    "⚠ Found {} conflict(s) for '{}'",
                    conflicts.len(),
                    import_entry.scientific_name
                );

                match handle_conflicts(
                    db,
                    validator,
                    &mut existing,
                    &import_entry,
                    source_id,
                    &conflicts,
                )? {
                    ConflictResolution::Resolved(entry) => {
                        db.save_oak_entry(&entry)?;
                        eprintln!("✓ Resolved conflicts and saved '{}'", entry.scientific_name);
                        updated_count += 1;
                    }
                    ConflictResolution::Skipped => {
                        eprintln!("⊘ Skipped '{}'", import_entry.scientific_name);
                        skipped_count += 1;
                    }
                }
            }
        } else {
            // New entry, just save it
            db.save_oak_entry(&import_entry)?;
            eprintln!("✓ Created new entry for '{}'", import_entry.scientific_name);
            imported_count += 1;
        }
    }

    eprintln!("\n=== Import Summary ===");
    eprintln!("New entries:     {}", imported_count);
    eprintln!("Updated entries: {}", updated_count);
    eprintln!("Skipped entries: {}", skipped_count);

    Ok(())
}

/// Detect conflicts where the same source_id has different values
fn detect_conflicts(existing: &OakEntry, import: &OakEntry, source_id: &str) -> Vec<Conflict> {
    let mut conflicts = Vec::new();

    // Helper to check conflicts for a field
    let check_field = |field_name: &str,
                       existing_points: &[DataPoint],
                       import_points: &[DataPoint]|
     -> Vec<Conflict> {
        let mut field_conflicts = Vec::new();

        // Find data points in import that have the same source_id as in existing
        for import_dp in import_points {
            if import_dp.source_id == source_id {
                // Check if there's an existing data point with the same source_id
                if let Some(existing_dp) =
                    existing_points.iter().find(|dp| dp.source_id == source_id)
                {
                    if existing_dp.value != import_dp.value {
                        field_conflicts.push(Conflict {
                            field_name: field_name.to_string(),
                            db_value: existing_dp.value.clone(),
                            import_value: import_dp.value.clone(),
                        });
                    }
                }
            }
        }

        field_conflicts
    };

    conflicts.extend(check_field(
        "common_names",
        &existing.common_names,
        &import.common_names,
    ));
    conflicts.extend(check_field(
        "leaf_color",
        &existing.leaf_color,
        &import.leaf_color,
    ));
    conflicts.extend(check_field(
        "bud_shape",
        &existing.bud_shape,
        &import.bud_shape,
    ));
    conflicts.extend(check_field(
        "leaf_shape",
        &existing.leaf_shape,
        &import.leaf_shape,
    ));
    conflicts.extend(check_field(
        "bark_texture",
        &existing.bark_texture,
        &import.bark_texture,
    ));
    conflicts.extend(check_field("habitat", &existing.habitat, &import.habitat));
    conflicts.extend(check_field(
        "native_range",
        &existing.native_range,
        &import.native_range,
    ));
    conflicts.extend(check_field("height", &existing.height, &import.height));

    conflicts
}

/// Merge import entry into existing entry (no conflicts)
fn merge_entries(existing: &mut OakEntry, import: &OakEntry, _source_id: &str) {
    // Helper to merge field data points
    let merge_field = |existing_points: &mut Vec<DataPoint>, import_points: &[DataPoint]| {
        for import_dp in import_points {
            // Only add if source_id doesn't already exist
            if !existing_points
                .iter()
                .any(|dp| dp.source_id == import_dp.source_id)
            {
                existing_points.push(import_dp.clone());
            }
        }
    };

    merge_field(&mut existing.common_names, &import.common_names);
    merge_field(&mut existing.leaf_color, &import.leaf_color);
    merge_field(&mut existing.bud_shape, &import.bud_shape);
    merge_field(&mut existing.leaf_shape, &import.leaf_shape);
    merge_field(&mut existing.bark_texture, &import.bark_texture);
    merge_field(&mut existing.habitat, &import.habitat);
    merge_field(&mut existing.native_range, &import.native_range);
    merge_field(&mut existing.height, &import.height);

    // Merge synonyms
    for syn in &import.synonyms {
        if !existing.synonyms.contains(syn) {
            existing.synonyms.push(syn.clone());
        }
    }
}

enum ConflictResolution {
    Resolved(OakEntry),
    Skipped,
}

/// Handle conflicts interactively
fn handle_conflicts(
    _db: &Database,
    validator: &SchemaValidator,
    existing: &mut OakEntry,
    import: &OakEntry,
    source_id: &str,
    conflicts: &[Conflict],
) -> Result<ConflictResolution> {
    for conflict in conflicts {
        eprintln!(
            "\nConflict for {}, field: {} (Source: {})",
            existing.scientific_name, conflict.field_name, source_id
        );
        eprintln!("[1] Database Value: '{}'", conflict.db_value);
        eprintln!("[2] Imported Value: '{}'", conflict.import_value);

        let choices = vec![
            "Keep database value",
            "Use imported value",
            "Merge manually (open editor)",
            "Skip this entry",
        ];

        let selection = Select::new()
            .with_prompt("Choose resolution")
            .items(&choices)
            .default(0)
            .interact()?;

        match selection {
            0 => {
                // Keep database value (do nothing)
                eprintln!("Keeping database value.");
            }
            1 => {
                // Use imported value
                eprintln!("Using imported value.");
                replace_field_value(
                    existing,
                    &conflict.field_name,
                    source_id,
                    &conflict.import_value,
                );
            }
            2 => {
                // Open editor for manual merge
                eprintln!("Opening editor for manual resolution...");
                let merged = editor::edit_oak_entry(existing, validator)?;
                // After manual editing, save the non-conflicting data from import too
                merge_entries(&mut merged.clone(), import, source_id);
                return Ok(ConflictResolution::Resolved(merged));
            }
            3 => {
                // Skip entry
                return Ok(ConflictResolution::Skipped);
            }
            _ => unreachable!(),
        }
    }

    // After resolving all conflicts, merge non-conflicting data
    merge_entries(existing, import, source_id);

    Ok(ConflictResolution::Resolved(existing.clone()))
}

/// Replace a field value for a specific source
fn replace_field_value(entry: &mut OakEntry, field_name: &str, source_id: &str, new_value: &str) {
    let update_field = |points: &mut Vec<DataPoint>| {
        if let Some(dp) = points.iter_mut().find(|dp| dp.source_id == source_id) {
            dp.value = new_value.to_string();
        }
    };

    match field_name {
        "common_names" => update_field(&mut entry.common_names),
        "leaf_color" => update_field(&mut entry.leaf_color),
        "bud_shape" => update_field(&mut entry.bud_shape),
        "leaf_shape" => update_field(&mut entry.leaf_shape),
        "bark_texture" => update_field(&mut entry.bark_texture),
        "habitat" => update_field(&mut entry.habitat),
        "native_range" => update_field(&mut entry.native_range),
        "height" => update_field(&mut entry.height),
        _ => {}
    }
}
