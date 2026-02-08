-- Test seed data for oak_compendium test database
-- Loaded after structure.sql to provide minimal data for tests
--
-- Keep this minimal — only add data that tests actually need

-- =============================================================================
-- Sources
-- =============================================================================

INSERT INTO sources (id, source_type, name, description, url) VALUES
  (1, 'website', 'iNaturalist', 'Authoritative taxonomy and species list', 'https://www.inaturalist.org'),
  (2, 'website', 'Oaks of the World', 'Rich descriptive data (morphology, distribution)', 'https://oaksoftheworld.fr'),
  (3, 'personal_observation', 'Oak Compendium', 'Field notes and curated content', NULL);

-- =============================================================================
-- Taxa
-- =============================================================================

INSERT INTO taxa (id, name, level, parent, author) VALUES
  (1, 'Quercus', 'subgenus', NULL, '(L.) Oerst.'),
  (2, 'Quercus', 'section', 'Quercus', 'L.'),
  (3, 'Lobatae', 'subgenus', NULL, '(Loudon) Menitsky'),
  (4, 'Lobatae', 'section', 'Lobatae', 'Loudon'),
  (5, 'Stellatae', 'subsection', 'Quercus', NULL);

-- =============================================================================
-- Species
-- =============================================================================

INSERT INTO species (id, scientific_name, author, is_hybrid, conservation_status, subgenus, section, subsection) VALUES
  (1, 'alba', 'L. 1753', 0, 'LC', 'Quercus', 'Quercus', NULL),
  (2, 'rubra', 'L. 1753', 0, 'LC', 'Lobatae', 'Lobatae', NULL),
  (3, 'stellata', 'Wangenh. 1787', 0, 'LC', 'Quercus', 'Quercus', 'Stellatae'),
  (4, 'velutina', 'Lam. 1785', 0, 'LC', 'Lobatae', 'Lobatae', NULL);

-- A hybrid
INSERT INTO species (id, scientific_name, author, is_hybrid, parent1, parent2, subgenus, section) VALUES
  (5, '×bebbiana', 'C.K.Schneid.', 1, 'alba', 'macrocarpa', 'Quercus', 'Quercus');

-- Add JSON array relationship data for testing detail page
UPDATE species SET
  hybrids = '["×bebbiana"]',
  closely_related_to = '["stellata"]',
  synonyms = '["alba var. repanda"]',
  subspecies_varieties = '["alba var. latiloba"]'
WHERE id = 1;

-- =============================================================================
-- Species Sources (junction data)
-- =============================================================================

INSERT INTO species_sources (id, species_id, source_id, local_names, range, growth_habit, leaves, is_preferred) VALUES
  (1, 1, 2, '["white oak","eastern white oak"]', 'Eastern North America; 0 to 1600 m', 'Reaches 25 m high', '8-20 cm long, obovate', 1),
  (2, 1, 1, NULL, NULL, NULL, NULL, 0),
  (3, 2, 2, '["northern red oak"]', 'Eastern North America', 'Reaches 25-35 m', '12-22 cm long', 1),
  (4, 3, 3, '["post oak"]', 'Eastern US', NULL, '10-18 cm, cross-shaped', 1);

-- =============================================================================
-- Articles
-- =============================================================================

INSERT INTO articles (id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at) VALUES
  (1, 'getting-started', 'Getting Started with Oak Identification', 'Jeff', '# Getting Started

Start by looking at the **leaves**. Oak leaves have distinctive lobed shapes.

## Key Features

- Leaf shape and lobe pattern
- Acorn size and cap coverage
- Bark texture and color

> The best way to learn is to go outside and observe.', '["guide","beginner"]', 1, '2025-01-01T00:00:00Z', '2025-01-15T00:00:00Z', '2025-01-01T00:00:00Z'),
  (2, 'advanced-taxonomy-draft', 'Advanced Oak Taxonomy', 'Jeff', 'This is a **draft** about oak taxonomy.', '["taxonomy","advanced"]', 0, '2025-02-01T00:00:00Z', '2025-02-10T00:00:00Z', NULL);

-- =============================================================================
-- Import Metadata
-- =============================================================================

INSERT INTO import_metadata (key, value) VALUES
  ('last_import_date', '2025-01-01'),
  ('inat_species_count', '450');
