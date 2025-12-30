package api

import (
	"context"
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

