// Package main provides the Oak Compendium API server.
//
// This is a standalone binary that provides REST API access to the oak species database.
// All configuration is done via environment variables for container compatibility.
//
// Environment Variables:
//
//	OAK_DB_PATH   - Database path (default: ./oak_compendium.db)
//	OAK_PORT      - Port to listen on (default: 8080)
//	OAK_API_KEY   - API key (or reads from ~/.oak/api_key)
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/jeff/oaks/api/internal/db"
	"github.com/jeff/oaks/api/internal/handlers"
)

// Version information set at build time.
var (
	Version   = "dev"
	GitCommit = "unknown"
	BuildDate = "unknown"
)

func main() {
	// Parse command line flags
	generateKey := flag.Bool("generate-key", false, "Generate a new API key and exit")
	showVersion := flag.Bool("version", false, "Show version information and exit")
	flag.Parse()

	// Handle version flag
	if *showVersion {
		fmt.Printf("oak-api %s (commit: %s, built: %s)\n", Version, GitCommit, BuildDate)
		os.Exit(0)
	}

	// Handle generate-key flag
	if *generateKey {
		key, err := handlers.GenerateAPIKey()
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: failed to generate API key: %v\n", err)
			os.Exit(1)
		}

		if err := handlers.SaveAPIKey(handlers.DefaultAPIKeyPath, key); err != nil {
			fmt.Fprintf(os.Stderr, "Error: failed to save API key: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("New API key generated and saved to %s\n", handlers.DefaultAPIKeyPath)
		fmt.Printf("API Key: %s\n", key)
		os.Exit(0)
	}

	// Setup structured logger
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Get configuration from environment
	dbPath := getEnv("OAK_DB_PATH", "./oak_compendium.db")
	port := getEnv("OAK_PORT", "8080")

	// Load or generate API key
	apiKey, err := handlers.EnsureAPIKey(handlers.DefaultAPIKeyPath)
	if err != nil {
		logger.Error("failed to load API key", "error", err)
		os.Exit(1)
	}

	// Open database connection
	database, err := db.New(dbPath)
	if err != nil {
		logger.Error("failed to open database", "error", err, "path", dbPath)
		os.Exit(1)
	}
	defer database.Close()

	// Create server instance with version info
	versionInfo := handlers.VersionInfo{
		API:       Version,
		MinClient: "1.0.0", // Minimum compatible CLI version
	}
	server := handlers.New(database, apiKey, logger, versionInfo)

	// Build address
	addr := fmt.Sprintf("0.0.0.0:%s", port)

	// Print startup banner
	fmt.Println("Oak Compendium API server")
	fmt.Printf("Version:  %s\n", Version)
	fmt.Printf("Database: %s\n", dbPath)
	fmt.Printf("API Key:  %s\n", maskAPIKey(apiKey))
	fmt.Printf("Listening on http://%s\n", addr)

	// Setup signal handlers for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start server in goroutine
	errChan := make(chan error, 1)
	go func() {
		if err := server.Start(addr); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errChan <- err
		}
	}()

	// Wait for signal or error
	select {
	case err := <-errChan:
		logger.Error("server error", "error", err)
		os.Exit(1)
	case sig := <-sigChan:
		logger.Info("shutdown signal received", "signal", sig.String())
	}

	// Graceful shutdown with 30 second timeout
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	fmt.Println("\nShutting down gracefully...")

	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown error", "error", err)
		os.Exit(1)
	}

	fmt.Println("Server stopped")
}

// getEnv returns the value of an environment variable or a default value.
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// maskAPIKey returns a masked version of the API key for display.
func maskAPIKey(key string) string {
	if key == "" {
		return "(not set)"
	}
	return strings.Repeat("*", 24)
}
