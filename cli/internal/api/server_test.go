package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestNew(t *testing.T) {
	// Test with nil logger (should use default)
	s := New(nil, "test-key", nil, WithoutMiddleware())
	if s == nil {
		t.Fatal("expected server to be created")
	}
	if s.router == nil {
		t.Error("expected router to be initialized")
	}
	if s.apiKey != "test-key" {
		t.Errorf("expected apiKey to be 'test-key', got %q", s.apiKey)
	}
}

// Health endpoint tests are in health_test.go

func TestShutdown(t *testing.T) {
	s := New(nil, "", nil, WithoutMiddleware())

	// Shutdown without starting should not error
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := s.Shutdown(ctx); err != nil {
		t.Errorf("expected no error on shutdown without start, got: %v", err)
	}
}

func TestAPIRoutes_ReturnNotImplemented(t *testing.T) {
	s := New(nil, "", nil, WithoutMiddleware())

	routes := []struct {
		method string
		path   string
	}{
		{"GET", "/api/v1/species"},
		{"GET", "/api/v1/species/alba"},
		{"GET", "/api/v1/taxa"},
		{"GET", "/api/v1/taxa/section/Quercus"},
		{"GET", "/api/v1/sources"},
		{"GET", "/api/v1/sources/1"},
		{"GET", "/api/v1/species/alba/sources"},
		{"GET", "/api/v1/export"},
	}

	for _, tc := range routes {
		t.Run(tc.method+" "+tc.path, func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, http.NoBody)
			w := httptest.NewRecorder()

			s.Router().ServeHTTP(w, req)

			if w.Code != http.StatusNotImplemented {
				t.Errorf("expected status %d for %s %s, got %d",
					http.StatusNotImplemented, tc.method, tc.path, w.Code)
			}
		})
	}
}
