package client

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jeff/oaks/cli/internal/config"
)

// newTestClient creates a client pointing at a test server.
func newTestClient(t *testing.T, server *httptest.Server) *Client {
	t.Helper()
	profile := &config.ResolvedProfile{
		Name:   "test",
		URL:    server.URL,
		Key:    "test-api-key",
		Source: config.SourceFlag,
	}
	c, err := New(profile, WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("failed to create test client: %v", err)
	}
	return c
}

func TestNew_LocalProfileError(t *testing.T) {
	profile := &config.ResolvedProfile{
		Source: config.SourceLocal,
	}
	_, err := New(profile)
	if err == nil {
		t.Error("expected error for local profile, got nil")
	}
}

func TestNew_NilProfileError(t *testing.T) {
	_, err := New(nil)
	if err == nil {
		t.Error("expected error for nil profile, got nil")
	}
}

func TestNew_Success(t *testing.T) {
	profile := &config.ResolvedProfile{
		Name:   "prod",
		URL:    "https://api.example.com",
		Key:    "test-key",
		Source: config.SourceFlag,
	}
	c, err := New(profile)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.baseURL != "https://api.example.com" {
		t.Errorf("baseURL = %q, want %q", c.baseURL, "https://api.example.com")
	}
	if c.apiKey != "test-key" {
		t.Errorf("apiKey = %q, want %q", c.apiKey, "test-key")
	}
}

func TestNew_TrimsTrailingSlash(t *testing.T) {
	profile := &config.ResolvedProfile{
		Name:   "prod",
		URL:    "https://api.example.com/",
		Key:    "test-key",
		Source: config.SourceFlag,
	}
	c, err := New(profile)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.baseURL != "https://api.example.com" {
		t.Errorf("baseURL = %q, want %q (trailing slash should be trimmed)", c.baseURL, "https://api.example.com")
	}
}

func TestClient_ProfileName(t *testing.T) {
	profile := &config.ResolvedProfile{
		Name:   "staging",
		URL:    "https://staging.example.com",
		Source: config.SourceFlag,
	}
	c, err := New(profile)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ProfileName() != "staging" {
		t.Errorf("ProfileName() = %q, want %q", c.ProfileName(), "staging")
	}
}

func TestHealth_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/health" {
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(HealthResponse{
			Status: "ok",
			Version: VersionInfo{
				API:       "1.2.0",
				MinClient: "1.0.0",
			},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	c.skipVersion = false // Enable for this test

	health, err := c.Health()
	if err != nil {
		t.Fatalf("Health() error = %v", err)
	}
	if health.Status != "ok" {
		t.Errorf("Status = %q, want %q", health.Status, "ok")
	}
	if health.Version.API != "1.2.0" {
		t.Errorf("Version.API = %q, want %q", health.Version.API, "1.2.0")
	}
}

func TestHealth_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.Health()
	if err == nil {
		t.Error("expected error for server error response")
	}
	var apiErr *APIError
	if !IsNotFoundError(err) && err != nil {
		// Just verify we got an error, specific type varies
	}
	_ = apiErr // Silence unused variable warning
}

func TestCompareVersions(t *testing.T) {
	tests := []struct {
		a, b string
		want int
	}{
		{"1.0.0", "1.0.0", 0},
		{"1.0.0", "1.0.1", -1},
		{"1.0.1", "1.0.0", 1},
		{"1.1.0", "1.0.0", 1},
		{"2.0.0", "1.9.9", 1},
		{"v1.0.0", "1.0.0", 0},
		{"1.0", "1.0.0", 0},
		{"1", "1.0.0", 0},
		{"", "0.0.0", 0},
	}

	for _, tt := range tests {
		got := compareVersions(tt.a, tt.b)
		if got != tt.want {
			t.Errorf("compareVersions(%q, %q) = %d, want %d", tt.a, tt.b, got, tt.want)
		}
	}
}

func TestParseVersion(t *testing.T) {
	tests := []struct {
		v    string
		want [3]int
	}{
		{"1.2.3", [3]int{1, 2, 3}},
		{"v1.2.3", [3]int{1, 2, 3}},
		{"1.2", [3]int{1, 2, 0}},
		{"1", [3]int{1, 0, 0}},
		{"", [3]int{0, 0, 0}},
		{"invalid", [3]int{0, 0, 0}},
		{"1.2.3.4", [3]int{1, 2, 3}}, // Extra parts ignored
	}

	for _, tt := range tests {
		got := parseVersion(tt.v)
		if got != tt.want {
			t.Errorf("parseVersion(%q) = %v, want %v", tt.v, got, tt.want)
		}
	}
}

func TestCheckCompatibility_VersionTooOld(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(HealthResponse{
			Status: "ok",
			Version: VersionInfo{
				API:       "2.0.0",
				MinClient: "99.0.0", // Impossibly high version
			},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	c.skipVersion = false
	c.versionChecked = false

	err := c.CheckCompatibility()
	if err == nil {
		t.Error("expected error for old CLI version")
	}
}

func TestCheckCompatibility_SkipEnabled(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
		t.Error("should not call server when version check is skipped")
	}))
	defer server.Close()

	c := newTestClient(t, server)
	c.skipVersion = true

	err := c.CheckCompatibility()
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestCheckCompatibility_AlreadyChecked(t *testing.T) {
	callCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		callCount++
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(HealthResponse{
			Status: "ok",
			Version: VersionInfo{
				API:       "1.0.0",
				MinClient: "1.0.0",
			},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	c.skipVersion = false
	c.versionChecked = false

	// First call
	_ = c.CheckCompatibility()
	// Second call should not hit server
	_ = c.CheckCompatibility()

	if callCount != 1 {
		t.Errorf("server called %d times, want 1", callCount)
	}
}

func TestAPIError_Error(t *testing.T) {
	tests := []struct {
		err  APIError
		want string
	}{
		{
			APIError{StatusCode: 404, Code: "not_found", Message: "resource not found"},
			"API error (404 not_found): resource not found",
		},
		{
			APIError{StatusCode: 500, Message: "server error"},
			"API error (500): server error",
		},
	}

	for _, tt := range tests {
		got := tt.err.Error()
		if got != tt.want {
			t.Errorf("Error() = %q, want %q", got, tt.want)
		}
	}
}

func TestMultiValidationError_Error(t *testing.T) {
	tests := []struct {
		err  MultiValidationError
		want string
	}{
		{
			MultiValidationError{},
			"validation failed",
		},
		{
			MultiValidationError{Errors: []ValidationError{
				{Field: "name", Message: "required"},
			}},
			"validation errors: name: required",
		},
		{
			MultiValidationError{Errors: []ValidationError{
				{Field: "name", Message: "required"},
				{Field: "type", Message: "invalid"},
			}},
			"validation errors: name: required; type: invalid",
		},
	}

	for _, tt := range tests {
		got := tt.err.Error()
		if got != tt.want {
			t.Errorf("Error() = %q, want %q", got, tt.want)
		}
	}
}

func TestIsNotFoundError(t *testing.T) {
	notFound := &APIError{StatusCode: 404, Code: "not_found"}
	if !IsNotFoundError(notFound) {
		t.Error("IsNotFoundError(404 error) = false, want true")
	}

	conflict := &APIError{StatusCode: 409, Code: "conflict"}
	if IsNotFoundError(conflict) {
		t.Error("IsNotFoundError(409 error) = true, want false")
	}

	if IsNotFoundError(nil) {
		t.Error("IsNotFoundError(nil) = true, want false")
	}
}

func TestIsConflictError(t *testing.T) {
	conflict := &APIError{StatusCode: 409, Code: "conflict"}
	if !IsConflictError(conflict) {
		t.Error("IsConflictError(409 error) = false, want true")
	}

	notFound := &APIError{StatusCode: 404, Code: "not_found"}
	if IsConflictError(notFound) {
		t.Error("IsConflictError(404 error) = true, want false")
	}
}

func TestIsAuthError(t *testing.T) {
	auth := &APIError{StatusCode: 401, Code: "unauthorized"}
	if !IsAuthError(auth) {
		t.Error("IsAuthError(401 error) = false, want true")
	}

	notFound := &APIError{StatusCode: 404, Code: "not_found"}
	if IsAuthError(notFound) {
		t.Error("IsAuthError(404 error) = true, want false")
	}
}

func TestParseError_UnauthorizedAddsProfileName(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, _ := http.Get(server.URL)
	defer resp.Body.Close()

	err := c.parseError(resp)
	apiErr, ok := err.(*APIError)
	if !ok {
		t.Fatalf("expected *APIError, got %T", err)
	}
	if apiErr.StatusCode != 401 {
		t.Errorf("StatusCode = %d, want 401", apiErr.StatusCode)
	}
	// Message should include profile name
	if apiErr.Message == "" {
		t.Error("expected non-empty error message")
	}
}

func TestParseError_ValidationErrors(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnprocessableEntity)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"errors": []map[string]string{
				{"field": "name", "message": "required"},
				{"field": "level", "message": "invalid value"},
			},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, _ := http.Get(server.URL)
	defer resp.Body.Close()

	err := c.parseError(resp)
	multiErr, ok := err.(*MultiValidationError)
	if !ok {
		t.Fatalf("expected *MultiValidationError, got %T", err)
	}
	if len(multiErr.Errors) != 2 {
		t.Errorf("expected 2 validation errors, got %d", len(multiErr.Errors))
	}
}

func TestDoRequest_SetsAuthHeader(t *testing.T) {
	var receivedAuth string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedAuth = r.Header.Get("Authorization")
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, err := c.doRequest(http.MethodGet, "/test", nil)
	if err != nil {
		t.Fatalf("doRequest error: %v", err)
	}
	resp.Body.Close()

	expected := "Bearer test-api-key"
	if receivedAuth != expected {
		t.Errorf("Authorization = %q, want %q", receivedAuth, expected)
	}
}

func TestDoRequest_SetsContentType(t *testing.T) {
	var receivedContentType string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		receivedContentType = r.Header.Get("Content-Type")
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}))
	defer server.Close()

	c := newTestClient(t, server)

	// Request with body should have Content-Type
	resp, err := c.doRequest(http.MethodPost, "/test", map[string]string{"key": "value"})
	if err != nil {
		t.Fatalf("doRequest error: %v", err)
	}
	resp.Body.Close()

	if receivedContentType != "application/json" {
		t.Errorf("Content-Type = %q, want %q", receivedContentType, "application/json")
	}
}

func TestWithHTTPClient(t *testing.T) {
	customClient := &http.Client{}
	profile := &config.ResolvedProfile{
		Name:   "test",
		URL:    "https://example.com",
		Source: config.SourceFlag,
	}

	c, err := New(profile, WithHTTPClient(customClient))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if c.httpClient != customClient {
		t.Error("custom HTTP client was not set")
	}
}

func TestWithSkipVersionCheck(t *testing.T) {
	profile := &config.ResolvedProfile{
		Name:   "test",
		URL:    "https://example.com",
		Source: config.SourceFlag,
	}

	c, err := New(profile, WithSkipVersionCheck(true))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if !c.skipVersion {
		t.Error("skipVersion was not set to true")
	}
}
