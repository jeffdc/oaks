package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/jeff/oaks/api/embed"
	"github.com/jeff/oaks/cli/internal/client"
	"github.com/jeff/oaks/cli/internal/config"
)

// Integration tests for CLI embedded and remote modes.
// These tests verify that the CLI architecture correctly routes operations
// through either the embedded API server (--local) or a remote API (--profile).

// TestEmbeddedAPI_CRUD verifies CRUD operations work correctly through the embedded API.
func TestEmbeddedAPI_CRUD(t *testing.T) {
	// Create a temporary database
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Start embedded server
	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	// Create client pointing at embedded server
	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	// Test species CRUD
	t.Run("Species_Create", func(t *testing.T) {
		species, err := c.CreateSpecies(&client.SpeciesRequest{
			ScientificName: "alba",
			IsHybrid:       false,
		})
		if err != nil {
			t.Fatalf("CreateSpecies failed: %v", err)
		}
		if species.ScientificName != "alba" {
			t.Errorf("ScientificName = %q, want %q", species.ScientificName, "alba")
		}
	})

	t.Run("Species_Get", func(t *testing.T) {
		species, err := c.GetSpecies("alba")
		if err != nil {
			t.Fatalf("GetSpecies failed: %v", err)
		}
		if species.ScientificName != "alba" {
			t.Errorf("ScientificName = %q, want %q", species.ScientificName, "alba")
		}
	})

	t.Run("Species_List", func(t *testing.T) {
		resp, err := c.ListSpecies(nil)
		if err != nil {
			t.Fatalf("ListSpecies failed: %v", err)
		}
		if len(resp.Data) != 1 {
			t.Errorf("got %d species, want 1", len(resp.Data))
		}
	})

	t.Run("Species_Update", func(t *testing.T) {
		author := "L. 1753"
		species, err := c.UpdateSpecies("alba", &client.SpeciesRequest{
			ScientificName: "alba",
			Author:         &author,
		})
		if err != nil {
			t.Fatalf("UpdateSpecies failed: %v", err)
		}
		if species.Author == nil || *species.Author != author {
			t.Errorf("Author = %v, want %q", species.Author, author)
		}
	})

	t.Run("Species_Delete", func(t *testing.T) {
		if err := c.DeleteSpecies("alba"); err != nil {
			t.Fatalf("DeleteSpecies failed: %v", err)
		}

		// Verify deletion
		_, err := c.GetSpecies("alba")
		if !client.IsNotFoundError(err) {
			t.Errorf("expected not found error, got %v", err)
		}
	})
}

// TestEmbeddedAPI_Taxa verifies taxa operations work through the embedded API.
func TestEmbeddedAPI_Taxa(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	t.Run("Taxa_Create", func(t *testing.T) {
		taxon, err := c.CreateTaxon(&client.TaxonRequest{
			Name:  "Lobatae",
			Level: "section",
		})
		if err != nil {
			t.Fatalf("CreateTaxon failed: %v", err)
		}
		if taxon.Name != "Lobatae" {
			t.Errorf("Name = %q, want %q", taxon.Name, "Lobatae")
		}
	})

	t.Run("Taxa_Get", func(t *testing.T) {
		taxon, err := c.GetTaxon("section", "Lobatae")
		if err != nil {
			t.Fatalf("GetTaxon failed: %v", err)
		}
		if taxon.Name != "Lobatae" {
			t.Errorf("Name = %q, want %q", taxon.Name, "Lobatae")
		}
	})

	t.Run("Taxa_List", func(t *testing.T) {
		resp, err := c.ListTaxa(nil)
		if err != nil {
			t.Fatalf("ListTaxa failed: %v", err)
		}
		if len(resp.Data) != 1 {
			t.Errorf("got %d taxa, want 1", len(resp.Data))
		}
	})
}

// TestEmbeddedAPI_Sources verifies source operations work through the embedded API.
func TestEmbeddedAPI_Sources(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	t.Run("Sources_Create", func(t *testing.T) {
		source, err := c.CreateSource(&client.SourceRequest{
			SourceType: "Website",
			Name:       "Test Source",
		})
		if err != nil {
			t.Fatalf("CreateSource failed: %v", err)
		}
		if source.Name != "Test Source" {
			t.Errorf("Name = %q, want %q", source.Name, "Test Source")
		}
		if source.ID == 0 {
			t.Error("expected non-zero ID")
		}
	})

	t.Run("Sources_List", func(t *testing.T) {
		sources, err := c.ListSources()
		if err != nil {
			t.Fatalf("ListSources failed: %v", err)
		}
		if len(sources) != 1 {
			t.Errorf("got %d sources, want 1", len(sources))
		}
	})
}

// TestEmbeddedAPI_BidirectionalHybridRelationships verifies that saving a hybrid
// automatically updates the parent species' hybrids list.
func TestEmbeddedAPI_BidirectionalHybridRelationships(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	// Create parent species
	t.Run("Setup_Parents", func(t *testing.T) {
		for _, name := range []string{"alba", "macrocarpa", "rubra"} {
			_, err := c.CreateSpecies(&client.SpeciesRequest{
				ScientificName: name,
				IsHybrid:       false,
			})
			if err != nil {
				t.Fatalf("CreateSpecies(%s) failed: %v", name, err)
			}
		}
	})

	// Create hybrid with parents
	t.Run("Create_Hybrid", func(t *testing.T) {
		parent1 := "alba"
		parent2 := "macrocarpa"
		_, err := c.CreateSpecies(&client.SpeciesRequest{
			ScientificName: "× bebbiana",
			IsHybrid:       true,
			Parent1:        &parent1,
			Parent2:        &parent2,
		})
		if err != nil {
			t.Fatalf("CreateSpecies(hybrid) failed: %v", err)
		}
	})

	// Verify parents have the hybrid in their hybrids list
	t.Run("Verify_ParentHybrids", func(t *testing.T) {
		alba, err := c.GetSpecies("alba")
		if err != nil {
			t.Fatalf("GetSpecies(alba) failed: %v", err)
		}
		if !sliceContains(alba.Hybrids, "× bebbiana") {
			t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana'", alba.Hybrids)
		}

		macrocarpa, err := c.GetSpecies("macrocarpa")
		if err != nil {
			t.Fatalf("GetSpecies(macrocarpa) failed: %v", err)
		}
		if !sliceContains(macrocarpa.Hybrids, "× bebbiana") {
			t.Errorf("macrocarpa.Hybrids = %v, want to contain '× bebbiana'", macrocarpa.Hybrids)
		}
	})

	// Change parent2 from macrocarpa to rubra
	t.Run("Update_HybridParent", func(t *testing.T) {
		parent1 := "alba"
		parent2 := "rubra"
		_, err := c.UpdateSpecies("× bebbiana", &client.SpeciesRequest{
			ScientificName: "× bebbiana",
			IsHybrid:       true,
			Parent1:        &parent1,
			Parent2:        &parent2,
		})
		if err != nil {
			t.Fatalf("UpdateSpecies(hybrid) failed: %v", err)
		}
	})

	// Verify macrocarpa no longer has the hybrid
	t.Run("Verify_OldParentRemoved", func(t *testing.T) {
		macrocarpa, err := c.GetSpecies("macrocarpa")
		if err != nil {
			t.Fatalf("GetSpecies(macrocarpa) failed: %v", err)
		}
		if sliceContains(macrocarpa.Hybrids, "× bebbiana") {
			t.Errorf("macrocarpa.Hybrids = %v, want NOT to contain '× bebbiana'", macrocarpa.Hybrids)
		}
	})

	// Verify rubra now has the hybrid
	t.Run("Verify_NewParentAdded", func(t *testing.T) {
		rubra, err := c.GetSpecies("rubra")
		if err != nil {
			t.Fatalf("GetSpecies(rubra) failed: %v", err)
		}
		if !sliceContains(rubra.Hybrids, "× bebbiana") {
			t.Errorf("rubra.Hybrids = %v, want to contain '× bebbiana'", rubra.Hybrids)
		}
	})

	// Verify alba still has the hybrid (unchanged)
	t.Run("Verify_UnchangedParent", func(t *testing.T) {
		alba, err := c.GetSpecies("alba")
		if err != nil {
			t.Fatalf("GetSpecies(alba) failed: %v", err)
		}
		if !sliceContains(alba.Hybrids, "× bebbiana") {
			t.Errorf("alba.Hybrids = %v, want to contain '× bebbiana'", alba.Hybrids)
		}
	})
}

// TestRemoteAPI_MockServer verifies the client correctly communicates with a remote API.
func TestRemoteAPI_MockServer(t *testing.T) {
	// Create a mock server that simulates the remote API
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify auth header
		auth := r.Header.Get("Authorization")
		if auth != "Bearer test-api-key" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}

		switch {
		case r.URL.Path == "/api/v1/species" && r.Method == http.MethodGet:
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(client.SpeciesListResponse{
				Data: []*client.OakEntry{
					{ScientificName: "alba", IsHybrid: false},
				},
				Pagination: client.Pagination{Total: 1, Limit: 50, Offset: 0},
			})
		case r.URL.Path == "/api/v1/species/alba" && r.Method == http.MethodGet:
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(client.OakEntry{
				ScientificName: "alba",
				IsHybrid:       false,
			})
		case r.URL.Path == "/api/v1/health" && r.Method == http.MethodGet:
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(client.HealthResponse{
				Status: "ok",
				Version: client.VersionInfo{
					API:       "1.0.0",
					MinClient: "1.0.0",
				},
			})
		default:
			w.WriteHeader(http.StatusNotFound)
		}
	}))
	defer server.Close()

	// Create client pointing at mock server
	profile := &config.ResolvedProfile{
		Name:   "test-remote",
		URL:    server.URL,
		Key:    "test-api-key",
		Source: config.SourceConfig,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	t.Run("Remote_ListSpecies", func(t *testing.T) {
		resp, err := c.ListSpecies(nil)
		if err != nil {
			t.Fatalf("ListSpecies failed: %v", err)
		}
		if len(resp.Data) != 1 {
			t.Errorf("got %d species, want 1", len(resp.Data))
		}
	})

	t.Run("Remote_GetSpecies", func(t *testing.T) {
		species, err := c.GetSpecies("alba")
		if err != nil {
			t.Fatalf("GetSpecies failed: %v", err)
		}
		if species.ScientificName != "alba" {
			t.Errorf("ScientificName = %q, want %q", species.ScientificName, "alba")
		}
	})
}

// TestRemoteAPI_AuthFailure verifies proper handling of authentication failures.
func TestRemoteAPI_AuthFailure(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]string{
			"code":    "unauthorized",
			"message": "invalid API key",
		})
	}))
	defer server.Close()

	profile := &config.ResolvedProfile{
		Name:   "test-remote",
		URL:    server.URL,
		Key:    "wrong-key",
		Source: config.SourceConfig,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	_, err = c.ListSpecies(nil)
	if err == nil {
		t.Fatal("expected auth error")
	}
	if !client.IsAuthError(err) {
		t.Errorf("expected auth error, got %v", err)
	}
}

// TestModeSwitch verifies that profile resolution correctly handles local vs remote modes.
func TestModeSwitch_ProfileResolution(t *testing.T) {
	t.Run("LocalSource", func(t *testing.T) {
		profile := &config.ResolvedProfile{
			Source: config.SourceLocal,
		}
		if !profile.IsLocal() {
			t.Error("expected IsLocal() = true for SourceLocal")
		}
	})

	t.Run("EmbeddedSource", func(t *testing.T) {
		profile := &config.ResolvedProfile{
			Name:   "embedded",
			URL:    "http://127.0.0.1:12345",
			Key:    "test-key",
			Source: config.SourceEmbedded,
		}
		// Embedded profiles are NOT local (they have a URL)
		if profile.IsLocal() {
			t.Error("expected IsLocal() = false for SourceEmbedded with URL")
		}
	})

	t.Run("ConfigSource", func(t *testing.T) {
		profile := &config.ResolvedProfile{
			Name:   "prod",
			URL:    "https://api.example.com",
			Key:    "prod-key",
			Source: config.SourceConfig,
		}
		if profile.IsLocal() {
			t.Error("expected IsLocal() = false for SourceConfig")
		}
	})

	t.Run("ClientRejectsLocalProfile", func(t *testing.T) {
		profile := &config.ResolvedProfile{
			Source: config.SourceLocal,
		}
		_, err := client.New(profile)
		if err == nil {
			t.Error("expected error when creating client with local profile")
		}
	})
}

// TestEmbeddedAPI_Export verifies the export endpoint works through embedded API.
func TestEmbeddedAPI_Export(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	// Create some test data
	_, _ = c.CreateSpecies(&client.SpeciesRequest{
		ScientificName: "alba",
		IsHybrid:       false,
	})

	_, _ = c.CreateSource(&client.SourceRequest{
		SourceType: "Website",
		Name:       "Test Source",
	})

	t.Run("Export", func(t *testing.T) {
		exportData, err := c.Export()
		if err != nil {
			t.Fatalf("Export failed: %v", err)
		}

		// Verify export contains our test data
		if exportData == nil {
			t.Fatal("expected non-nil export")
		}

		// Parse the export to verify structure
		var export struct {
			Species []struct {
				Name string `json:"name"`
			} `json:"species"`
		}
		if err := json.Unmarshal(exportData, &export); err != nil {
			t.Fatalf("failed to unmarshal export: %v", err)
		}

		// The export should have at least the species we created
		if len(export.Species) == 0 {
			t.Error("expected at least one species in export")
		}
	})
}

// TestConfigLoad verifies config loading from files and environment.
func TestConfigLoad(t *testing.T) {
	t.Run("LoadFromNonexistentPath", func(t *testing.T) {
		cfg, err := config.Load("/nonexistent/path/config.yaml")
		if err != nil {
			t.Fatalf("Load failed: %v", err)
		}
		// Should return empty config, not error
		if cfg == nil {
			t.Error("expected non-nil config")
		}
	})

	t.Run("LoadFromTempFile", func(t *testing.T) {
		tmpDir := t.TempDir()
		configPath := filepath.Join(tmpDir, "config.yaml")

		configContent := `profiles:
  test:
    url: https://test.example.com
    key: test-key
`
		if err := os.WriteFile(configPath, []byte(configContent), 0600); err != nil {
			t.Fatalf("failed to write test config: %v", err)
		}

		cfg, err := config.Load(configPath)
		if err != nil {
			t.Fatalf("Load failed: %v", err)
		}

		if cfg.Profiles == nil {
			t.Fatal("expected non-nil Profiles")
		}

		profile, exists := cfg.Profiles["test"]
		if !exists {
			t.Fatal("expected 'test' profile to exist")
		}
		if profile.URL != "https://test.example.com" {
			t.Errorf("URL = %q, want %q", profile.URL, "https://test.example.com")
		}
	})
}

// TestEmbeddedAPI_SpeciesSources verifies species source operations.
func TestEmbeddedAPI_SpeciesSources(t *testing.T) {
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	server, err := embed.Start(embed.Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	profile := &config.ResolvedProfile{
		Name:   "embedded",
		URL:    server.URL(),
		Key:    server.APIKey(),
		Source: config.SourceEmbedded,
	}
	c, err := client.New(profile, client.WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	// Setup: create species and source
	_, _ = c.CreateSpecies(&client.SpeciesRequest{
		ScientificName: "alba",
		IsHybrid:       false,
	})

	source, _ := c.CreateSource(&client.SourceRequest{
		SourceType: "Website",
		Name:       "Test Source",
	})

	t.Run("CreateSpeciesSource", func(t *testing.T) {
		leaves := "Large lobed leaves"
		ss, err := c.CreateSpeciesSource("alba", &client.SpeciesSource{
			SourceID: source.ID,
			Leaves:   &leaves,
		})
		if err != nil {
			t.Fatalf("CreateSpeciesSource failed: %v", err)
		}
		if ss.SourceID != source.ID {
			t.Errorf("SourceID = %d, want %d", ss.SourceID, source.ID)
		}
		if ss.Leaves == nil || *ss.Leaves != leaves {
			t.Errorf("Leaves = %v, want %q", ss.Leaves, leaves)
		}
	})

	t.Run("ListSpeciesSources", func(t *testing.T) {
		sources, err := c.ListSpeciesSources("alba")
		if err != nil {
			t.Fatalf("ListSpeciesSources failed: %v", err)
		}
		if len(sources) != 1 {
			t.Errorf("got %d sources, want 1", len(sources))
		}
	})

	t.Run("GetSpeciesWithSources", func(t *testing.T) {
		entry, sources, err := c.GetSpeciesWithSources("alba")
		if err != nil {
			t.Fatalf("GetSpeciesWithSources failed: %v", err)
		}
		if entry.ScientificName != "alba" {
			t.Errorf("ScientificName = %q, want %q", entry.ScientificName, "alba")
		}
		if len(sources) != 1 {
			t.Errorf("got %d sources, want 1", len(sources))
		}
	})
}

// sliceContains checks if a string slice contains a value.
func sliceContains(slice []string, value string) bool {
	for _, s := range slice {
		if s == value {
			return true
		}
	}
	return false
}
