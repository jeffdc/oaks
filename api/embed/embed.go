// Package embed provides an embeddable API server for the Oak Compendium.
// This package allows the CLI to run the API server in-process for local operations.
package embed

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"time"

	"github.com/jeff/oaks/api/internal/db"
	"github.com/jeff/oaks/api/internal/handlers"
)

// Server wraps an embedded API server for local CLI operations.
type Server struct {
	server     *handlers.Server
	httpServer *http.Server
	listener   net.Listener
	url        string
	apiKey     string
	logger     *slog.Logger
	errChan    chan error
}

// Config holds configuration for the embedded server.
type Config struct {
	// DBPath is the path to the SQLite database file.
	DBPath string

	// Quiet suppresses server startup/shutdown messages.
	Quiet bool
}

// Start creates and starts an embedded API server on a random localhost port.
// Returns the server instance which provides the URL and API key for connecting.
func Start(cfg Config) (*Server, error) {
	// Generate a session-specific API key
	apiKey, err := generateSessionKey()
	if err != nil {
		return nil, fmt.Errorf("failed to generate session key: %w", err)
	}

	// Create a discarding logger for quiet embedded operation
	var logger *slog.Logger
	if cfg.Quiet {
		logger = slog.New(slog.NewTextHandler(io.Discard, nil))
	} else {
		logger = slog.Default()
	}

	// Open database connection
	database, err := db.New(cfg.DBPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Create server with embedded-friendly configuration
	versionInfo := handlers.VersionInfo{
		API:       "embedded",
		MinClient: "1.0.0",
	}

	// Use minimal middleware for embedded mode (skip rate limiting, logging, etc.)
	server := handlers.New(database, apiKey, logger, versionInfo, handlers.WithoutMiddleware())

	// Listen on a random localhost port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		database.Close()
		return nil, fmt.Errorf("failed to listen on localhost: %w", err)
	}

	addr := listener.Addr().(*net.TCPAddr)
	url := fmt.Sprintf("http://127.0.0.1:%d", addr.Port)

	embedded := &Server{
		server:   server,
		listener: listener,
		url:      url,
		apiKey:   apiKey,
		logger:   logger,
		errChan:  make(chan error, 1),
	}

	// Create HTTP server
	embedded.httpServer = &http.Server{
		Handler:      server.Router(),
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start serving in background
	go func() {
		if err := embedded.httpServer.Serve(listener); err != nil && err != http.ErrServerClosed {
			embedded.errChan <- err
		}
	}()

	// Wait briefly to ensure server is accepting connections
	if err := embedded.waitForReady(); err != nil {
		embedded.Shutdown()
		return nil, fmt.Errorf("embedded server failed to start: %w", err)
	}

	return embedded, nil
}

// URL returns the localhost URL for connecting to the embedded server.
func (s *Server) URL() string {
	return s.url
}

// APIKey returns the session-specific API key for authentication.
func (s *Server) APIKey() string {
	return s.apiKey
}

// Shutdown gracefully shuts down the embedded server.
func (s *Server) Shutdown() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Shutdown the HTTP server
	if s.httpServer != nil {
		if err := s.httpServer.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to shutdown embedded server: %w", err)
		}
	}

	// Shutdown the handlers server (closes database)
	if err := s.server.Shutdown(ctx); err != nil {
		return fmt.Errorf("failed to shutdown handler server: %w", err)
	}

	return nil
}

// waitForReady polls the health endpoint until the server is ready.
func (s *Server) waitForReady() error {
	client := &http.Client{Timeout: time.Second}

	for i := 0; i < 50; i++ { // 50 * 10ms = 500ms max wait
		resp, err := client.Get(s.url + "/health")
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode == http.StatusOK {
				return nil
			}
		}
		time.Sleep(10 * time.Millisecond)
	}

	// Check if server failed to start
	select {
	case err := <-s.errChan:
		return err
	default:
		return fmt.Errorf("timeout waiting for server to become ready")
	}
}

// generateSessionKey generates a random API key for this session.
func generateSessionKey() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(bytes), nil
}
