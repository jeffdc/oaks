package embed

import (
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

func TestStartAndShutdown(t *testing.T) {
	// Create a temporary database file
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Start embedded server
	server, err := Start(Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}

	// Verify URL is set
	if server.URL() == "" {
		t.Error("expected URL to be set")
	}

	// Verify API key is set
	if server.APIKey() == "" {
		t.Error("expected API key to be set")
	}

	// Verify server responds to health check
	resp, err := http.Get(server.URL() + "/health")
	if err != nil {
		t.Fatalf("failed to call health endpoint: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected status 200, got %d", resp.StatusCode)
	}

	// Shutdown server
	if err := server.Shutdown(); err != nil {
		t.Errorf("failed to shutdown server: %v", err)
	}

	// Verify database file was created
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		t.Error("expected database file to be created")
	}
}

func TestAPIKeyAuthentication(t *testing.T) {
	// Create a temporary database file
	tmpDir := t.TempDir()
	dbPath := filepath.Join(tmpDir, "test.db")

	// Start embedded server
	server, err := Start(Config{
		DBPath: dbPath,
		Quiet:  true,
	})
	if err != nil {
		t.Fatalf("failed to start embedded server: %v", err)
	}
	defer server.Shutdown()

	// Try to create a source without auth (should fail with 401)
	req, _ := http.NewRequest("POST", server.URL()+"/api/v1/sources", nil)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("failed to make request: %v", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusUnauthorized {
		t.Errorf("expected 401 without auth, got %d", resp.StatusCode)
	}

	// Try with correct auth (should get further - may fail on validation but not auth)
	req, _ = http.NewRequest("POST", server.URL()+"/api/v1/sources", nil)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+server.APIKey())
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("failed to make request: %v", err)
	}
	resp.Body.Close()

	// Should not be 401 (may be 400/422 for validation, but auth should pass)
	if resp.StatusCode == http.StatusUnauthorized {
		t.Error("expected auth to succeed with correct API key")
	}
}

func TestGenerateSessionKey(t *testing.T) {
	key1, err := generateSessionKey()
	if err != nil {
		t.Fatalf("failed to generate session key: %v", err)
	}

	key2, err := generateSessionKey()
	if err != nil {
		t.Fatalf("failed to generate session key: %v", err)
	}

	// Keys should be non-empty
	if key1 == "" || key2 == "" {
		t.Error("expected non-empty keys")
	}

	// Keys should be different
	if key1 == key2 {
		t.Error("expected different keys for each generation")
	}

	// Key should be base64 encoded (44 chars for 32 bytes)
	if len(key1) != 44 {
		t.Errorf("expected key length 44, got %d", len(key1))
	}
}
