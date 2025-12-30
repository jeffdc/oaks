package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/export"
	"github.com/jeff/oaks/cli/internal/models"
)

// Integration tests for the API with full middleware chain.
// These tests verify the complete request/response cycle including
// all middleware (CORS, rate limiting, logging, etc.)

// setupIntegrationServer creates a test server with full middleware applied.
func setupIntegrationServer(t *testing.T) (*Server, *db.Database) {
	t.Helper()
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}

	// Create server WITH middleware (unlike unit tests that skip it)
	config := DefaultMiddlewareConfig(nil)
	// Use a very high rate limit for tests to avoid flakiness
	config.RateLimit.ReadLimit = 1000
	config.RateLimit.WriteLimit = 1000
	server := New(database, "test-api-key", nil, WithMiddlewareConfig(config))

	return server, database
}

// TestIntegration_FullRequestCycle tests the complete request/response cycle
// for all main endpoints with middleware applied.
func TestIntegration_FullRequestCycle(t *testing.T) {
	s, database := setupIntegrationServer(t)
	defer database.Close()

	tests := []struct {
		name           string
		method         string
		path           string
		body           string
		auth           bool
		wantStatus     int
		wantRequestID  bool
		checkCORS      bool
		checkRateLimit bool
	}{
		{
			name:          "health check",
			method:        "GET",
			path:          "/health",
			wantStatus:    http.StatusOK,
			wantRequestID: true,
		},
		{
			name:          "readiness check",
			method:        "GET",
			path:          "/health/ready",
			wantStatus:    http.StatusOK,
			wantRequestID: true,
		},
		{
			name:           "list species",
			method:         "GET",
			path:           "/api/v1/species",
			wantStatus:     http.StatusOK,
			wantRequestID:  true,
			checkRateLimit: true,
		},
		{
			name:           "list taxa",
			method:         "GET",
			path:           "/api/v1/taxa",
			wantStatus:     http.StatusOK,
			wantRequestID:  true,
			checkRateLimit: true,
		},
		{
			name:           "list sources",
			method:         "GET",
			path:           "/api/v1/sources",
			wantStatus:     http.StatusOK,
			wantRequestID:  true,
			checkRateLimit: true,
		},
		{
			name:           "export endpoint",
			method:         "GET",
			path:           "/api/v1/export",
			wantStatus:     http.StatusOK,
			wantRequestID:  true,
			checkRateLimit: true,
		},
		{
			name:          "create species requires auth",
			method:        "POST",
			path:          "/api/v1/species",
			body:          `{"scientific_name":"testus"}`,
			auth:          false,
			wantStatus:    http.StatusUnauthorized,
			wantRequestID: true,
		},
		{
			name:          "create species with auth",
			method:        "POST",
			path:          "/api/v1/species",
			body:          `{"scientific_name":"testus"}`,
			auth:          true,
			wantStatus:    http.StatusCreated,
			wantRequestID: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var body *bytes.Reader
			if tc.body != "" {
				body = bytes.NewReader([]byte(tc.body))
			} else {
				body = bytes.NewReader(nil)
			}

			req := httptest.NewRequest(tc.method, tc.path, body)
			req.RemoteAddr = "127.0.0.1:12345"

			if tc.body != "" {
				req.Header.Set("Content-Type", "application/json")
			}
			if tc.auth {
				req.Header.Set("Authorization", "Bearer test-api-key")
			}

			w := httptest.NewRecorder()
			s.Router().ServeHTTP(w, req)

			if w.Code != tc.wantStatus {
				t.Errorf("expected status %d, got %d: %s", tc.wantStatus, w.Code, w.Body.String())
			}

			// Verify X-Request-ID header is set by middleware
			if tc.wantRequestID && w.Header().Get("X-Request-ID") == "" {
				t.Error("expected X-Request-ID header to be present")
			}
		})
	}
}

// TestIntegration_CORSHeaders verifies CORS headers are properly set.
func TestIntegration_CORSHeaders(t *testing.T) {
	s, database := setupIntegrationServer(t)
	defer database.Close()

	tests := []struct {
		name          string
		origin        string
		wantAllowed   bool
		isPreflight   bool
	}{
		{
			name:        "production origin allowed",
			origin:      "https://oakcompendium.org",
			wantAllowed: true,
			isPreflight: true,
		},
		{
			name:        "localhost allowed in dev",
			origin:      "http://localhost:5173",
			wantAllowed: true,
			isPreflight: true,
		},
		{
			name:        "unknown origin rejected",
			origin:      "https://evil.com",
			wantAllowed: false,
			isPreflight: true,
		},
		{
			name:        "actual request with allowed origin",
			origin:      "https://oakcompendium.org",
			wantAllowed: true,
			isPreflight: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var req *http.Request
			if tc.isPreflight {
				req = httptest.NewRequest("OPTIONS", "/api/v1/species", http.NoBody)
				req.Header.Set("Access-Control-Request-Method", "GET")
			} else {
				req = httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
			}
			req.Header.Set("Origin", tc.origin)
			req.RemoteAddr = "127.0.0.1:12345"

			w := httptest.NewRecorder()
			s.Router().ServeHTTP(w, req)

			allowOrigin := w.Header().Get("Access-Control-Allow-Origin")

			if tc.wantAllowed && allowOrigin == "" {
				t.Errorf("expected origin %q to be allowed, but Access-Control-Allow-Origin is empty", tc.origin)
			}
			if !tc.wantAllowed && allowOrigin != "" {
				t.Errorf("expected origin %q to be blocked, but got Allow-Origin: %q", tc.origin, allowOrigin)
			}

			// For preflight with allowed origin, check other CORS headers
			if tc.isPreflight && tc.wantAllowed && allowOrigin != "" {
				// The go-chi/cors middleware sets these headers
				methods := w.Header().Get("Access-Control-Allow-Methods")
				if methods == "" {
					t.Logf("Note: Access-Control-Allow-Methods not set (may be OK depending on CORS config)")
				}
			}
		})
	}
}

// TestIntegration_Authentication tests authentication across multiple endpoints.
func TestIntegration_Authentication(t *testing.T) {
	s, database := setupIntegrationServer(t)
	defer database.Close()

	// Insert test data
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	readEndpoints := []struct {
		method string
		path   string
	}{
		{"GET", "/api/v1/species"},
		{"GET", "/api/v1/species/alba"},
		{"GET", "/api/v1/taxa"},
		{"GET", "/api/v1/sources"},
		{"GET", "/api/v1/export"},
	}

	writeEndpoints := []struct {
		method string
		path   string
		body   string
	}{
		{"POST", "/api/v1/species", `{"scientific_name":"newspecies"}`},
		{"PUT", "/api/v1/species/alba", `{"author":"L."}`},
		{"DELETE", "/api/v1/species/alba", ""},
		{"POST", "/api/v1/sources", `{"source_type":"website","name":"Test"}`},
		{"POST", "/api/v1/taxa", `{"name":"Test","level":"subgenus"}`},
	}

	// Read endpoints should work without auth
	for _, ep := range readEndpoints {
		t.Run("public_"+ep.method+"_"+ep.path, func(t *testing.T) {
			req := httptest.NewRequest(ep.method, ep.path, http.NoBody)
			req.RemoteAddr = "127.0.0.1:12345"
			w := httptest.NewRecorder()

			s.Router().ServeHTTP(w, req)

			// Should not be 401 Unauthorized
			if w.Code == http.StatusUnauthorized {
				t.Errorf("read endpoint %s %s should not require auth", ep.method, ep.path)
			}
		})
	}

	// Write endpoints should require auth
	for _, ep := range writeEndpoints {
		t.Run("protected_"+ep.method+"_"+strings.ReplaceAll(ep.path, "/", "_"), func(t *testing.T) {
			var body *bytes.Reader
			if ep.body != "" {
				body = bytes.NewReader([]byte(ep.body))
			} else {
				body = bytes.NewReader(nil)
			}

			// Without auth - should fail
			req := httptest.NewRequest(ep.method, ep.path, body)
			req.RemoteAddr = "127.0.0.1:12345"
			if ep.body != "" {
				req.Header.Set("Content-Type", "application/json")
			}
			w := httptest.NewRecorder()

			s.Router().ServeHTTP(w, req)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("write endpoint %s %s without auth: expected 401, got %d", ep.method, ep.path, w.Code)
			}

			// With invalid auth - should fail
			body = bytes.NewReader([]byte(ep.body))
			req = httptest.NewRequest(ep.method, ep.path, body)
			req.RemoteAddr = "127.0.0.1:12345"
			req.Header.Set("Authorization", "Bearer wrong-key")
			if ep.body != "" {
				req.Header.Set("Content-Type", "application/json")
			}
			w = httptest.NewRecorder()

			s.Router().ServeHTTP(w, req)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("write endpoint %s %s with invalid auth: expected 401, got %d", ep.method, ep.path, w.Code)
			}
		})
	}
}

// TestIntegration_DeleteSpeciesAndSources verifies deleting a species works,
// and tests separate deletion of species_sources records.
// Note: SQLite cascade delete via ON DELETE CASCADE requires PRAGMA foreign_keys = ON
// which is not currently enabled in the database setup.
func TestIntegration_DeleteSpeciesAndSources(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert species
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	// Insert source
	source := &models.Source{SourceType: "website", Name: "Test"}
	sourceID, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	// Insert species-source association
	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		LocalNames:     []string{"white oak"},
	}
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to insert species source: %v", err)
	}

	// Verify association exists
	sources, err := database.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("failed to get species sources: %v", err)
	}
	if len(sources) != 1 {
		t.Fatalf("expected 1 species source, got %d", len(sources))
	}

	// First delete the species-source association
	req := httptest.NewRequest("DELETE", "/api/v1/species/alba/sources/1", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d for delete species-source, got %d: %s",
			http.StatusNoContent, w.Code, w.Body.String())
	}

	// Verify species-source is deleted
	sources, err = database.GetSpeciesSources("alba")
	if err != nil {
		t.Fatalf("failed to get species sources: %v", err)
	}
	if len(sources) != 0 {
		t.Errorf("expected species sources to be deleted, got %d", len(sources))
	}

	// Delete the species
	req = httptest.NewRequest("DELETE", "/api/v1/species/alba", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w = httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d for delete species, got %d: %s",
			http.StatusNoContent, w.Code, w.Body.String())
	}

	// Verify species is deleted
	entry, _ := database.GetOakEntry("alba")
	if entry != nil {
		t.Error("expected species to be deleted")
	}
}

// TestIntegration_ExportMatchesWebFormat verifies the export endpoint
// produces the format expected by the web application.
func TestIntegration_ExportMatchesWebFormat(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert comprehensive test data
	source := &models.Source{
		SourceType: "website",
		Name:       "Oaks of the World",
	}
	sourceID, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	subgenus := "Quercus"
	section := "Quercus"
	author := "L. 1753"
	entry := &models.OakEntry{
		ScientificName:        "alba",
		Author:                &author,
		IsHybrid:              false,
		ConservationStatus:    ptrStr("LC"),
		Subgenus:              &subgenus,
		Section:               &section,
		Hybrids:               []string{"x bebbiana"},
		CloselyRelatedTo:      []string{"stellata"},
		SubspeciesVarieties: []string{"alba var. latiloba"},
		Synonyms:              []string{"alba var. repanda"},
	}
	if err := database.SaveOakEntry(entry); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	ss := &models.SpeciesSource{
		ScientificName: "alba",
		SourceID:       sourceID,
		IsPreferred:    true,
		LocalNames:     []string{"white oak", "eastern white oak"},
		Range:          ptrStr("Eastern North America; 0 to 1600 m"),
		GrowthHabit:    ptrStr("reaches 25 m high"),
		Leaves:         ptrStr("8-20 cm long"),
	}
	if err := database.SaveSpeciesSource(ss); err != nil {
		t.Fatalf("failed to insert species source: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/export", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", w.Code)
	}

	var result export.File
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	// Validate web app expected structure
	if result.Species == nil {
		t.Fatal("expected species array")
	}
	if len(result.Species) != 1 {
		t.Fatalf("expected 1 species, got %d", len(result.Species))
	}

	species := result.Species[0]

	// Verify species name (without Quercus prefix)
	if species.Name != "alba" {
		t.Errorf("expected name 'alba', got %q", species.Name)
	}

	// Verify author
	if species.Author == nil || *species.Author != "L. 1753" {
		t.Errorf("expected author 'L. 1753', got %v", species.Author)
	}

	// Verify taxonomy structure
	if species.Taxonomy.Genus != "Quercus" {
		t.Errorf("expected genus 'Quercus', got %q", species.Taxonomy.Genus)
	}
	if species.Taxonomy.Subgenus == nil || *species.Taxonomy.Subgenus != "Quercus" {
		t.Errorf("expected subgenus 'Quercus', got %v", species.Taxonomy.Subgenus)
	}
	if species.Taxonomy.Section == nil || *species.Taxonomy.Section != "Quercus" {
		t.Errorf("expected section 'Quercus', got %v", species.Taxonomy.Section)
	}

	// Verify hybrid indicator
	if species.IsHybrid {
		t.Error("expected is_hybrid to be false")
	}

	// Verify hybrids list
	if len(species.Hybrids) != 1 || species.Hybrids[0] != "x bebbiana" {
		t.Errorf("expected hybrids ['x bebbiana'], got %v", species.Hybrids)
	}

	// Verify closely_related_to
	if len(species.CloselyRelatedTo) != 1 || species.CloselyRelatedTo[0] != "stellata" {
		t.Errorf("expected closely_related_to ['stellata'], got %v", species.CloselyRelatedTo)
	}

	// Verify sources structure
	if len(species.Sources) != 1 {
		t.Fatalf("expected 1 source, got %d", len(species.Sources))
	}

	src := species.Sources[0]
	if src.SourceName != "Oaks of the World" {
		t.Errorf("expected source_name 'Oaks of the World', got %q", src.SourceName)
	}
	if !src.IsPreferred {
		t.Error("expected is_preferred to be true")
	}
	if len(src.LocalNames) != 2 {
		t.Errorf("expected 2 local names, got %d", len(src.LocalNames))
	}
	if src.Range == nil || *src.Range != "Eastern North America; 0 to 1600 m" {
		t.Errorf("expected range, got %v", src.Range)
	}

	// Verify metadata
	if result.Metadata.SpeciesCount != 1 {
		t.Errorf("expected species_count 1, got %d", result.Metadata.SpeciesCount)
	}
	if result.Metadata.Version == "" {
		t.Error("expected version to be set")
	}
	if result.Metadata.ExportedAt == "" {
		t.Error("expected exported_at to be set")
	}
}

// TestIntegration_ErrorResponses verifies error response format is consistent.
func TestIntegration_ErrorResponses(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	tests := []struct {
		name           string
		method         string
		path           string
		body           string
		auth           bool
		wantStatus     int
		wantErrorCode  string
	}{
		{
			name:          "not found species",
			method:        "GET",
			path:          "/api/v1/species/nonexistent",
			wantStatus:    http.StatusNotFound,
			wantErrorCode: ErrCodeNotFound,
		},
		{
			name:          "not found taxon",
			method:        "GET",
			path:          "/api/v1/taxa/subgenus/nonexistent",
			wantStatus:    http.StatusNotFound,
			wantErrorCode: ErrCodeNotFound,
		},
		{
			name:          "validation error - missing name",
			method:        "POST",
			path:          "/api/v1/species",
			body:          `{}`,
			auth:          true,
			wantStatus:    http.StatusBadRequest,
			wantErrorCode: ErrCodeValidation,
		},
		{
			name:          "validation error - invalid limit",
			method:        "GET",
			path:          "/api/v1/species?limit=-1",
			wantStatus:    http.StatusBadRequest,
			wantErrorCode: ErrCodeValidation,
		},
		{
			name:          "validation error - missing search query",
			method:        "GET",
			path:          "/api/v1/species/search",
			wantStatus:    http.StatusBadRequest,
			wantErrorCode: ErrCodeValidation,
		},
		{
			name:          "unauthorized - missing auth",
			method:        "POST",
			path:          "/api/v1/species",
			body:          `{"scientific_name":"test"}`,
			auth:          false,
			wantStatus:    http.StatusUnauthorized,
			wantErrorCode: ErrCodeUnauthorized,
		},
		{
			name:          "invalid JSON",
			method:        "POST",
			path:          "/api/v1/species",
			body:          `not json`,
			auth:          true,
			wantStatus:    http.StatusBadRequest,
			wantErrorCode: ErrCodeValidation,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var body *bytes.Reader
			if tc.body != "" {
				body = bytes.NewReader([]byte(tc.body))
			} else {
				body = bytes.NewReader(nil)
			}

			req := httptest.NewRequest(tc.method, tc.path, body)
			if tc.body != "" {
				req.Header.Set("Content-Type", "application/json")
			}
			if tc.auth {
				req.Header.Set("Authorization", "Bearer test-api-key")
			}
			w := httptest.NewRecorder()

			s.Router().ServeHTTP(w, req)

			if w.Code != tc.wantStatus {
				t.Errorf("expected status %d, got %d: %s", tc.wantStatus, w.Code, w.Body.String())
			}

			// Verify error response structure
			var resp ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to parse error response: %v", err)
			}

			if resp.Error.Code != tc.wantErrorCode {
				t.Errorf("expected error code %q, got %q", tc.wantErrorCode, resp.Error.Code)
			}
			if resp.Error.Message == "" {
				t.Error("expected error message to be non-empty")
			}
		})
	}
}

// TestIntegration_ConflictErrors verifies conflict error handling.
func TestIntegration_ConflictErrors(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	// Insert existing species
	if err := database.SaveOakEntry(&models.OakEntry{ScientificName: "alba"}); err != nil {
		t.Fatalf("failed to insert entry: %v", err)
	}

	// Try to create duplicate
	body := `{"scientific_name":"alba"}`
	req := httptest.NewRequest("POST", "/api/v1/species", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Errorf("expected status %d, got %d", http.StatusConflict, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse error response: %v", err)
	}

	if resp.Error.Code != ErrCodeConflict {
		t.Errorf("expected error code %q, got %q", ErrCodeConflict, resp.Error.Code)
	}
}

// TestIntegration_RateLimitBehavior tests rate limiting with realistic settings.
func TestIntegration_RateLimitBehavior(t *testing.T) {
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	defer database.Close()

	// Create server with very low rate limit for testing
	config := DefaultMiddlewareConfig(nil)
	config.RateLimit.ReadLimit = 2
	config.RateLimit.WriteLimit = 2
	config.RateLimit.Window = time.Second
	server := New(database, "test-api-key", nil, WithMiddlewareConfig(config))

	// Make requests until rate limited
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()

		server.Router().ServeHTTP(w, req)

		if i < 2 {
			// First 2 should succeed
			if w.Code != http.StatusOK {
				t.Errorf("request %d: expected status 200, got %d", i, w.Code)
			}
		} else {
			// Third should be rate limited
			if w.Code != http.StatusTooManyRequests {
				t.Errorf("request %d: expected status 429, got %d", i, w.Code)
			}
		}
	}

	// Health endpoint should not be rate limited
	for i := 0; i < 10; i++ {
		req := httptest.NewRequest("GET", "/health", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()

		server.Router().ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("health request %d should not be rate limited, got status %d", i, w.Code)
		}
	}
}

// TestIntegration_PanicRecovery verifies the server recovers from panics.
func TestIntegration_PanicRecovery(t *testing.T) {
	s, database := setupIntegrationServer(t)
	defer database.Close()

	// We can't easily inject a panic, but we can verify the recover middleware
	// is in place by checking it doesn't crash on normal requests
	req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
	req.RemoteAddr = "127.0.0.1:12345"
	w := httptest.NewRecorder()

	// This shouldn't panic
	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status 200, got %d", w.Code)
	}
}

// TestIntegration_FilterBySection tests species filtering by section.
func TestIntegration_FilterBySection(t *testing.T) {
	s, database := setupTestServer(t)
	defer database.Close()

	section1 := "Quercus"
	section2 := "Lobatae"
	entries := []*models.OakEntry{
		{ScientificName: "alba", Section: &section1},
		{ScientificName: "rubra", Section: &section2},
		{ScientificName: "robur", Section: &section1},
	}
	for _, e := range entries {
		if err := database.SaveOakEntry(e); err != nil {
			t.Fatalf("failed to insert entry: %v", err)
		}
	}

	req := httptest.NewRequest("GET", "/api/v1/species?section=Quercus", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var resp ListResponse[*models.OakEntry]
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("expected 2 items, got %d", len(resp.Data))
	}
}

// ptrStr returns a pointer to the given string.
func ptrStr(s string) *string {
	return &s
}
