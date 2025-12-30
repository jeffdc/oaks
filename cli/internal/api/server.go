package api

import (
	"context"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/cli/internal/db"
)

// Server is the API server for the Oak Compendium.
type Server struct {
	router           chi.Router
	db               *db.Database
	httpServer       *http.Server
	apiKey           string
	logger           *slog.Logger
	middlewareConfig *MiddlewareConfig
	skipMiddleware   bool
}

// ServerOption is a functional option for configuring the server.
type ServerOption func(*Server)

// WithMiddlewareConfig sets a custom middleware configuration.
func WithMiddlewareConfig(config MiddlewareConfig) ServerOption {
	return func(s *Server) {
		s.middlewareConfig = &config
	}
}

// WithoutMiddleware disables middleware (useful for testing).
func WithoutMiddleware() ServerOption {
	return func(s *Server) {
		s.skipMiddleware = true
	}
}

// New creates a new API server with the given database, API key, and logger.
func New(database *db.Database, apiKey string, logger *slog.Logger, opts ...ServerOption) *Server {
	if logger == nil {
		logger = slog.Default()
	}

	s := &Server{
		router: chi.NewRouter(),
		db:     database,
		apiKey: apiKey,
		logger: logger,
	}

	// Apply options
	for _, opt := range opts {
		opt(s)
	}

	s.setupRoutes()
	return s
}

// setupRoutes configures all routes for the server.
func (s *Server) setupRoutes() {
	r := s.router

	// Apply middleware unless disabled (e.g., for testing)
	if !s.skipMiddleware {
		config := s.middlewareConfig
		if config == nil {
			defaultConfig := DefaultMiddlewareConfig(s.logger)
			config = &defaultConfig
		}
		s.SetupMiddleware(*config)
	}

	// Health check endpoints (no auth, rate limiting exempt via middleware)
	r.Get("/health", s.handleHealth)
	r.Get("/health/ready", s.handleHealthReady)

	// API v1 routes
	r.Route("/api/v1", func(r chi.Router) {
		// Species endpoints
		r.Get("/species", s.handleListSpecies)
		r.Get("/species/{name}", s.handleGetSpecies)

		// Taxa endpoints
		r.Get("/taxa", s.handleListTaxa)
		r.Get("/taxa/{level}/{name}", s.handleGetTaxon)

		// Sources endpoints
		r.Get("/sources", s.handleListSources)
		r.Get("/sources/{id}", s.handleGetSource)

		// Species-sources endpoints
		r.Get("/species/{name}/sources", s.handleGetSpeciesSources)

		// Export endpoint
		r.Get("/export", s.handleExport)
	})
}

// Start starts the HTTP server on the given address.
func (s *Server) Start(addr string) error {
	s.httpServer = &http.Server{
		Addr:         addr,
		Handler:      s.router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	s.logger.Info("starting API server", "addr", addr)
	return s.httpServer.ListenAndServe()
}

// Shutdown gracefully shuts down the server with the given context.
func (s *Server) Shutdown(ctx context.Context) error {
	s.logger.Info("shutting down API server")
	if s.httpServer == nil {
		return nil
	}
	return s.httpServer.Shutdown(ctx)
}

// Router returns the chi router for testing purposes.
func (s *Server) Router() chi.Router {
	return s.router
}

// Placeholder handlers - will be implemented in endpoint tasks

func (s *Server) handleListSpecies(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleGetSpecies(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleListTaxa(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleGetTaxon(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleListSources(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleGetSource(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleGetSpeciesSources(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (s *Server) handleExport(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
