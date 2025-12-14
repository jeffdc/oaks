-- Quercus Database Schema
-- Source-attributed data model for oak species information
--
-- Core Principles:
-- - Species and taxonomy are opinionated facts we curate
-- - All observational data is source-attributed
-- - Sources can be marked as preferred
-- - A synthetic/curated source represents our reconciled data

-- =============================================================================
-- TAXONOMY TABLES
-- =============================================================================
-- Hierarchical taxonomy structure for oak species
-- Hierarchy: Genus > Subgenus > Section > Subsection > Complex
-- All ranks are optional except Genus

CREATE TABLE genera (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,    -- e.g., "Quercus"
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE subgenera (
    id INTEGER PRIMARY KEY,
    genus_id INTEGER NOT NULL REFERENCES genera(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,           -- e.g., "Quercus", "Cerris", "Cyclobalanopsis"
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(genus_id, name)
);

CREATE INDEX idx_subgenera_genus ON subgenera(genus_id);

CREATE TABLE sections (
    id INTEGER PRIMARY KEY,
    subgenus_id INTEGER NOT NULL REFERENCES subgenera(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,           -- e.g., "Lobatae", "Quercus", "Ilex"
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subgenus_id, name)
);

CREATE INDEX idx_sections_subgenus ON sections(subgenus_id);

CREATE TABLE subsections (
    id INTEGER PRIMARY KEY,
    section_id INTEGER NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,           -- e.g., "Coccineae", "Dumosae", "Albae"
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(section_id, name)
);

CREATE INDEX idx_subsections_section ON subsections(section_id);

CREATE TABLE complexes (
    id INTEGER PRIMARY KEY,
    subsection_id INTEGER NOT NULL REFERENCES subsections(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,           -- e.g., "Q. shumardii complex"
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(subsection_id, name)
);

CREATE INDEX idx_complexes_subsection ON complexes(subsection_id);

-- =============================================================================
-- CONTROLLED VOCABULARIES
-- =============================================================================

CREATE TABLE conservation_statuses (
    id INTEGER PRIMARY KEY,
    code VARCHAR(2) NOT NULL UNIQUE, -- EN, VU, CR, NT, LC, DD, NE, EX, EW
    name VARCHAR(100) NOT NULL,      -- e.g., "Endangered", "Vulnerable"
    description TEXT
);

CREATE TABLE leaf_persistence (
    id INTEGER PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE, -- deciduous, evergreen, semi-evergreen
    description TEXT
);

-- =============================================================================
-- SOURCES
-- =============================================================================

CREATE TABLE sources (
    id INTEGER PRIMARY KEY,
    name VARCHAR(500) NOT NULL,           -- Title/name of source
    type VARCHAR(50),                     -- website, journal, book, observation, synthetic
    url TEXT,                             -- URL if applicable
    is_synthetic BOOLEAN DEFAULT FALSE,   -- TRUE for our curated/reconciled source
    author VARCHAR(500),                  -- Author(s) if applicable
    year INTEGER,                         -- Publication year if applicable
    publisher VARCHAR(500),               -- Publisher if applicable
    notes TEXT,                           -- Additional metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- SPECIES (Core Facts)
-- =============================================================================

CREATE TABLE species (
    id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL UNIQUE,    -- Species name WITHOUT "Quercus" prefix
    is_hybrid BOOLEAN NOT NULL DEFAULT FALSE,
    author VARCHAR(500),                  -- Taxonomic authority (e.g., "L. 1753")

    -- Taxonomy (opinionated/curated classification)
    genus_id INTEGER NOT NULL REFERENCES genera(id),
    subgenus_id INTEGER REFERENCES subgenera(id),
    section_id INTEGER REFERENCES sections(id),
    subsection_id INTEGER REFERENCES subsections(id),
    complex_id INTEGER REFERENCES complexes(id),

    -- Conservation status (species-level fact)
    conservation_status_id INTEGER REFERENCES conservation_statuses(id),

    -- Hybrid parentage (only for hybrids, structural facts)
    parent1 VARCHAR(200),                 -- Full species name (e.g., "Quercus alba")
    parent2 VARCHAR(200),                 -- Full species name
    parent_formula TEXT,                  -- Text description of parentage

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CHECK (
        (is_hybrid = FALSE AND parent1 IS NULL AND parent2 IS NULL AND parent_formula IS NULL) OR
        (is_hybrid = TRUE)
    )
);

CREATE INDEX idx_species_name ON species(name);
CREATE INDEX idx_species_is_hybrid ON species(is_hybrid);
CREATE INDEX idx_species_genus ON species(genus_id);
CREATE INDEX idx_species_subgenus ON species(subgenus_id);
CREATE INDEX idx_species_section ON species(section_id);
CREATE INDEX idx_species_subsection ON species(subsection_id);
CREATE INDEX idx_species_complex ON species(complex_id);

-- =============================================================================
-- SPECIES-SOURCE DATA (Source-Attributed Observations)
-- =============================================================================

CREATE TABLE species_source_data (
    id INTEGER PRIMARY KEY,
    species_id INTEGER NOT NULL REFERENCES species(id) ON DELETE CASCADE,
    source_id INTEGER NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    is_preferred BOOLEAN DEFAULT FALSE,   -- Mark preferred source for this species

    -- Morphological descriptions (free text, always preserved)
    leaves TEXT,
    flowers TEXT,
    fruits TEXT,
    bark_twigs_buds TEXT,
    growth_habit TEXT,
    range TEXT,
    hardiness_habitat TEXT,
    additional_info TEXT,                 -- Miscellaneous notes
    taxonomy TEXT,                        -- Source-reported taxonomy (free text)

    -- Structured data extracted from text (optional, for querying)
    -- Height (from growth_habit)
    height_min REAL,                      -- meters
    height_max REAL,                      -- meters

    -- Elevation (from range)
    elevation_min REAL,                   -- meters
    elevation_max REAL,                   -- meters

    -- Hardiness zones (from hardiness_habitat)
    hardiness_zone_min VARCHAR(3),        -- e.g., "8a"
    hardiness_zone_max VARCHAR(3),        -- e.g., "10a"

    -- Leaf persistence (from leaves text)
    leaf_persistence_id INTEGER REFERENCES leaf_persistence(id),

    -- Acorn maturation (from fruits text)
    acorn_maturation_years INTEGER,       -- 1 or 2

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE(species_id, source_id),        -- One record per species-source pair
    CHECK (acorn_maturation_years IN (1, 2) OR acorn_maturation_years IS NULL),
    CHECK (hardiness_zone_min IS NULL OR hardiness_zone_min ~ '^[0-9]{1,2}[ab]$'),
    CHECK (hardiness_zone_max IS NULL OR hardiness_zone_max ~ '^[0-9]{1,2}[ab]$')
);

CREATE INDEX idx_species_source_data_species ON species_source_data(species_id);
CREATE INDEX idx_species_source_data_source ON species_source_data(source_id);
CREATE INDEX idx_species_source_data_preferred ON species_source_data(is_preferred);

-- =============================================================================
-- SOURCE-ATTRIBUTED RELATED DATA
-- =============================================================================

CREATE TABLE synonyms (
    id INTEGER PRIMARY KEY,
    species_source_data_id INTEGER NOT NULL REFERENCES species_source_data(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,           -- Synonym name (without "Quercus" prefix)
    author VARCHAR(500),                  -- Taxonomic authority for synonym
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_synonyms_species_source ON synonyms(species_source_data_id);
CREATE INDEX idx_synonyms_name ON synonyms(name);

CREATE TABLE local_names (
    id INTEGER PRIMARY KEY,
    species_source_data_id INTEGER NOT NULL REFERENCES species_source_data(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,           -- Common/local name
    language VARCHAR(50),                 -- Optional language code (e.g., "en", "zh")
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_local_names_species_source ON local_names(species_source_data_id);

CREATE TABLE subspecies_varieties (
    id INTEGER PRIMARY KEY,
    species_source_data_id INTEGER NOT NULL REFERENCES species_source_data(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,           -- Subspecies/variety name
    author VARCHAR(500),                  -- Taxonomic authority
    description TEXT,                     -- Additional details
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_subspecies_varieties_species_source ON subspecies_varieties(species_source_data_id);

-- =============================================================================
-- SEED DATA - Controlled Vocabularies
-- =============================================================================

-- Conservation statuses (IUCN Red List categories)
INSERT INTO conservation_statuses (code, name, description) VALUES
    ('EX', 'Extinct', 'No known individuals remaining'),
    ('EW', 'Extinct in the Wild', 'Known only to survive in cultivation'),
    ('CR', 'Critically Endangered', 'Extremely high risk of extinction in the wild'),
    ('EN', 'Endangered', 'High risk of extinction in the wild'),
    ('VU', 'Vulnerable', 'High risk of endangerment in the wild'),
    ('NT', 'Near Threatened', 'Likely to become endangered in the near future'),
    ('LC', 'Least Concern', 'Lowest risk; does not qualify for a higher risk category'),
    ('DD', 'Data Deficient', 'Not enough data to make an assessment'),
    ('NE', 'Not Evaluated', 'Has not yet been evaluated');

-- Leaf persistence types
INSERT INTO leaf_persistence (name, description) VALUES
    ('deciduous', 'Leaves fall seasonally'),
    ('evergreen', 'Leaves persist year-round'),
    ('semi-evergreen', 'Partially deciduous depending on climate');

-- Genus (seed with Quercus)
INSERT INTO genera (name, description) VALUES
    ('Quercus', 'Oak genus containing approximately 600 extant species');
