package handlers

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
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

// testServerWithMiddleware creates a test server with middleware enabled
func testServerWithMiddleware(t *testing.T) (*Server, func()) {
	t.Helper()

	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create test database: %v", err)
	}

	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelError}))
	version := VersionInfo{API: "1.0.0", MinClient: "1.0.0"}
	// Use middleware config that disables rate limiting for tests
	config := MiddlewareConfig{
		Logger:    logger,
		RateLimit: RateLimitConfig{ReadLimit: 1000, WriteLimit: 1000, BackupLimit: 1000, Window: 1, BackupWindow: 1},
		CORS:      DefaultCORSConfig(),
		Timeout:   30,
	}
	server := New(database, "test-api-key", logger, version, WithMiddlewareConfig(config))

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
	createReq := models.Species{
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

	var entry models.Species
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
	updateReq := models.Species{
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
	species := models.Species{
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
	species := models.Species{
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
	species := models.Species{
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
	species := models.Species{
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

func TestSpeciesFullEndpoint(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	subgenus := "Quercus"
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		Subgenus:       &subgenus,
		IsHybrid:       false,
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

	// Create a source
	sourceURL := "https://example.com"
	source := models.Source{
		SourceType: "website",
		Name:       "Test Source",
		URL:        &sourceURL,
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

	// Get full species
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba/full", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get full species status = %d, want %d. Body: %s", w.Code, http.StatusOK, w.Body.String())
	}

	var full models.SpeciesWithSources
	if err := json.NewDecoder(w.Body).Decode(&full); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if full.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", full.ScientificName)
	}
	if len(full.Sources) != 1 {
		t.Fatalf("Sources length = %d, want 1", len(full.Sources))
	}
	if full.Sources[0].SourceName != "Test Source" {
		t.Errorf("SourceName = %s, want Test Source", full.Sources[0].SourceName)
	}
	if full.Sources[0].SourceURL == nil || *full.Sources[0].SourceURL != "https://example.com" {
		t.Errorf("SourceURL = %v, want https://example.com", full.Sources[0].SourceURL)
	}
	if full.Sources[0].Leaves == nil || *full.Sources[0].Leaves != "Large lobed leaves" {
		t.Errorf("Leaves = %v, want Large lobed leaves", full.Sources[0].Leaves)
	}
}

func TestSpeciesFullEndpointNotFound(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/species/nonexistent/full", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("get nonexistent full species status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestDeleteCascadeProtection(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create two parent species
	author := "L."
	parent1 := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
	}
	body, _ := json.Marshal(parent1)

	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create parent1 status = %d, want %d", w.Code, http.StatusCreated)
	}

	parent2 := models.Species{
		ScientificName: "macrocarpa",
		Author:         &author,
		IsHybrid:       false,
	}
	body, _ = json.Marshal(parent2)

	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create parent2 status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Create a hybrid that references both parents
	p1 := "alba"
	p2 := "macrocarpa"
	hybrid := models.Species{
		ScientificName: "× bebbiana",
		IsHybrid:       true,
		Parent1:        &p1,
		Parent2:        &p2,
	}
	body, _ = json.Marshal(hybrid)

	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("create hybrid status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// Try to delete parent1 - should fail with 409 Conflict
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/species/alba", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Fatalf("delete blocked parent status = %d, want %d. Body: %s", w.Code, http.StatusConflict, w.Body.String())
	}

	// Verify the error message contains blocking hybrids
	var errResp ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&errResp); err != nil {
		t.Fatalf("failed to decode error response: %v", err)
	}

	if errResp.Error.Code != ErrCodeConflict {
		t.Errorf("error code = %s, want %s", errResp.Error.Code, ErrCodeConflict)
	}

	// Check that details contains blocking hybrids
	details, ok := errResp.Error.Details.(map[string]interface{})
	if !ok {
		t.Fatalf("error details is not a map: %T", errResp.Error.Details)
	}
	hybrids, ok := details["blocking_hybrids"].([]interface{})
	if !ok {
		t.Fatalf("blocking_hybrids is not an array: %T", details["blocking_hybrids"])
	}
	if len(hybrids) != 1 {
		t.Errorf("blocking_hybrids length = %d, want 1", len(hybrids))
	}
	if hybrids[0] != "× bebbiana" {
		t.Errorf("blocking_hybrids[0] = %s, want × bebbiana", hybrids[0])
	}

	// Delete the hybrid first
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/species/%C3%97%20bebbiana", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete hybrid status = %d, want %d. Body: %s", w.Code, http.StatusNoContent, w.Body.String())
	}

	// Now deleting parent1 should succeed
	req = httptest.NewRequest(http.MethodDelete, "/api/v1/species/alba", nil)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Fatalf("delete parent after hybrid removed status = %d, want %d", w.Code, http.StatusNoContent)
	}
}

func TestGzipCompression(t *testing.T) {
	server, cleanup := testServerWithMiddleware(t)
	defer cleanup()

	// Create multiple species to generate a large response
	author := "L."
	for i := 0; i < 50; i++ {
		species := models.Species{
			ScientificName: "species" + strings.Repeat("x", 20) + string(rune('A'+i%26)) + string(rune('a'+i/26)),
			Author:         &author,
			IsHybrid:       false,
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
	}

	// Request with Accept-Encoding: gzip
	req := httptest.NewRequest(http.MethodGet, "/api/v1/species", nil)
	req.Header.Set("Accept-Encoding", "gzip")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Check that response is compressed
	if w.Header().Get("Content-Encoding") != "gzip" {
		t.Error("response should be gzip compressed for large responses")
	}

	// Verify we can decompress and read the content
	reader, err := gzip.NewReader(w.Body)
	if err != nil {
		t.Fatalf("failed to create gzip reader: %v", err)
	}
	defer reader.Close()

	body, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("failed to read gzip body: %v", err)
	}

	// Verify it's valid JSON with species data
	var listResp ListResponse[*models.Species]
	if err := json.Unmarshal(body, &listResp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if len(listResp.Data) != 50 {
		t.Errorf("expected 50 species, got %d", len(listResp.Data))
	}
}

func TestGzipCompressionSmallResponseNotCompressed(t *testing.T) {
	server, cleanup := testServerWithMiddleware(t)
	defer cleanup()

	// Health endpoint returns small response - should not be compressed
	req := httptest.NewRequest(http.MethodGet, "/api/v1/health", nil)
	req.Header.Set("Accept-Encoding", "gzip")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("health status = %d, want %d", w.Code, http.StatusOK)
	}

	// Small responses should NOT be compressed
	if w.Header().Get("Content-Encoding") == "gzip" {
		t.Error("small responses should not be gzip compressed")
	}
}

func TestGetSpeciesByID(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	createReq := models.Species{
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

	// Get the species by ID
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/id/1", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get by ID status = %d, want %d. Body: %s", w.Code, http.StatusOK, w.Body.String())
	}

	var entry models.Species
	if err := json.NewDecoder(w.Body).Decode(&entry); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", entry.ScientificName)
	}
	if entry.ID != 1 {
		t.Errorf("ID = %d, want 1", entry.ID)
	}
}

func TestGetSpeciesByIDNotFound(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/species/id/999", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("get nonexistent by ID status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestGetSpeciesByIDInvalidID(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/species/id/abc", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("get with invalid ID status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestGetTaxonByID(t *testing.T) {
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

	// Get the taxon by ID
	req = httptest.NewRequest(http.MethodGet, "/api/v1/taxa/id/1", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get by ID status = %d, want %d. Body: %s", w.Code, http.StatusOK, w.Body.String())
	}

	var taxon TaxonResponse
	if err := json.NewDecoder(w.Body).Decode(&taxon); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
	if taxon.Name != "Lobatae" {
		t.Errorf("Name = %s, want Lobatae", taxon.Name)
	}
	if taxon.Level != models.TaxonLevelSection {
		t.Errorf("Level = %s, want section", taxon.Level)
	}
}

func TestGetTaxonByIDNotFound(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/taxa/id/999", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("get nonexistent by ID status = %d, want %d", w.Code, http.StatusNotFound)
	}
}

func TestGetTaxonByIDInvalidID(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	req := httptest.NewRequest(http.MethodGet, "/api/v1/taxa/id/abc", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("get with invalid ID status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestGzipCompressionNotRequestedNotCompressed(t *testing.T) {
	server, cleanup := testServerWithMiddleware(t)
	defer cleanup()

	// Create species to have some data
	author := "L."
	for i := 0; i < 50; i++ {
		species := models.Species{
			ScientificName: "species" + strings.Repeat("y", 20) + string(rune('A'+i%26)) + string(rune('a'+i/26)),
			Author:         &author,
			IsHybrid:       false,
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
	}

	// Request WITHOUT Accept-Encoding: gzip
	req := httptest.NewRequest(http.MethodGet, "/api/v1/species", nil)
	// No Accept-Encoding header
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("list status = %d, want %d", w.Code, http.StatusOK)
	}

	// Response should NOT be compressed
	if w.Header().Get("Content-Encoding") == "gzip" {
		t.Error("response should not be compressed when client doesn't accept gzip")
	}

	// Verify it's valid JSON (not gzipped)
	var listResp ListResponse[*models.Species]
	if err := json.Unmarshal(w.Body.Bytes(), &listResp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
}

func TestSpeciesReferencesEndpoint(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create parent species
	author := "L."
	parent := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
	}
	body, _ := json.Marshal(parent)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create parent status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Create another parent
	parent2 := models.Species{
		ScientificName: "macrocarpa",
		Author:         &author,
		IsHybrid:       false,
	}
	body, _ = json.Marshal(parent2)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create parent2 status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Create a hybrid that references alba as parent1
	p1 := "alba"
	p2 := "macrocarpa"
	hybrid := models.Species{
		ScientificName: "× bebbiana",
		IsHybrid:       true,
		Parent1:        &p1,
		Parent2:        &p2,
	}
	body, _ = json.Marshal(hybrid)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create hybrid status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// Create a species that lists alba in closely_related_to
	related := models.Species{
		ScientificName:   "stellata",
		Author:           &author,
		IsHybrid:         false,
		CloselyRelatedTo: []string{"alba"},
	}
	body, _ = json.Marshal(related)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create related status = %d, want %d. Body: %s", w.Code, http.StatusCreated, w.Body.String())
	}

	// Test: Get references to alba
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/references?name=alba", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get references status = %d, want %d. Body: %s", w.Code, http.StatusOK, w.Body.String())
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	// Check count
	count, ok := resp["count"].(float64)
	if !ok || count != 2 {
		t.Errorf("count = %v, want 2", resp["count"])
	}

	// Check data contains the expected references
	data, ok := resp["data"].([]interface{})
	if !ok {
		t.Fatalf("data is not an array: %T", resp["data"])
	}
	if len(data) != 2 {
		t.Errorf("data length = %d, want 2", len(data))
	}

	// Verify reference types
	refTypes := make(map[string]string)
	for _, item := range data {
		ref := item.(map[string]interface{})
		name := ref["scientific_name"].(string)
		refType := ref["reference_type"].(string)
		refTypes[name] = refType
	}

	if refTypes["stellata"] != "closely_related_to" {
		t.Errorf("stellata reference_type = %s, want closely_related_to", refTypes["stellata"])
	}
	if refTypes["× bebbiana"] != "parent1" {
		t.Errorf("× bebbiana reference_type = %s, want parent1", refTypes["× bebbiana"])
	}
}

func TestSpeciesReferencesNoReferences(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species with no references
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
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

	// Get references - should return empty array, not 404
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/references?name=alba", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get references status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	count, ok := resp["count"].(float64)
	if !ok || count != 0 {
		t.Errorf("count = %v, want 0", resp["count"])
	}

	data, ok := resp["data"].([]interface{})
	if !ok {
		t.Fatalf("data is not an array: %T", resp["data"])
	}
	if len(data) != 0 {
		t.Errorf("data length = %d, want 0", len(data))
	}
}

func TestSpeciesReferencesMissingName(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Request without name parameter
	req := httptest.NewRequest(http.MethodGet, "/api/v1/species/references", nil)
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("get references without name status = %d, want %d", w.Code, http.StatusBadRequest)
	}
}

func TestSpeciesReferencesHybridsField(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create alba with a hybrids list containing "bebbiana"
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Hybrids:        []string{"bebbiana", "jackiana"},
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

	// Get references to bebbiana - should find alba via hybrids field
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/references?name=bebbiana", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get references status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp map[string]interface{}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	count, ok := resp["count"].(float64)
	if !ok || count != 1 {
		t.Errorf("count = %v, want 1", resp["count"])
	}

	data, ok := resp["data"].([]interface{})
	if !ok || len(data) != 1 {
		t.Fatalf("data length = %d, want 1", len(data))
	}

	ref := data[0].(map[string]interface{})
	if ref["scientific_name"] != "alba" {
		t.Errorf("scientific_name = %s, want alba", ref["scientific_name"])
	}
	if ref["reference_type"] != "hybrids" {
		t.Errorf("reference_type = %s, want hybrids", ref["reference_type"])
	}
}

func TestGetSpeciesSynonymRedirect(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species with synonyms
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Synonyms:       []string{"alba var. repanda", "quercus repanda"},
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

	// Request a synonym - should get 404 with synonym_of
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba%20var.%20repanda", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("get synonym status = %d, want %d", w.Code, http.StatusNotFound)
	}

	var resp SynonymRedirectResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.SynonymOf != "alba" {
		t.Errorf("synonym_of = %s, want alba", resp.SynonymOf)
	}
}

func TestGetSpeciesSynonymRedirectCaseInsensitive(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species with synonyms
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Synonyms:       []string{"Quercus Repanda"},
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

	// Request with different case - should still match
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/quercus%20repanda", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("get synonym status = %d, want %d", w.Code, http.StatusNotFound)
	}

	var resp SynonymRedirectResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.SynonymOf != "alba" {
		t.Errorf("synonym_of = %s, want alba", resp.SynonymOf)
	}
}

func TestGetSpeciesAmbiguousSynonym(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create two species with the same synonym
	author := "L."
	species1 := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Synonyms:       []string{"disputed name"},
	}
	body, _ := json.Marshal(species1)
	req := httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create species1 status = %d, want %d", w.Code, http.StatusCreated)
	}

	species2 := models.Species{
		ScientificName: "robur",
		Author:         &author,
		IsHybrid:       false,
		Synonyms:       []string{"disputed name"},
	}
	body, _ = json.Marshal(species2)
	req = httptest.NewRequest(http.MethodPost, "/api/v1/species", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)
	if w.Code != http.StatusCreated {
		t.Fatalf("create species2 status = %d, want %d", w.Code, http.StatusCreated)
	}

	// Request the ambiguous synonym
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/disputed%20name", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("get ambiguous synonym status = %d, want %d", w.Code, http.StatusNotFound)
	}

	var resp AmbiguousSynonymResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if !resp.AmbiguousSynonym {
		t.Error("expected ambiguous_synonym = true")
	}

	if len(resp.Matches) != 2 {
		t.Fatalf("matches length = %d, want 2", len(resp.Matches))
	}

	// Matches should be sorted alphabetically
	if resp.Matches[0] != "alba" || resp.Matches[1] != "robur" {
		t.Errorf("matches = %v, want [alba, robur]", resp.Matches)
	}
}

func TestGetSpeciesNotFoundNoSynonym(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species (to ensure database is working)
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Synonyms:       []string{"alba var. repanda"},
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

	// Request a name that doesn't exist and isn't a synonym
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/nonexistent", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Fatalf("get nonexistent status = %d, want %d", w.Code, http.StatusNotFound)
	}

	// Should be standard error response, not synonym redirect
	var resp ErrorResponse
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.Error.Code != ErrCodeNotFound {
		t.Errorf("error code = %s, want %s", resp.Error.Code, ErrCodeNotFound)
	}
}

func TestGetSpeciesExistsNoSynonymLookup(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	species := models.Species{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
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

	// Request the species - should return normally (200)
	req = httptest.NewRequest(http.MethodGet, "/api/v1/species/alba", nil)
	w = httptest.NewRecorder()
	server.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("get species status = %d, want %d", w.Code, http.StatusOK)
	}

	var resp models.Species
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}

	if resp.ScientificName != "alba" {
		t.Errorf("scientific_name = %s, want alba", resp.ScientificName)
	}
}
