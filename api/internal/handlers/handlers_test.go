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

func TestSpeciesFullEndpoint(t *testing.T) {
	server, cleanup := testServer(t)
	defer cleanup()

	// Create a species
	author := "L."
	subgenus := "Quercus"
	species := models.OakEntry{
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
	parent1 := models.OakEntry{
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

	parent2 := models.OakEntry{
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
	hybrid := models.OakEntry{
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
		species := models.OakEntry{
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
	var listResp ListResponse[*models.OakEntry]
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

func TestGzipCompressionNotRequestedNotCompressed(t *testing.T) {
	server, cleanup := testServerWithMiddleware(t)
	defer cleanup()

	// Create species to have some data
	author := "L."
	for i := 0; i < 50; i++ {
		species := models.OakEntry{
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
	var listResp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &listResp); err != nil {
		t.Fatalf("failed to decode response: %v", err)
	}
}
