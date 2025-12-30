package cmd

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/spf13/cobra"

	"github.com/jeff/oaks/cli/internal/api"
)

var (
	servePort          int
	serveHost          string
	serveRegenerateKey bool
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Start the Oak Compendium API server",
	Long: `Start the Oak Compendium API server.

The server provides a REST API for querying oak species, taxa, and sources.
API key authentication is required for write operations; read operations are public.

Environment Variables:
  OAK_API_KEY   API key (overrides file at ~/.oak/api_key)
  OAK_DB_PATH   Database path (overrides --database flag)
  OAK_PORT      Port (overrides --port flag)

Examples:
  oak serve                      # Start on default port 8080
  oak serve --port 3000          # Start on port 3000
  oak serve --host 127.0.0.1     # Bind to localhost only
  oak serve --regenerate-key     # Generate new API key and exit`,
	RunE: runServe,
}

func init() {
	rootCmd.AddCommand(serveCmd)

	serveCmd.Flags().IntVarP(&servePort, "port", "p", 8080, "Port to listen on")
	serveCmd.Flags().StringVarP(&serveHost, "host", "H", "0.0.0.0", "Host to bind to")
	serveCmd.Flags().BoolVar(&serveRegenerateKey, "regenerate-key", false, "Generate new API key and exit")
}

func runServe(cmd *cobra.Command, args []string) error {
	// Apply environment variable overrides
	if envPort := os.Getenv("OAK_PORT"); envPort != "" {
		var p int
		if _, err := fmt.Sscanf(envPort, "%d", &p); err == nil {
			servePort = p
		}
	}

	if envDB := os.Getenv("OAK_DB_PATH"); envDB != "" {
		dbPath = envDB
	}

	// Handle --regenerate-key flag
	if serveRegenerateKey {
		key, err := api.GenerateAPIKey()
		if err != nil {
			return fmt.Errorf("failed to generate API key: %w", err)
		}

		if err := api.SaveAPIKey(api.DefaultAPIKeyPath, key); err != nil {
			return fmt.Errorf("failed to save API key: %w", err)
		}

		fmt.Fprintf(cmd.OutOrStdout(), "New API key generated and saved to %s\n", api.DefaultAPIKeyPath)
		fmt.Fprintf(cmd.OutOrStdout(), "API Key: %s\n", key)
		return nil
	}

	// Setup structured logger
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	// Load or generate API key
	apiKey, err := api.EnsureAPIKey(api.DefaultAPIKeyPath)
	if err != nil {
		return fmt.Errorf("failed to load API key: %w", err)
	}

	// Open database connection
	database, err := getDB()
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}
	defer database.Close()

	// Create server instance
	server := api.New(database, apiKey, logger)

	// Build address
	addr := fmt.Sprintf("%s:%d", serveHost, servePort)

	// Print startup banner
	fmt.Fprintln(cmd.OutOrStdout(), "Oak Compendium API server")
	fmt.Fprintf(cmd.OutOrStdout(), "Database: %s\n", dbPath)
	fmt.Fprintf(cmd.OutOrStdout(), "API Key:  %s\n", maskAPIKey(apiKey))
	fmt.Fprintf(cmd.OutOrStdout(), "Listening on http://%s\n", addr)

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
		return fmt.Errorf("server error: %w", err)
	case sig := <-sigChan:
		logger.Info("shutdown signal received", "signal", sig.String())
	}

	// Graceful shutdown with 30 second timeout
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	fmt.Fprintln(cmd.OutOrStdout(), "\nShutting down gracefully...")

	if err := server.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutdown error: %w", err)
	}

	fmt.Fprintln(cmd.OutOrStdout(), "Server stopped")
	return nil
}

// maskAPIKey returns a masked version of the API key for display.
// Shows only dots to indicate a key is present without revealing it.
func maskAPIKey(key string) string {
	if key == "" {
		return "(not set)"
	}
	// Return 24 dots regardless of key length (security through obscurity of length)
	return strings.Repeat("*", 24)
}
