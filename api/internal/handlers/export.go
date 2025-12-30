package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"time"

	"github.com/jeff/oaks/api/internal/export"
)

// handleExport handles GET /api/v1/export
// Returns the full database export as JSON.
func (s *Server) handleExport(w http.ResponseWriter, r *http.Request) {
	// Build export data
	exportData, err := export.Build(s.db)
	if err != nil {
		s.logger.Error("failed to build export", "error", err)
		RespondInternalError(w, "")
		return
	}

	// Marshal to JSON
	jsonData, err := json.Marshal(exportData)
	if err != nil {
		s.logger.Error("failed to marshal export JSON", "error", err)
		RespondInternalError(w, "")
		return
	}

	// Generate ETag from content hash
	hash := sha256.Sum256(jsonData)
	etag := `"` + hex.EncodeToString(hash[:16]) + `"`

	// Check If-None-Match header for caching
	if match := r.Header.Get("If-None-Match"); match == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}

	// Set response headers
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("ETag", etag)
	w.Header().Set("Last-Modified", time.Now().UTC().Format(http.TimeFormat))
	w.Header().Set("Cache-Control", "public, max-age=300") // 5 minute cache

	w.WriteHeader(http.StatusOK)
	if _, err := w.Write(jsonData); err != nil {
		s.logger.Error("failed to write export response", "error", err)
	}
}
