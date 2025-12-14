use serde::{Deserialize, Serialize};

/// Represents a single data point attributed to a specific source
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataPoint {
    /// The attribute value (e.g., "lobed", "green")
    pub value: String,
    /// Foreign key reference to the Source table
    pub source_id: String,
    /// Optional page number or location within the source
    #[serde(skip_serializing_if = "Option::is_none")]
    pub page_number: Option<String>,
}

/// Represents an Oak taxonomic entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OakEntry {
    /// Primary key: Scientific name
    pub scientific_name: String,

    /// Common names
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub common_names: Vec<DataPoint>,

    /// Leaf color
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub leaf_color: Vec<DataPoint>,

    /// Bud shape
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub bud_shape: Vec<DataPoint>,

    /// Leaf shape
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub leaf_shape: Vec<DataPoint>,

    /// Bark texture
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub bark_texture: Vec<DataPoint>,

    /// Habitat
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub habitat: Vec<DataPoint>,

    /// Native range
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub native_range: Vec<DataPoint>,

    /// Height range
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub height: Vec<DataPoint>,

    /// Synonyms
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub synonyms: Vec<String>,
}

impl OakEntry {
    /// Creates a new empty OakEntry with the given scientific name
    pub fn new(scientific_name: String) -> Self {
        Self {
            scientific_name,
            common_names: Vec::new(),
            leaf_color: Vec::new(),
            bud_shape: Vec::new(),
            leaf_shape: Vec::new(),
            bark_texture: Vec::new(),
            habitat: Vec::new(),
            native_range: Vec::new(),
            height: Vec::new(),
            synonyms: Vec::new(),
        }
    }
}

/// Represents a source reference
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Source {
    /// Unique source identifier
    pub source_id: String,

    /// Source type (Book, Paper, Website, Observation, etc.)
    pub source_type: String,

    /// Full name/title of the source
    pub name: String,

    /// Author(s)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub author: Option<String>,

    /// Publication year
    #[serde(skip_serializing_if = "Option::is_none")]
    pub year: Option<i32>,

    /// URL for web sources
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,

    /// ISBN for books
    #[serde(skip_serializing_if = "Option::is_none")]
    pub isbn: Option<String>,

    /// DOI for papers
    #[serde(skip_serializing_if = "Option::is_none")]
    pub doi: Option<String>,

    /// Additional notes
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
}

impl Source {
    /// Creates a new Source with the given ID, type, and name
    pub fn new(source_id: String, source_type: String, name: String) -> Self {
        Self {
            source_id,
            source_type,
            name,
            author: None,
            year: None,
            url: None,
            isbn: None,
            doi: None,
            notes: None,
        }
    }
}
