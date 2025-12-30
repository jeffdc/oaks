// Package client provides an HTTP client for the Oak Compendium API.
// It supports profile-based configuration and version compatibility checking.
package client

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jeff/oaks/cli/internal/config"
)

// CLIVersion is the current CLI version for compatibility checking.
// This should be updated when the CLI version changes.
const CLIVersion = "1.0.0"

// Client is an HTTP client for the Oak Compendium API.
type Client struct {
	baseURL    string
	apiKey     string
	httpClient *http.Client
	profile    *config.ResolvedProfile

	// Version check state
	versionChecked bool
	skipVersion    bool
}

// VersionInfo contains version information from the API server.
type VersionInfo struct {
	API       string `json:"api"`
	MinClient string `json:"min_client"`
}

// HealthResponse is the response from the health endpoint.
type HealthResponse struct {
	Status  string      `json:"status"`
	Version VersionInfo `json:"version"`
}

// APIError represents an error response from the API.
type APIError struct {
	StatusCode int
	Code       string `json:"code"`
	Message    string `json:"message"`
}

func (e *APIError) Error() string {
	if e.Code != "" {
		return fmt.Sprintf("API error (%d %s): %s", e.StatusCode, e.Code, e.Message)
	}
	return fmt.Sprintf("API error (%d): %s", e.StatusCode, e.Message)
}

// ValidationError represents a field-level validation error.
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// MultiValidationError wraps multiple validation errors from the API.
type MultiValidationError struct {
	Errors []ValidationError `json:"errors"`
}

func (e *MultiValidationError) Error() string {
	if len(e.Errors) == 0 {
		return "validation failed"
	}
	msgs := make([]string, 0, len(e.Errors))
	for _, err := range e.Errors {
		msgs = append(msgs, fmt.Sprintf("%s: %s", err.Field, err.Message))
	}
	return fmt.Sprintf("validation errors: %s", strings.Join(msgs, "; "))
}

// Option is a functional option for configuring the client.
type Option func(*Client)

// WithHTTPClient sets a custom HTTP client.
func WithHTTPClient(client *http.Client) Option {
	return func(c *Client) {
		c.httpClient = client
	}
}

// WithSkipVersionCheck disables API version compatibility checking.
func WithSkipVersionCheck(skip bool) Option {
	return func(c *Client) {
		c.skipVersion = skip
	}
}

// New creates a new API client from a resolved profile.
// Returns an error if the profile is for local mode (no API URL).
func New(profile *config.ResolvedProfile, opts ...Option) (*Client, error) {
	if profile == nil || profile.IsLocal() {
		return nil, fmt.Errorf("cannot create API client: profile is for local mode")
	}

	c := &Client{
		baseURL: strings.TrimSuffix(profile.URL, "/"),
		apiKey:  profile.Key,
		profile: profile,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}

	for _, opt := range opts {
		opt(c)
	}

	return c, nil
}

// Profile returns the profile used by this client.
func (c *Client) Profile() *config.ResolvedProfile {
	return c.profile
}

// ProfileName returns the name of the profile for display purposes.
func (c *Client) ProfileName() string {
	if c.profile != nil {
		return c.profile.Name
	}
	return "unknown"
}

// CheckCompatibility checks if the CLI version is compatible with the API.
// This is called automatically on first API request unless skipped.
// Version check failures are treated as warnings and do not prevent operation.
func (c *Client) CheckCompatibility() error {
	if c.versionChecked || c.skipVersion {
		return nil
	}

	health, err := c.Health()
	c.versionChecked = true
	if err != nil {
		// Version check failure is a warning, not a hard error.
		// Continue without version check - we intentionally ignore this error.
		return nil //nolint:nilerr // Intentionally ignoring version check errors
	}

	// Check minimum client version
	if health.Version.MinClient != "" {
		cmp := compareVersions(CLIVersion, health.Version.MinClient)
		if cmp < 0 {
			return fmt.Errorf(
				"CLI version %s is too old for API (requires >= %s). Run: go install github.com/jeff/oaks/cli@latest",
				CLIVersion, health.Version.MinClient,
			)
		}
	}

	// Note: CLI newer than API is just informational, not an error.
	// Could log a warning if health.Version.API != "" && compareVersions(CLIVersion, health.Version.API) > 0

	return nil
}

// Health fetches the API health status and version info.
func (c *Client) Health() (*HealthResponse, error) {
	ctx := context.Background()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/api/v1/health", http.NoBody)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("connection error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.parseError(resp)
	}

	var health HealthResponse
	if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
		return nil, fmt.Errorf("failed to parse health response: %w", err)
	}

	return &health, nil
}

// VerifyAuth verifies the API key is valid for write operations.
// Call this before attempting write operations to fail fast on auth issues.
func (c *Client) VerifyAuth() error {
	ctx := context.Background()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/api/v1/auth/verify", http.NoBody)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	// Must include auth header
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("connection error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return c.parseError(resp)
	}

	return nil
}

// doRequest performs an HTTP request with authentication and error handling.
func (c *Client) doRequest(method, path string, body interface{}) (*http.Response, error) {
	// Check compatibility on first request
	if err := c.CheckCompatibility(); err != nil {
		return nil, err
	}

	var bodyReader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, fmt.Errorf("failed to marshal request body: %w", err)
		}
		bodyReader = bytes.NewReader(data)
	}

	ctx := context.Background()
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bodyReader)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	// Set headers
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("connection error to %s: %w", c.profile.Name, err)
	}

	return resp, nil
}

// parseError parses an error response from the API.
func (c *Client) parseError(resp *http.Response) error {
	body, _ := io.ReadAll(resp.Body)

	switch resp.StatusCode {
	case http.StatusUnauthorized:
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "unauthorized",
			Message:    fmt.Sprintf("invalid API key for profile [%s]", c.profile.Name),
		}
	case http.StatusForbidden:
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "forbidden",
			Message:    "access denied",
		}
	case http.StatusNotFound:
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "not_found",
			Message:    "resource not found",
		}
	case http.StatusConflict:
		var apiErr APIError
		if json.Unmarshal(body, &apiErr) == nil && apiErr.Message != "" {
			apiErr.StatusCode = resp.StatusCode
			return &apiErr
		}
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "conflict",
			Message:    "resource already exists",
		}
	case http.StatusUnprocessableEntity:
		// Try to parse validation errors
		var wrapper struct {
			Errors []ValidationError `json:"errors"`
		}
		if json.Unmarshal(body, &wrapper) == nil && len(wrapper.Errors) > 0 {
			return &MultiValidationError{Errors: wrapper.Errors}
		}
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "validation_error",
			Message:    string(body),
		}
	case http.StatusTooManyRequests:
		return &APIError{
			StatusCode: resp.StatusCode,
			Code:       "rate_limit",
			Message:    "rate limit exceeded, please try again later",
		}
	default:
		if resp.StatusCode >= 500 {
			return &APIError{
				StatusCode: resp.StatusCode,
				Code:       "server_error",
				Message:    "server error, please try again later",
			}
		}
		var apiErr APIError
		if json.Unmarshal(body, &apiErr) == nil && apiErr.Message != "" {
			apiErr.StatusCode = resp.StatusCode
			return &apiErr
		}
		return &APIError{
			StatusCode: resp.StatusCode,
			Message:    string(body),
		}
	}
}

// parseResponse reads and parses a JSON response into the target.
func (c *Client) parseResponse(resp *http.Response, target interface{}) error {
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return c.parseError(resp)
	}

	if target == nil {
		return nil
	}

	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("failed to parse response: %w", err)
	}

	return nil
}

// compareVersions compares two semantic versions.
// Returns -1 if a < b, 0 if a == b, 1 if a > b.
func compareVersions(a, b string) int {
	aParts := parseVersion(a)
	bParts := parseVersion(b)

	for i := 0; i < 3; i++ {
		if aParts[i] < bParts[i] {
			return -1
		}
		if aParts[i] > bParts[i] {
			return 1
		}
	}
	return 0
}

// parseVersion parses a semantic version string into [major, minor, patch].
func parseVersion(v string) [3]int {
	v = strings.TrimPrefix(v, "v")
	parts := strings.Split(v, ".")
	var result [3]int
	for i := 0; i < len(parts) && i < 3; i++ {
		n, _ := strconv.Atoi(parts[i])
		result[i] = n
	}
	return result
}

// IsNotFoundError returns true if the error is a 404 Not Found.
func IsNotFoundError(err error) bool {
	var apiErr *APIError
	if errors.As(err, &apiErr) {
		return apiErr.StatusCode == http.StatusNotFound
	}
	return false
}

// IsConflictError returns true if the error is a 409 Conflict.
func IsConflictError(err error) bool {
	var apiErr *APIError
	if errors.As(err, &apiErr) {
		return apiErr.StatusCode == http.StatusConflict
	}
	return false
}

// IsAuthError returns true if the error is a 401 Unauthorized.
func IsAuthError(err error) bool {
	var apiErr *APIError
	if errors.As(err, &apiErr) {
		return apiErr.StatusCode == http.StatusUnauthorized
	}
	return false
}
