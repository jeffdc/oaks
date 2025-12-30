package api

import (
	"encoding/json"
	"net/http"
)

// HealthResponse represents the response for liveness check
type HealthResponse struct {
	Status string `json:"status"`
}

// ReadyResponse represents the response for readiness check
type ReadyResponse struct {
	Status   string `json:"status"`
	Database string `json:"database"`
	Error    string `json:"error,omitempty"`
}

// handleHealth handles liveness check - immediate 200 if server is running
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(HealthResponse{Status: "ok"})
}

// handleHealthReady handles readiness check - verifies DB connection
func (s *Server) handleHealthReady(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Check if database is configured
	if s.db == nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		_ = json.NewEncoder(w).Encode(ReadyResponse{
			Status:   "unavailable",
			Database: "error",
			Error:    "database not configured",
		})
		return
	}

	// Verify database connection with ping
	if err := s.db.Ping(); err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		_ = json.NewEncoder(w).Encode(ReadyResponse{
			Status:   "unavailable",
			Database: "error",
			Error:    err.Error(),
		})
		return
	}

	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(ReadyResponse{
		Status:   "ready",
		Database: "connected",
	})
}
