-- Test seed data for oak_compendium test database
-- Loaded after the migrations (make test-db) to provide minimal data for tests
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
-- Import Metadata
-- =============================================================================

INSERT INTO import_metadata (key, value) VALUES
  ('last_import_date', '2025-01-01'),
  ('inat_species_count', '450');
