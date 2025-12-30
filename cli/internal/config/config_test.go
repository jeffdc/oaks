package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoad(t *testing.T) {
	// Create a temporary config file
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.yaml")

	configContent := `
profiles:
  prod:
    url: https://api.oakcompendium.com
    key: prod-key-12345
  staging:
    url: https://staging.oakcompendium.com
    key: staging-key-67890
  local-server:
    url: http://localhost:8080
    key: dev-key

default_profile: staging
`
	if err := os.WriteFile(configPath, []byte(configContent), 0o600); err != nil {
		t.Fatalf("failed to write test config: %v", err)
	}

	cfg, err := Load(configPath)
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if len(cfg.Profiles) != 3 {
		t.Errorf("expected 3 profiles, got %d", len(cfg.Profiles))
	}

	if cfg.DefaultProfile != "staging" {
		t.Errorf("expected default_profile = staging, got %s", cfg.DefaultProfile)
	}

	prod := cfg.Profiles["prod"]
	if prod.URL != "https://api.oakcompendium.com" {
		t.Errorf("prod URL = %q, want %q", prod.URL, "https://api.oakcompendium.com")
	}
}

func TestLoad_NonExistent(t *testing.T) {
	cfg, err := Load("/nonexistent/path/config.yaml")
	if err != nil {
		t.Fatalf("Load() should not error for non-existent file, got: %v", err)
	}

	if cfg == nil {
		t.Fatal("Load() returned nil config")
	}

	if len(cfg.Profiles) != 0 {
		t.Errorf("expected 0 profiles for non-existent file, got %d", len(cfg.Profiles))
	}
}

func TestResolve_LegacyEnvOverridesAll(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{
			"prod": {URL: "https://prod.example.com", Key: "prod-key"},
		},
		DefaultProfile: "prod",
	}

	// Set legacy env vars
	os.Setenv(EnvAPIURL, "https://override.example.com")
	os.Setenv(EnvAPIKey, "override-key")
	defer os.Unsetenv(EnvAPIURL)
	defer os.Unsetenv(EnvAPIKey)

	resolved, err := Resolve(cfg, "")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolved.URL != "https://override.example.com" {
		t.Errorf("URL = %q, want override URL", resolved.URL)
	}
	if resolved.Source != SourceLegacyEnv {
		t.Errorf("Source = %q, want %q", resolved.Source, SourceLegacyEnv)
	}
}

func TestResolve_ProfileFlag(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{
			"prod":    {URL: "https://prod.example.com", Key: "prod-key"},
			"staging": {URL: "https://staging.example.com", Key: "staging-key"},
		},
		DefaultProfile: "prod",
	}

	resolved, err := Resolve(cfg, "staging")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolved.Name != "staging" {
		t.Errorf("Name = %q, want staging", resolved.Name)
	}
	if resolved.URL != "https://staging.example.com" {
		t.Errorf("URL = %q, want staging URL", resolved.URL)
	}
	if resolved.Source != SourceFlag {
		t.Errorf("Source = %q, want %q", resolved.Source, SourceFlag)
	}
}

func TestResolve_ProfileFlagNotFound(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{
			"prod": {URL: "https://prod.example.com", Key: "prod-key"},
		},
	}

	_, err := Resolve(cfg, "nonexistent")
	if err == nil {
		t.Fatal("Resolve() expected error for nonexistent profile")
	}
}

func TestResolve_EnvVar(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{
			"prod":    {URL: "https://prod.example.com", Key: "prod-key"},
			"staging": {URL: "https://staging.example.com", Key: "staging-key"},
		},
		DefaultProfile: "prod",
	}

	os.Setenv(EnvProfile, "staging")
	defer os.Unsetenv(EnvProfile)

	resolved, err := Resolve(cfg, "")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolved.Name != "staging" {
		t.Errorf("Name = %q, want staging", resolved.Name)
	}
	if resolved.Source != SourceEnv {
		t.Errorf("Source = %q, want %q", resolved.Source, SourceEnv)
	}
}

func TestResolve_DefaultProfile(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{
			"prod":    {URL: "https://prod.example.com", Key: "prod-key"},
			"staging": {URL: "https://staging.example.com", Key: "staging-key"},
		},
		DefaultProfile: "prod",
	}

	// Clear any env vars that might interfere
	os.Unsetenv(EnvAPIURL)
	os.Unsetenv(EnvProfile)

	resolved, err := Resolve(cfg, "")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolved.Name != "prod" {
		t.Errorf("Name = %q, want prod", resolved.Name)
	}
	if resolved.Source != SourceConfig {
		t.Errorf("Source = %q, want %q", resolved.Source, SourceConfig)
	}
}

func TestResolve_LocalMode(t *testing.T) {
	cfg := &Config{
		Profiles: map[string]Profile{},
	}

	// Clear any env vars
	os.Unsetenv(EnvAPIURL)
	os.Unsetenv(EnvProfile)

	resolved, err := Resolve(cfg, "")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if !resolved.IsLocal() {
		t.Error("expected IsLocal() = true")
	}
	if resolved.Source != SourceLocal {
		t.Errorf("Source = %q, want %q", resolved.Source, SourceLocal)
	}
}

func TestMaskKey(t *testing.T) {
	tests := []struct {
		key  string
		want string
	}{
		{"", "(not set)"},
		{"abc", "****"},
		{"12345678", "****"},
		{"123456789", "1234...6789"},
		{"abcdefghijklmnop", "abcd...mnop"},
	}

	for _, tt := range tests {
		got := MaskKey(tt.key)
		if got != tt.want {
			t.Errorf("MaskKey(%q) = %q, want %q", tt.key, got, tt.want)
		}
	}
}

func TestResolvedProfile_IsLocal(t *testing.T) {
	local := &ResolvedProfile{Source: SourceLocal}
	if !local.IsLocal() {
		t.Error("expected IsLocal() = true for local profile")
	}

	remote := &ResolvedProfile{URL: "https://example.com", Source: SourceFlag}
	if remote.IsLocal() {
		t.Error("expected IsLocal() = false for remote profile")
	}
}
