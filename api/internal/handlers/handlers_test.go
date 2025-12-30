package handlers

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/jeff/oaks/api/internal/db"
	"github.com/jeff/oaks/api/internal/models"
)

// testServer creates a test server with an in-memory database
func testServer(t *testing.T) (*Server, func()) {
	t.Helper()

	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create test database: %v", err)
	}

	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	version := VersionInfo{API: "1.0.0", MinClient: "1.0.0"}
	server := New(database, "test-api-key", logger, version, WithoutMiddleware())

	cleanup := func() {
		database.Close()
	}

	return server, cleanup
}

func TestHealth(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp HealthResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.Status != "ok" {
		t.Errorf("status = %s, want ok", resp.Status)
	}
	if resp.Version.API != "1.0.0" {
		t.Errorf("API version = %s, want 1.0.0", resp.Version.API)
	}
}

func TestSpeciesCRUD(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	createReq := models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
	}
	body, _ := json.Marshal(createReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// Get the species
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get status = %d, want %d", w.Code, http.StatusOK)
	}

	var entry models.OakEntry
	if err := json.NewDecoder(w.Body).Decode(&entry); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", entry.ScientificName)
	}

	// List species
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Search species
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/search?q=alb", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("search status = %d, want %d", w.Code, http.StatusOK)
	}

	// Update species
	conservation := "LC"
	updateReq := models.OakEntry{
		ScientificName:     "alba",
		Author:             &author,
		ConservationStatus: &conservation,
	}
	body, _ = json.Marshal(updateReq)

	req = httptest.NewRequest(http.MethodPut, "/api/v1/species/alba", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("update status = %d, want %d. Body: %s", w.Code, http.StatusOK, w.Body.String())
	}

	// Delete species
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/species/alba", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, want %d", w.Code, http.StatusNoContent)
	}

	// Verify deletion
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("get after delete status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestTaxaCRUD(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a taxon
	author := "Trel."
	createReq := models.Taxon{
		Name:   "Lobatae",
		Level:  models.TaxonLevelSection,
		Author: &author,
	}
	body, _ := json.Marshal(createReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/taxa", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// Get the taxon
	req = httptest.NewRequest(http.MethodGet, "/api/v1/taxa/section/Lobatae", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get status = %d, want %d", w.Code, http.StatusOK)
	}

	var taxon models.Taxon
	if err := json.NewDecoder(w.Body).Decode(&taxon); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if taxon.Name != "Lobatae" {
		t.Errorf("Name = %s, want Lobatae", taxon.Name)
	}

	// List taxa
	req = httptest.NewRequest(http.MethodGet, "/api/v1/taxa", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Delete taxon
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/taxa/section/Lobatae", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, want %d", w.Code, http.StatusNoContent)
	}
}

func TestSourcesCRUD(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a source
	desc := "A biodiversity database"
	createReq := models.Source{
		SourceType:  "website",
		Name:        "iNaturalist",
		Description: &desc,
	}
	body, _ := json.Marshal(createReq)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/sources", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	var created models.Source
	if err := json.NewDecoder(w.Body).Decode(&created); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Get the source
	req = httptest.NewRequest(http.MethodGet, "/api/v1/sources/1", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get status = %d, want %d", w.Code, http.StatusOK)
	}

	// List sources
	req = httptest.NewRequest(http.MethodGet, "/api/v1/sources", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Delete source
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/sources/1", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, want %d", w.Code, http.StatusNoContent)
	}
}

func TestSpeciesSourcesCRUD(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// First create a species and a source
	author := "L."
	species := models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
	}
	body, _ := json.Marshal(species)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create species status = %d, want %d", w.Code, http.StatusCreated)
	}

	source := models.Source{
		SourceType: "website",
		Name:       "Test Source",
	}
	body, _ = json.Marshal(source)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/sources", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create source status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Create a species-source record
	leaves := "Large lobed leaves"
	ss := models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       1,
		Leaves:         &leaves,
		LocalNames:     []string{"white oak"},
		IsPreferred:    true,
	}
	body, _ = json.Marshal(ss)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species/alba/sources", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create species-source status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// List species sources
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba/sources", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Get specific species source
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba/sources/1", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get status = %d, want %d", w.Code, http.StatusOK)
	}

	// Delete species source
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/species/alba/sources/1", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete status = %d, want %d", w.Code, http.StatusNoContent)
	}
}

func TestExport(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create some test data
	author := "L."
	species := models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
	}
	body, _ := json.Marshal(species)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create species status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Export
	req = httptest.NewRequest(http.MethodGet, "/api/v1/export", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("export status = %d, want %d", w.Code, http.StatusOK)
	}

	// Verify export contains species
	body = w.Body.Bytes()
	if !bytes.Contains(body, []byte("alba")) {
		t.Error("export missing 'alba'")
	}
}

func TestAuthRequired(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Try to create without auth
	author := "L."
	species := models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
	}
	body, _ := json.Marshal(species)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	// No X-API-Key header
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("create without auth status = %d, want %d", w.Code, http.StatusUnauthorized)
	}

	// Try with wrong key
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer wrong-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("create with wrong key status = %d, want %d", w.Code, http.StatusUnauthorized)
	}
}

func TestConflictError(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	species := models.OakEntry{
		ScientificName: "alba",
		Author:         &author,
	}
	body, _ := json.Marshal(species)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("first create status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Try to create again - should get conflict
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("duplicate create status = %d, want %d", w.Code, http.StatusConflict)
	}
}
