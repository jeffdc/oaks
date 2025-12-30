package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/go-chi/chi/v5"
)

func TestRequireAuth_PublicReadEndpoints(t *testing.T) {
	s := &Server{
		router: chi.NewRouter(),
		apiKey: "test-api-key",
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	r := chi.NewRouter()
	r.Use(s.RequireAuth)
	r.Get("/api/v1/species", handler)
	r.Head("/api/v1/species", handler)

	// GET and HEAD requests should not require auth
	// (OPTIONS is handled by CORS middleware, not auth)
	methods := []string{"GET", "HEAD"}
	for _, method := range methods {
		t.Run(method+" without auth", func(t *testing.T) {
			req := httptest.NewRequest(method, "/api/v1/species", http.NoBody)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("expected status %d for %s without auth, got %d", http.StatusOK, method, w.Code)
			}
		})
	}
}

func TestRequireAuth_ProtectedWriteEndpoints(t *testing.T) {
	s := &Server{
		router: chi.NewRouter(),
		apiKey: "test-api-key",
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(s.RequireAuth)
	r.Post("/api/v1/species", handler)
	r.Put("/api/v1/species/{name}", handler)
	r.Delete("/api/v1/species/{name}", handler)
	r.Patch("/api/v1/species/{name}", handler)

	writeMethods := []struct {
		method string
		path   string
	}{
		{"POST", "/api/v1/species"},
		{"PUT", "/api/v1/species/alba"},
		{"DELETE", "/api/v1/species/alba"},
		{"PATCH", "/api/v1/species/alba"},
	}

	for _, tc := range writeMethods {
		t.Run(tc.method+" without auth", func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, http.NoBody)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("expected status %d for %s without auth, got %d",
					http.StatusUnauthorized, tc.method, w.Code)
			}

			// Verify error response format
			var resp ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to parse error response: %v", err)
			}
			if resp.Error.Code != ErrCodeUnauthorized {
				t.Errorf("expected error code %q, got %q", ErrCodeUnauthorized, resp.Error.Code)
			}
		})

		t.Run(tc.method+" with valid auth", func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, http.NoBody)
			req.Header.Set("Authorization", "Bearer test-api-key")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			if w.Code != http.StatusOK {
				t.Errorf("expected status %d for %s with valid auth, got %d",
					http.StatusOK, tc.method, w.Code)
			}
		})

		t.Run(tc.method+" with invalid auth", func(t *testing.T) {
			req := httptest.NewRequest(tc.method, tc.path, http.NoBody)
			req.Header.Set("Authorization", "Bearer wrong-key")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("expected status %d for %s with invalid auth, got %d",
					http.StatusUnauthorized, tc.method, w.Code)
			}
		})
	}
}

func TestExtractBearerToken(t *testing.T) {
	tests := []struct {
		name     string
		header   string
		expected string
	}{
		{"valid Bearer token", "Bearer test-token-123", "test-token-123"},
		{"lowercase bearer", "bearer test-token-123", "test-token-123"},
		{"mixed case BEARER", "BEARER test-token-123", "test-token-123"},
		{"empty header", "", ""},
		{"no prefix", "test-token-123", ""},
		{"wrong prefix", "Basic test-token-123", ""},
		{"only Bearer", "Bearer", ""},
		{"Bearer with extra spaces", "Bearer   spaced-token  ", "spaced-token"},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/", http.NoBody)
			if tc.header != "" {
				req.Header.Set("Authorization", tc.header)
			}

			result := extractBearerToken(req)
			if result != tc.expected {
				t.Errorf("expected %q, got %q", tc.expected, result)
			}
		})
	}
}

func TestValidateAPIKey(t *testing.T) {
	tests := []struct {
		name     string
		provided string
		expected string
		valid    bool
	}{
		{"matching keys", "test-key-123", "test-key-123", true},
		{"mismatched keys", "wrong-key", "test-key-123", false},
		{"empty provided", "", "test-key-123", false},
		{"empty expected", "test-key-123", "", false},
		{"both empty", "", "", false},
		{"different lengths", "short", "much-longer-key", false},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			result := ValidateAPIKey(tc.provided, tc.expected)
			if result != tc.valid {
				t.Errorf("ValidateAPIKey(%q, %q) = %v, expected %v",
					tc.provided, tc.expected, result, tc.valid)
			}
		})
	}
}

func TestGenerateAPIKey(t *testing.T) {
	// Generate multiple keys and verify they're unique and valid
	keys := make(map[string]bool)

	for range 10 {
		key, err := GenerateAPIKey()
		if err != nil {
			t.Fatalf("GenerateAPIKey() error: %v", err)
		}

		// Should be non-empty
		if key == "" {
			t.Error("GenerateAPIKey() returned empty string")
		}

		// Should be ~43 characters (32 bytes base64 encoded)
		if len(key) < 40 || len(key) > 50 {
			t.Errorf("GenerateAPIKey() returned unexpected length: %d", len(key))
		}

		// Should be unique
		if keys[key] {
			t.Error("GenerateAPIKey() returned duplicate key")
		}
		keys[key] = true
	}
}

func TestLoadAPIKey_FromEnv(t *testing.T) {
	// Set environment variable
	os.Setenv(APIKeyEnvVar, "env-api-key")
	defer os.Unsetenv(APIKeyEnvVar)

	key, err := LoadAPIKey("/nonexistent/path")
	if err != nil {
		t.Fatalf("LoadAPIKey() error: %v", err)
	}

	if key != "env-api-key" {
		t.Errorf("expected 'env-api-key', got %q", key)
	}
}

func TestLoadAPIKey_FromFile(t *testing.T) {
	// Ensure env var is not set
	os.Unsetenv(APIKeyEnvVar)

	// Create temp file with API key
	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "api_key")
	if err := os.WriteFile(keyFile, []byte("file-api-key\n"), 0600); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	key, err := LoadAPIKey(keyFile)
	if err != nil {
		t.Fatalf("LoadAPIKey() error: %v", err)
	}

	if key != "file-api-key" {
		t.Errorf("expected 'file-api-key', got %q", key)
	}
}

func TestLoadAPIKey_FileNotFound(t *testing.T) {
	os.Unsetenv(APIKeyEnvVar)

	key, err := LoadAPIKey("/nonexistent/path/api_key")
	if err != nil {
		t.Fatalf("LoadAPIKey() error: %v", err)
	}

	if key != "" {
		t.Errorf("expected empty string for missing file, got %q", key)
	}
}

func TestLoadAPIKey_EnvTakesPrecedence(t *testing.T) {
	// Create temp file with different key
	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "api_key")
	if err := os.WriteFile(keyFile, []byte("file-api-key\n"), 0600); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	// Set environment variable
	os.Setenv(APIKeyEnvVar, "env-api-key")
	defer os.Unsetenv(APIKeyEnvVar)

	key, err := LoadAPIKey(keyFile)
	if err != nil {
		t.Fatalf("LoadAPIKey() error: %v", err)
	}

	// Env should take precedence
	if key != "env-api-key" {
		t.Errorf("expected 'env-api-key' (from env), got %q", key)
	}
}

func TestSaveAPIKey(t *testing.T) {
	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "subdir", "api_key")

	err := SaveAPIKey(keyFile, "saved-api-key")
	if err != nil {
		t.Fatalf("SaveAPIKey() error: %v", err)
	}

	// Verify file was created
	data, err := os.ReadFile(keyFile)
	if err != nil {
		t.Fatalf("failed to read saved file: %v", err)
	}

	if string(data) != "saved-api-key\n" {
		t.Errorf("expected 'saved-api-key\\n', got %q", string(data))
	}

	// Verify file permissions
	info, err := os.Stat(keyFile)
	if err != nil {
		t.Fatalf("failed to stat file: %v", err)
	}

	mode := info.Mode().Perm()
	if mode != 0600 {
		t.Errorf("expected file mode 0600, got %o", mode)
	}

	// Verify directory permissions
	dirInfo, err := os.Stat(filepath.Dir(keyFile))
	if err != nil {
		t.Fatalf("failed to stat directory: %v", err)
	}

	dirMode := dirInfo.Mode().Perm()
	if dirMode != 0700 {
		t.Errorf("expected directory mode 0700, got %o", dirMode)
	}
}

func TestExpandPath(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("cannot get home directory")
	}

	tests := []struct {
		input    string
		expected string
	}{
		{"~/test/path", filepath.Join(home, "test/path")},
		{"/absolute/path", "/absolute/path"},
		{"relative/path", "relative/path"},
		{"~notahome/path", "~notahome/path"}, // Only ~/ is expanded
	}

	for _, tc := range tests {
		t.Run(tc.input, func(t *testing.T) {
			result := expandPath(tc.input)
			if result != tc.expected {
				t.Errorf("expandPath(%q) = %q, expected %q", tc.input, result, tc.expected)
			}
		})
	}
}

func TestEnsureAPIKey_ExistingKey(t *testing.T) {
	os.Unsetenv(APIKeyEnvVar)

	// Create temp file with existing key
	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "api_key")
	if err := os.WriteFile(keyFile, []byte("existing-key\n"), 0600); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}

	key, err := EnsureAPIKey(keyFile)
	if err != nil {
		t.Fatalf("EnsureAPIKey() error: %v", err)
	}

	if key != "existing-key" {
		t.Errorf("expected 'existing-key', got %q", key)
	}
}

func TestEnsureAPIKey_GeneratesNew(t *testing.T) {
	os.Unsetenv(APIKeyEnvVar)

	tmpDir := t.TempDir()
	keyFile := filepath.Join(tmpDir, "api_key")

	key, err := EnsureAPIKey(keyFile)
	if err != nil {
		t.Fatalf("EnsureAPIKey() error: %v", err)
	}

	// Should have generated a key
	if key == "" {
		t.Error("EnsureAPIKey() returned empty key")
	}

	// Key should be saved to file
	savedKey, err := LoadAPIKey(keyFile)
	if err != nil {
		t.Fatalf("failed to load saved key: %v", err)
	}

	if savedKey != key {
		t.Errorf("saved key %q doesn't match returned key %q", savedKey, key)
	}
}

func TestRequireAuth_EmptyAPIKey(t *testing.T) {
	// Server with empty API key - all writes should fail
	s := &Server{
		router: chi.NewRouter(),
		apiKey: "",
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(s.RequireAuth)
	r.Post("/api/v1/species", handler)

	// Even with a token, should fail because server has no API key configured
	req := httptest.NewRequest("POST", "/api/v1/species", http.NoBody)
	req.Header.Set("Authorization", "Bearer any-token")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 when server has no API key, got %d", w.Code)
	}
}
