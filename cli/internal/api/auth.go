package api

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

const (
	// APIKeyEnvVar is the environment variable name for the API key.
	APIKeyEnvVar = "OAK_API_KEY"

	// DefaultAPIKeyPath is the default path for the API key file.
	DefaultAPIKeyPath = "~/.oak/api_key"

	// apiKeyBytes is the number of random bytes for generated keys.
	apiKeyBytes = 32
)

// RequireAuth returns middleware that requires Bearer token authentication.
// It only applies to write methods (POST, PUT, DELETE, PATCH).
// Read methods (GET, HEAD, OPTIONS) pass through without authentication.
func (s *Server) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Read methods are public - no auth required
		if !isWriteMethod(r.Method) {
			next.ServeHTTP(w, r)
			return
		}

		// Write methods require authentication
		token := extractBearerToken(r)
		if token == "" {
			RespondUnauthorized(w, "Missing authorization header")
			return
		}

		if !ValidateAPIKey(token, s.apiKey) {
			RespondUnauthorized(w, "Invalid API key")
			return
		}

		next.ServeHTTP(w, r)
	})
}

// extractBearerToken extracts the token from the Authorization header.
// Expected format: "Bearer <token>"
func extractBearerToken(r *http.Request) string {
	auth := r.Header.Get("Authorization")
	if auth == "" {
		return ""
	}

	// Check for Bearer prefix (case-insensitive per RFC 7235)
	const prefix = "Bearer "
	if len(auth) < len(prefix) {
		return ""
	}

	if !strings.EqualFold(auth[:len(prefix)], prefix) {
		return ""
	}

	return strings.TrimSpace(auth[len(prefix):])
}

// ValidateAPIKey compares the provided key against the expected key.
// Uses constant-time comparison to prevent timing attacks.
func ValidateAPIKey(provided, expected string) bool {
	if expected == "" {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(provided), []byte(expected)) == 1
}

// GenerateAPIKey generates a cryptographically secure API key.
// Returns a base64-encoded string of 32 random bytes.
func GenerateAPIKey() (string, error) {
	bytes := make([]byte, apiKeyBytes)
	_, err := rand.Read(bytes)
	if err != nil {
		return "", fmt.Errorf("failed to generate random bytes: %w", err)
	}
	return base64.URLEncoding.EncodeToString(bytes), nil
}

// LoadAPIKey loads the API key from environment variable or file.
// Environment variable takes precedence over file.
// Returns empty string if no key is configured.
func LoadAPIKey(path string) (string, error) {
	// Check environment variable first
	if key := os.Getenv(APIKeyEnvVar); key != "" {
		return key, nil
	}

	// Fall back to file
	expandedPath := expandPath(path)
	data, err := os.ReadFile(expandedPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil // No key configured
		}
		return "", fmt.Errorf("failed to read API key file: %w", err)
	}

	return strings.TrimSpace(string(data)), nil
}

// SaveAPIKey saves the API key to the specified file path.
// Creates the directory if it doesn't exist.
func SaveAPIKey(path string, key string) error {
	expandedPath := expandPath(path)

	// Create directory if needed
	dir := filepath.Dir(expandedPath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write file with restrictive permissions
	if err := os.WriteFile(expandedPath, []byte(key+"\n"), 0600); err != nil {
		return fmt.Errorf("failed to write API key file: %w", err)
	}

	return nil
}

// expandPath expands ~ to the user's home directory.
func expandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return path // Return as-is if we can't get home dir
		}
		return filepath.Join(home, path[2:])
	}
	return path
}

// EnsureAPIKey loads an existing API key or generates a new one if not found.
// If generated, the key is saved to the specified path.
func EnsureAPIKey(path string) (string, error) {
	key, err := LoadAPIKey(path)
	if err != nil {
		return "", err
	}

	if key != "" {
		return key, nil
	}

	// Generate new key
	key, err = GenerateAPIKey()
	if err != nil {
		return "", err
	}

	// Save to file
	if err := SaveAPIKey(path, key); err != nil {
		return "", err
	}

	return key, nil
}
