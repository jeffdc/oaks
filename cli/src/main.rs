mod db;
mod editor;
mod models;
mod schema;
mod commands;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "oak")]
#[command(about = "Oak Compendium CLI - Manage taxonomic data for oak species", long_about = None)]
#[command(version)]
struct Cli {
    /// Path to the database file
    #[arg(short, long, default_value = "oak_compendium.db")]
    database: PathBuf,

    /// Path to the schema file
    #[arg(short, long, default_value = "schema/oak_schema.json")]
    schema: PathBuf,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new Oak entry
    New {
        /// Scientific name of the oak
        name: String,
    },

    /// Edit an existing Oak entry
    Edit {
        /// Scientific name of the oak to edit
        name: String,
    },

    /// Delete an Oak entry
    Delete {
        /// Scientific name of the oak to delete
        name: String,
    },

    /// Search for Oak entries or Sources
    Find {
        /// Search query
        query: String,

        /// Output only IDs (for pipelining)
        #[arg(short, long)]
        id_only: bool,

        /// Search type: oak, source, or both
        #[arg(short = 't', long, default_value = "both")]
        search_type: String,
    },

    /// Manage sources
    #[command(subcommand)]
    Source(SourceCommands),

    /// Add a new enumeration value to a field
    AddValue {
        /// Field name (e.g., leaf_shape)
        field: String,

        /// Value to add
        value: String,
    },

    /// Import data from a file in bulk
    ImportBulk {
        /// Path to the import file (YAML or JSON)
        file: PathBuf,

        /// Source ID to attribute the data to
        #[arg(short, long)]
        source_id: String,
    },
}

#[derive(Subcommand)]
enum SourceCommands {
    /// Create a new source
    New,

    /// Edit an existing source
    Edit {
        /// Source ID to edit
        id: String,
    },

    /// List all sources
    List,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize database and schema
    let db = db::Database::new(cli.database.to_str().unwrap())?;
    let schema = schema::SchemaValidator::from_file(&cli.schema)?;

    match cli.command {
        Commands::New { name } => {
            commands::new::execute(&db, &schema, &name)?;
        }
        Commands::Edit { name } => {
            commands::edit::execute(&db, &schema, &name)?;
        }
        Commands::Delete { name } => {
            commands::delete::execute(&db, &name)?;
        }
        Commands::Find { query, id_only, search_type } => {
            commands::find::execute(&db, &query, id_only, &search_type)?;
        }
        Commands::Source(source_cmd) => match source_cmd {
            SourceCommands::New => {
                commands::source::new(&db)?;
            }
            SourceCommands::Edit { id } => {
                commands::source::edit(&db, &id)?;
            }
            SourceCommands::List => {
                commands::source::list(&db)?;
            }
        },
        Commands::AddValue { field, value } => {
            commands::add_value::execute(&cli.schema, &schema, &field, &value)?;
        }
        Commands::ImportBulk { file, source_id } => {
            commands::import_bulk::execute(&db, &schema, &file, &source_id)?;
        }
    }

    Ok(())
}
