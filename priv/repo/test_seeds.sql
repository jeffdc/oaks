-- Test seed data for oak_compendium test database
-- Loaded after the migrations (make test-db) as a minimal baseline: the
-- three data sources and the two subgenus roots.
--
-- Tests never read these rows. Each test builds its own data with the
-- fixture modules in test/support/fixtures/ and asserts only on rows it
-- created, so changing the seeds needs no test change.

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

-- The genus row (id 1) is created by the taxa migration; these hang from it.
INSERT INTO taxa (id, name, level, parent_id, parent, author) VALUES
  (2, 'Quercus', 'subgenus', 1, NULL, '(L.) Oerst.'),
  (3, 'Lobatae', 'subgenus', 1, NULL, '(Loudon) Menitsky');
