package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/db"
	"github.com/jeff/oaks/cli/internal/models"
)

func setupSourcesTestServer(t *testing.T) (*Server, *db.Database) {
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	server := New(database, "test-api-key", nil, WithoutMiddleware())
	return server, database
}

func TestListSources_Empty(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/sources", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var sources []*models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &sources); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(sources) != 0 {
		t.Errorf("expected 0 sources, got %d", len(sources))
	}
}

func TestListSources_WithData(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	// Insert test source
	source := &models.Source{
		SourceType: "website",
		Name:       "iNaturalist",
	}
	if _, err := database.InsertSource(source); err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	req := httptest.NewRequest("GET", "/api/v1/sources", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var sources []*models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &sources); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(sources) != 1 {
		t.Errorf("expected 1 source, got %d", len(sources))
	}

	if sources[0].Name != "iNaturalist" {
		t.Errorf("expected name 'iNaturalist', got %q", sources[0].Name)
	}
}

func TestGetSource_Success(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	source := &models.Source{
		SourceType: "website",
		Name:       "Oaks of the World",
	}
	id, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	req := httptest.NewRequest("GET", fmt.Sprintf("/api/v1/sources/%d", id), http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	var got models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if got.Name != "Oaks of the World" {
		t.Errorf("expected name 'Oaks of the World', got %q", got.Name)
	}
}

func TestGetSource_NotFound(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/sources/999", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestGetSource_InvalidID(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("GET", "/api/v1/sources/invalid", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}

func TestCreateSource_Success(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	body := `{"source_type":"website","name":"Test Source","description":"A test source"}`
	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var created models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if created.ID == 0 {
		t.Error("expected non-zero ID")
	}
	if created.Name != "Test Source" {
		t.Errorf("expected name 'Test Source', got %q", created.Name)
	}
	if created.SourceType != "website" {
		t.Errorf("expected source_type 'website', got %q", created.SourceType)
	}
}

func TestCreateSource_ValidationError(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	// Missing required fields
	body := `{"name":"Test Source"}`
	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Error.Code != ErrCodeValidation {
		t.Errorf("expected error code %q, got %q", ErrCodeValidation, resp.Error.Code)
	}
}

func TestCreateSource_Unauthorized(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	body := `{"source_type":"website","name":"Test Source"}`
	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestCreateSource_InvalidAPIKey(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	body := `{"source_type":"website","name":"Test Source"}`
	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer wrong-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestUpdateSource_Success(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	source := &models.Source{
		SourceType: "website",
		Name:       "Original Name",
	}
	id, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	body := `{"source_type":"book","name":"Updated Name"}`
	req := httptest.NewRequest("PUT", fmt.Sprintf("/api/v1/sources/%d", id), bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d: %s", http.StatusOK, w.Code, w.Body.String())
	}

	var updated models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &updated); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if updated.Name != "Updated Name" {
		t.Errorf("expected name 'Updated Name', got %q", updated.Name)
	}
	if updated.SourceType != "book" {
		t.Errorf("expected source_type 'book', got %q", updated.SourceType)
	}
}

func TestUpdateSource_NotFound(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	body := `{"source_type":"website","name":"Test"}`
	req := httptest.NewRequest("PUT", "/api/v1/sources/999", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestUpdateSource_Unauthorized(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	source := &models.Source{
		SourceType: "website",
		Name:       "Test",
	}
	id, _ := database.InsertSource(source)

	body := `{"source_type":"website","name":"Updated"}`
	req := httptest.NewRequest("PUT", fmt.Sprintf("/api/v1/sources/%d", id), bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestDeleteSource_Success(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	source := &models.Source{
		SourceType: "website",
		Name:       "To Delete",
	}
	id, err := database.InsertSource(source)
	if err != nil {
		t.Fatalf("failed to insert source: %v", err)
	}

	req := httptest.NewRequest("DELETE", fmt.Sprintf("/api/v1/sources/%d", id), http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNoContent {
		t.Errorf("expected status %d, got %d: %s", http.StatusNoContent, w.Code, w.Body.String())
	}

	// Verify source is deleted
	got, err := database.GetSource(id)
	if err != nil {
		t.Fatalf("failed to get source: %v", err)
	}
	if got != nil {
		t.Error("expected source to be deleted")
	}
}

func TestDeleteSource_NotFound(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("DELETE", "/api/v1/sources/999", http.NoBody)
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("expected status %d, got %d", http.StatusNotFound, w.Code)
	}
}

func TestDeleteSource_Unauthorized(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	source := &models.Source{
		SourceType: "website",
		Name:       "Test",
	}
	id, _ := database.InsertSource(source)

	req := httptest.NewRequest("DELETE", fmt.Sprintf("/api/v1/sources/%d", id), http.NoBody)
	// No Authorization header
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected status %d, got %d", http.StatusUnauthorized, w.Code)
	}
}

func TestCreateSource_WithAllFields(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	body := `{
		"source_type": "website",
		"name": "Full Source",
		"description": "A comprehensive source",
		"author": "John Doe",
		"year": 2024,
		"url": "https://example.com",
		"license": "CC BY-NC",
		"license_url": "https://creativecommons.org/licenses/by-nc/4.0/"
	}`
	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusCreated {
		t.Errorf("expected status %d, got %d: %s", http.StatusCreated, w.Code, w.Body.String())
	}

	var created models.Source
	if err := json.Unmarshal(w.Body.Bytes(), &created); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if created.Name != "Full Source" {
		t.Errorf("expected name 'Full Source', got %q", created.Name)
	}
	if created.Author == nil || *created.Author != "John Doe" {
		t.Errorf("expected author 'John Doe', got %v", created.Author)
	}
	if created.Year == nil || *created.Year != 2024 {
		t.Errorf("expected year 2024, got %v", created.Year)
	}
	if created.License == nil || *created.License != "CC BY-NC" {
		t.Errorf("expected license 'CC BY-NC', got %v", created.License)
	}
}

func TestCreateSource_InvalidJSON(t *testing.T) {
	s, database := setupSourcesTestServer(t)
	defer database.Close()

	req := httptest.NewRequest("POST", "/api/v1/sources", bytes.NewBufferString("not json"))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer test-api-key")
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("expected status %d, got %d", http.StatusBadRequest, w.Code)
	}
}
