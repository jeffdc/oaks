package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/db"
)

func TestHealthEndpoint_Success(t *testing.T) {
	s := New(nil, "", nil, WithoutMiddleware())

	req := httptest.NewRequest("GET", "/health", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got %q", contentType)
	}

	var resp HealthResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Status != "ok" {
		t.Errorf("expected status 'ok', got %q", resp.Status)
	}
}

func TestHealthReadyEndpoint_NilDatabase(t *testing.T) {
	s := New(nil, "", nil, WithoutMiddleware())

	req := httptest.NewRequest("GET", "/health/ready", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status %d, got %d", http.StatusServiceUnavailable, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got %q", contentType)
	}

	var resp ReadyResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Status != "unavailable" {
		t.Errorf("expected status 'unavailable', got %q", resp.Status)
	}
	if resp.Database != "error" {
		t.Errorf("expected database 'error', got %q", resp.Database)
	}
	if resp.Error == "" {
		t.Error("expected error message, got empty string")
	}
}

func TestHealthReadyEndpoint_ConnectedDatabase(t *testing.T) {
	// Create an in-memory database
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	defer database.Close()

	s := New(database, "", nil, WithoutMiddleware())

	req := httptest.NewRequest("GET", "/health/ready", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}

	contentType := w.Header().Get("Content-Type")
	if contentType != "application/json" {
		t.Errorf("expected Content-Type 'application/json', got %q", contentType)
	}

	var resp ReadyResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Status != "ready" {
		t.Errorf("expected status 'ready', got %q", resp.Status)
	}
	if resp.Database != "connected" {
		t.Errorf("expected database 'connected', got %q", resp.Database)
	}
	if resp.Error != "" {
		t.Errorf("expected no error, got %q", resp.Error)
	}
}

func TestHealthReadyEndpoint_ClosedDatabase(t *testing.T) {
	// Create and close an in-memory database
	database, err := db.New(":memory:")
	if err != nil {
		t.Fatalf("failed to create database: %v", err)
	}
	database.Close() // Close the database to simulate connection failure

	s := New(database, "", nil, WithoutMiddleware())

	req := httptest.NewRequest("GET", "/health/ready", http.NoBody)
	w := httptest.NewRecorder()

	s.Router().ServeHTTP(w, req)

	if w.Code != http.StatusServiceUnavailable {
		t.Errorf("expected status %d, got %d", http.StatusServiceUnavailable, w.Code)
	}

	var resp ReadyResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if resp.Status != "unavailable" {
		t.Errorf("expected status 'unavailable', got %q", resp.Status)
	}
	if resp.Database != "error" {
		t.Errorf("expected database 'error', got %q", resp.Database)
	}
	if resp.Error == "" {
		t.Error("expected error message, got empty string")
	}
}
