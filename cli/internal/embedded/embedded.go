// Package embedded provides a wrapper around the API's embed package
// for use in the CLI. This allows the CLI to use the same HTTP-based
// API client for both local and remote operations.
package embedded

import (
	"github.com/jeff/oaks/api/embed"
)

// Server wraps the API's embedded server.
type Server = embed.Server

// Config is an alias for the API's embedded config.
type Config = embed.Config

// Start creates and starts an embedded API server on a random localhost port.
// This is a convenience wrapper around embed.Start.
func Start(cfg Config) (*Server, error) {
	return embed.Start(cfg)
}
