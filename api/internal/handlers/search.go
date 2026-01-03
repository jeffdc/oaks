package handlers

import (
	"net/http"
	"strconv"
)

// handleUnifiedSearch handles GET /api/v1/search?q=
// Searches across species, taxa, and sources
func (s *Server) handleUnifiedSearch(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "query parameter 'q' is required")
		return
	}

	// Limit search results per category
	limit := defaultLimit
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= maxLimit {
			limit = parsed
		}
	}

	results, err := s.db.UnifiedSearch(query, limit)
	if err != nil {
		s.logger.Error("failed to perform unified search", "query", query, "error", err)
		RespondInternalError(w, "")
		return
	}

	RespondJSON(w, http.StatusOK, results)
}
