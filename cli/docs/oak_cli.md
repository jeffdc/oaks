# 🌳 Oak Compendium CLI Tool Specification

## 1. Overview and Goals

This document specifies the requirements for a Command Line Interface (CLI) tool designed to manage the taxonomic and identification data for the Oak Compendium database.

The primary goal is to provide a highly efficient, powerful, and scriptable interface for a single **power-user** to maintain data integrity, manage sources, and perform complex merges. The tool must prioritize speed, strict data validation, and compatibility with standard CLI pipelining.

## 2. Constraints and User Profile

* **User:** Single, highly technical user (Power User).
* **Optimization:** Tool must be optimized for keystroke efficiency and scriptability (pipelining).
* **Data Integrity:** Validation must be **Strict**, preventing bad data from entering the system.
* **Interaction Model:** Primarily non-GUI; leveraging the user's `$EDITOR` for structured input.

## 3. Data Architecture Model

The key architectural constraint is that an **Oak Entry** is a container for data points, where every data point is explicitly tied to a **Source**. Conflicts are only possible when updating data points attributed to the *same* source.

### A. Core Entities

| Entity | Primary Key | Description |
| :--- | :--- | :--- |
| **Oak Entry** | `scientific_name` | The taxonomic entry (Species, Hybrid, Cultivar). Must support synonym tracking. |
| **Source** | `source_id` (Unique ID) | A specific reference (Book, Paper, Website, Observation). |
| **Data Point** | N/A | An attribute (e.g., `leaf_color`, `bud_shape`) linked to exactly one `source_id`. |

### B. Conflict Rule

* **Non-Conflict:** If an imported entry contains a value for `leaf_color` attributed to `Source B`, and the database already has a value for `leaf_color` attributed to `Source A`, **this is not a conflict.** The tool simply adds the new data point.
* **Conflict:** A conflict only occurs if the imported data attempts to overwrite an existing Data Point attributed to the *same* `source_id`.

## 4. CLI Interface Design & Commands (MVP)

The tool shall use a single primary executable, `oak`, with subcommands for distinct operations.

### A. Core Library Management

| Command | Description | Workflow |
| :--- | :--- | :--- |
| `oak new` | Create a new Oak Entry. | Scaffolds a blank data template and opens it in the user's `$EDITOR`. |
| `oak edit <name>` | Modify an existing Oak Entry. | Retrieves the existing entry's full data (e.g., as YAML), opens it in `$EDITOR`. |
| `oak delete <name>` | Remove an Oak Entry. | Requires explicit `Y/N` confirmation. |

### B. Search and Pipelining

The `find` command is critical for integration with shell scripting.

| Command | Description | Output Behavior |
| :--- | :--- | :--- |
| `oak find <query> [-i/--id-only]` | Searches Oak Entries, Sources, or both. | **Default:** Human-readable list of results. **Pipelined:** If the `-i` or `--id-only` flag is used, outputs **only** the unique identifiers of matching entities (one ID per line) to `stdout`. |

### C. Source Management

| Command | Description | Output Behavior |
| :--- | :--- | :--- |
| `oak source new` | Creates a new Source entry via interactive prompts for required Source fields. | Outputs the newly generated `source_id` to `stdout`. |
| `oak source edit <ID>` | Modifies an existing Source entry. | Opens the Source data in `$EDITOR`. |
| `oak source list` | Displays all existing Sources. | Human-readable table (ID, Name, Type) for reference. |

### D. Schema and Validation Management

| Command | Description | Function |
| :--- | :--- | :--- |
| `oak add-value <field> <value>` | Adds a new permitted enumeration value (e.g., 'Square') to a validated field (e.g., `leaf_shape`). | Updates the underlying schema definition file and outputs success status to `stdout`. |

### E. Complex Import Workflow

| Command | Description | Syntax |
| :--- | :--- | :--- |
| `oak import-bulk` | Imports data from a file, handles merging, and resolves source-attributed conflicts interactively. | `oak import-bulk <file_path> --source-id <ID>` |

## 5. Core Feature Workflows

### 5.1 The `$EDITOR` Edit/New Workflow (`oak new`, `oak edit`)

1.  **Preparation:** The tool fetches the data/template and converts it to a clean, human-readable format (e.g., YAML) and writes it to a temporary file.
2.  **Editing:** The tool launches the user's environment variable `$EDITOR` (or a defined fallback) to open the temporary file.
3.  **Completion:** Upon the user saving and closing the editor, the tool reads the modified file.
4.  **Validation:** The tool strictly validates the modified data against the schema (including required fields and permitted enumeration values).
    * *If invalid:* The tool rejects the save, explains the error (e.g., "Invalid value 'Square' for field `leaf_shape`"), and **re-opens the temporary file** in the editor for the user to fix, preventing data loss.
    * *If valid:* The changes are persisted to the database.

### 5.2 Bulk Import and Merge Workflow (`oak import-bulk`)

1.  **Input:** The tool reads the data from `<file_path>` and validates that the provided `--source-id` exists.
2.  **Conflict Detection:** For each entry, the tool identifies Data Points in the import file that differ from Data Points already in the database and attributed to the **same** `--source-id`.
3.  **Interactive Conflict Resolution (Option A):** If a conflict is found, the tool pauses and enters an interactive prompt:
    ```
    Conflict for Quercus robur, field: leaf_color (Source: <ID>)
    [1] Database Value: '<existing_value>'
    [2] Imported Value: '<new_value>'
    [3] Merge Manually (Open Editor for this specific entry)
    [S] Skip this entry and continue
    > Enter choice (1/2/3/S):
    ```
4.  **Resolution Logic:**
    * Choosing **[1]** or **[2]** resolves the conflict for that field.
    * Choosing **[3]** opens the entry in `$EDITOR`, allowing the user to manually resolve all conflicts for that entry at once.
    * Choosing **[S]** skips the entry entirely.
5.  **Saving:** All non-conflicting new entries and successfully resolved entries are committed to the database.

That is a perfect transition. As a Software Architect, my focus now shifts from *what* to build to *how* to build it robustly and efficiently, considering the complex data model and the need for a powerful CLI.

Given the requirements—a structured data model, strict validation, interactive workflows, and high performance—I have prioritized language and tools that excel in type safety, CLI development, and data integrity.

Here is the final section detailing the technical recommendations, complete with necessary guardrails and decisions.

-----

# 6\. Technical Architecture and Implementation Details

This section defines the core technology stack and implementation decisions to guide the development process, ensuring the resulting tool is maintainable, robust, and meets the power-user requirements.

## 6.1. Core Technology Stack Decision

| Component | Recommendation | Rationale | Guardrail/Constraint |
| :--- | :--- | :--- | :--- |
| **Language** | **Rust** | Excellent performance, robust type system, and superior tooling for building reliable, self-contained binaries. The strict ownership model enforces data safety, ideal for complex merge logic. | Must use the **latest stable version**. All external dependencies must be actively maintained. |
| **Data Storage (Database)** | **SQLite (via `rusqlite` or similar library)** | Simple, file-based, single-user database—perfect for a headless, single-user CLI. Eliminates the overhead of managing a separate database server. | All data **must** be managed via an abstraction layer (Repository Pattern) to separate business logic from storage implementation. |
| **Data Serialization** | **YAML (for `$EDITOR` interface)** | YAML is human-readable and widely accepted for configuration and structured data editing, which is ideal for the `$EDITOR` workflow. | Use the `serde` framework extensively for robust serialization/deserialization and error handling. |
| **CLI Framework** | **`clap` (Command Line Argument Parser)** | The industry standard in Rust for building complex, well-documented CLIs, supporting subcommands (`oak source new`) and pipelining flags (`-i`). | Must generate comprehensive usage help messages (`--help`) for all commands. |

## 6.2. Data Model Implementation and Validation

### A. Schema Definition and Validation

**Decision:** The data schema and its enumerations (e.g., the list of valid `leaf_shape` strings) must be defined in a separate, version-controlled **JSON Schema** file.

  * **Implementation:** Use a library that can validate data structures against this schema file at runtime (e.g., Rust's `jsonschema` crate).
  * **Guardrail:** The `oak new` and `oak edit` commands **must** load and validate the user's input against this schema *before* attempting a database transaction.
  * **`oak add-value`:** This command will be the only mechanism that programmatically modifies and updates the JSON Schema file for approved enumerated values.

### B. Source-Attributed Data Structure

The central constraint of the architecture (Section 3) must be reflected in the code structure.

  * **Rust Struct:** Every data point field on the Oak Entry (e.g., `leaf_color`) should be represented internally as a vector of structs:

    ```rust
    struct DataPoint {
        value: String,         // The attribute value (e.g., "lobed", "green")
        source_id: String,     // FK reference to the Source table
        // Optional: page_number: Option<String>, 
    }

    struct OakEntry {
        scientific_name: String,
        leaf_color: Vec<DataPoint>,
        bud_shape: Vec<DataPoint>,
        // ... other attributes
    }
    ```

## 6.3. Core Workflow Implementation Guardrails

### A. The `$EDITOR` Workflow

  * **Process Management:** Use a library to safely spawn and await the user's `$EDITOR` process (e.g., reading the `EDITOR` environment variable).
  * **Error Handling:** If the user's edited YAML file fails validation:
    1.  The original file must be saved to a `.bak` file.
    2.  The error reason must be printed clearly to the console.
    3.  The editor **must** be immediately re-launched with the problematic file, forcing the user to correct the error before proceeding.

### B. Bulk Import and Merge (`oak import-bulk`)

  * **Transaction Safety:** The entire bulk import process **must** be wrapped in a single database transaction. If the process is canceled by the user (e.g., via `Ctrl+C`) or fails unexpectedly mid-way, the entire transaction must be rolled back to maintain data integrity.
  * **Conflict Resolution:** The interactive conflict prompt (Section 5.2) should be implemented using a dedicated library for interactive terminal prompts (e.g., the `dialoguer` crate), ensuring a polished user experience.

### C. Pipelining (`oak find -i`)

  * **Output Format:** When the `-i` flag is used, the output to `stdout` **must be strictly** the unique IDs of the matching entities, with each ID on a new line, and absolutely **no other output** (e.g., logs, headers, warnings) to `stdout` to ensure successful piping into tools like `xargs`. All non-ID output should be directed to `stderr`.