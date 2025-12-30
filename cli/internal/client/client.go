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

// Default retry configuration values.
const (
	DefaultMaxRetries     = 3
	DefaultRetryBaseDelay = 1 * time.Second
	DefaultRetryMaxDelay  = 10 * time.Second
)

// Client is an HTTP client for the Oak Compendium API.
type Client struct {
	baseURL    string
	apiKey     string
	httpClient *http.Client
	profile    *config.ResolvedProfile

	// Version check state
	versionChecked bool
	skipVersion    bool

	// Retry configuration
	maxRetries     int
	retryBaseDelay time.Duration
	retryMaxDelay  time.Duration
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

// ConnectionError represents a connection failure to the API server.
type ConnectionError struct {
	URL     string
	Profile string
	Err     error
}

func (e *ConnectionError) Error() string {
	return fmt.Sprintf("failed to connect to API server at %s (profile: %s): %s", e.URL, e.Profile, e.Err)
}

func (e *ConnectionError) Unwrap() error {
	return e.Err
}

// IsConnectionError returns true if the error is a connection failure.
func IsConnectionError(err error) bool {
	var connErr *ConnectionError
	return errors.As(err, &connErr)
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

// WithMaxRetries sets the maximum number of retry attempts for transient failures.
func WithMaxRetries(retries int) Option {
	return func(c *Client) {
		if retries >= 0 {
			c.maxRetries = retries
		}
	}
}

// WithRetryDelay sets the base delay for exponential backoff.
func WithRetryDelay(base, maxDelay time.Duration) Option {
	return func(c *Client) {
		if base > 0 {
			c.retryBaseDelay = base
		}
		if maxDelay > 0 {
			c.retryMaxDelay = maxDelay
		}
	}
}

// WithTimeout sets the HTTP client timeout.
func WithTimeout(timeout time.Duration) Option {
	return func(c *Client) {
		if timeout > 0 {
			c.httpClient.Timeout = timeout
		}
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
		maxRetries:     DefaultMaxRetries,
		retryBaseDelay: DefaultRetryBaseDelay,
		retryMaxDelay:  DefaultRetryMaxDelay,
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

// doRequest performs an HTTP request with authentication, retry logic, and error handling.
// It automatically retries on transient failures (5xx errors, timeouts, connection errors)
// with exponential backoff.
func (c *Client) doRequest(method, path string, body interface{}) (*http.Response, error) {
	if err := c.CheckCompatibility(); err != nil {
		return nil, err
	}

	bodyData, err := c.marshalBody(body)
	if err != nil {
		return nil, err
	}

	var lastErr error
	for attempt := 0; attempt <= c.maxRetries; attempt++ {
		if attempt > 0 {
			time.Sleep(c.calculateBackoff(attempt))
		}

		resp, err := c.executeRequest(method, path, bodyData, body != nil)
		if err != nil {
			lastErr = c.wrapConnectionError(err)
			if c.isRetryableError(err) {
				continue
			}
			return nil, lastErr
		}

		if c.isRetryableStatusCode(resp.StatusCode) {
			resp.Body.Close()
			lastErr = &APIError{
				StatusCode: resp.StatusCode,
				Code:       "server_error",
				Message:    fmt.Sprintf("server error (attempt %d/%d)", attempt+1, c.maxRetries+1),
			}
			continue
		}

		return resp, nil
	}

	if lastErr != nil {
		return nil, fmt.Errorf("request failed after %d attempts: %w", c.maxRetries+1, lastErr)
	}
	return nil, fmt.Errorf("request failed after %d attempts", c.maxRetries+1)
}

// marshalBody serializes the request body to JSON if present.
func (c *Client) marshalBody(body interface{}) ([]byte, error) {
	if body == nil {
		return nil, nil
	}
	data, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %w", err)
	}
	return data, nil
}

// executeRequest creates and executes a single HTTP request.
func (c *Client) executeRequest(method, path string, bodyData []byte, hasBody bool) (*http.Response, error) {
	var bodyReader io.Reader
	if bodyData != nil {
		bodyReader = bytes.NewReader(bodyData)
	}

	ctx := context.Background()
	req, err := http.NewRequestWithContext(ctx, method, c.baseURL+path, bodyReader)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	if hasBody {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.apiKey != "" {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

	return c.httpClient.Do(req)
}

// calculateBackoff returns the delay for the given retry attempt using exponential backoff.
// The delay doubles with each attempt: base, 2*base, 4*base, etc., capped at maxDelay.
func (c *Client) calculateBackoff(attempt int) time.Duration {
	// Exponential backoff: base * 2^(attempt-1)
	delay := c.retryBaseDelay * time.Duration(1<<(attempt-1))
	if delay > c.retryMaxDelay {
		delay = c.retryMaxDelay
	}
	return delay
}

// isRetryableError returns true if the error is a transient failure that should be retried.
func (c *Client) isRetryableError(err error) bool {
	if err == nil {
		return false
	}

	// Check for timeout errors
	var netErr interface{ Timeout() bool }
	if errors.As(err, &netErr) && netErr.Timeout() {
		return true
	}

	// Check for connection refused and other network errors
	errStr := err.Error()
	retryablePatterns := []string{
		"connection refused",
		"connection reset",
		"no such host",
		"network is unreachable",
		"i/o timeout",
		"EOF",
	}
	for _, pattern := range retryablePatterns {
		if strings.Contains(strings.ToLower(errStr), strings.ToLower(pattern)) {
			return true
		}
	}

	return false
}

// isRetryableStatusCode returns true if the HTTP status code indicates a transient failure.
func (c *Client) isRetryableStatusCode(statusCode int) bool {
	// Retry on 5xx server errors and 429 (rate limited)
	return statusCode >= 500 || statusCode == http.StatusTooManyRequests
}

// wrapConnectionError wraps a connection error with additional context.
func (c *Client) wrapConnectionError(err error) error {
	return &ConnectionError{
		URL:     c.baseURL,
		Profile: c.profile.Name,
		Err:     err,
	}
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
