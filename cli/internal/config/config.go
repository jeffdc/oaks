// Package config provides profile-based configuration for the Oak CLI.
// It supports named API profiles for connecting to different servers
// (production, staging, local) with automatic resolution based on
// flags, environment variables, and config file settings.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Profile represents a named API configuration.
type Profile struct {
	URL string `yaml:"url"`
	Key string `yaml:"key"`
}

// Config represents the CLI configuration file structure.
type Config struct {
	Profiles       map[string]Profile `yaml:"profiles"`
	DefaultProfile string             `yaml:"default_profile"`
}

// ResolvedProfile contains the active profile after resolution.
type ResolvedProfile struct {
	Name   string // Profile name (empty if local mode)
	URL    string // API URL
	Key    string // API key
	Source string // Where the profile came from: "flag", "env", "config", "legacy-env", "local"
}

// IsLocal returns true if operating in local database mode.
func (r *ResolvedProfile) IsLocal() bool {
	return r.URL == ""
}

// Resolution sources
const (
	SourceFlag      = "flag"
	SourceEnv       = "env"
	SourceConfig    = "config"
	SourceLegacyEnv = "legacy-env"
	SourceLocal     = "local"
)

// Environment variable names
const (
	EnvProfile = "OAK_PROFILE"
	EnvAPIURL  = "OAK_API_URL"
	EnvAPIKey  = "OAK_API_KEY" //nolint:gosec // This is an env var name, not a credential
)

// DefaultConfigPath returns the default configuration file path.
func DefaultConfigPath() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, ".oak", "config.yaml")
}

// Load reads the configuration from the specified path.
// Returns an empty config (not an error) if the file doesn't exist.
func Load(path string) (*Config, error) {
	if path == "" {
		path = DefaultConfigPath()
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			// No config file is valid - return empty config
			return &Config{Profiles: make(map[string]Profile)}, nil
		}
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	if cfg.Profiles == nil {
		cfg.Profiles = make(map[string]Profile)
	}

	return &cfg, nil
}

// Resolve determines the active profile based on resolution order:
// 1. OAK_API_URL + OAK_API_KEY env vars (legacy, overrides all)
// 2. --profile flag (passed as profileFlag parameter)
// 3. OAK_PROFILE env var
// 4. default_profile from config file
// 5. No profile -> local database mode (safe default)
func Resolve(cfg *Config, profileFlag string) (*ResolvedProfile, error) {
	// 1. Legacy env vars override everything
	if url := os.Getenv(EnvAPIURL); url != "" {
		return &ResolvedProfile{
			Name:   "legacy-env",
			URL:    url,
			Key:    os.Getenv(EnvAPIKey),
			Source: SourceLegacyEnv,
		}, nil
	}

	// 2. --profile flag
	if profileFlag != "" {
		profile, ok := cfg.Profiles[profileFlag]
		if !ok {
			return nil, fmt.Errorf("profile %q not found in config", profileFlag)
		}
		return &ResolvedProfile{
			Name:   profileFlag,
			URL:    profile.URL,
			Key:    profile.Key,
			Source: SourceFlag,
		}, nil
	}

	// 3. OAK_PROFILE env var
	if envProfile := os.Getenv(EnvProfile); envProfile != "" {
		profile, ok := cfg.Profiles[envProfile]
		if !ok {
			return nil, fmt.Errorf("profile %q (from %s) not found in config", envProfile, EnvProfile)
		}
		return &ResolvedProfile{
			Name:   envProfile,
			URL:    profile.URL,
			Key:    profile.Key,
			Source: SourceEnv,
		}, nil
	}

	// 4. default_profile from config
	if cfg.DefaultProfile != "" {
		profile, ok := cfg.Profiles[cfg.DefaultProfile]
		if !ok {
			return nil, fmt.Errorf("default profile %q not found in config", cfg.DefaultProfile)
		}
		return &ResolvedProfile{
			Name:   cfg.DefaultProfile,
			URL:    profile.URL,
			Key:    profile.Key,
			Source: SourceConfig,
		}, nil
	}

	// 5. No profile -> local database mode
	return &ResolvedProfile{
		Source: SourceLocal,
	}, nil
}

// ProfileNames returns a sorted list of all profile names in the config.
func (c *Config) ProfileNames() []string {
	names := make([]string, 0, len(c.Profiles))
	for name := range c.Profiles {
		names = append(names, name)
	}
	return names
}

// MaskKey returns a masked version of an API key for display.
// Shows first 4 and last 4 characters if long enough, otherwise all asterisks.
func MaskKey(key string) string {
	if key == "" {
		return "(not set)"
	}
	if len(key) <= 8 {
		return "****"
	}
	return key[:4] + "..." + key[len(key)-4:]
}
