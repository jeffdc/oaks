package handlers

import (
	"net/http"
)

// StatsResponse represents the stats endpoint response
type StatsResponse struct {
	SpeciesCount int `json:"species_count"`
	HybridCount  int `json:"hybrid_count"`
	TaxaCount    int `json:"taxa_count"`
	SourceCount  int `json:"source_count"`
}

// handleStats returns aggregate counts for the database
// GET /api/v1/stats
func (s *Server) handleStats(w http.ResponseWriter, r *http.Request) {
	stats, err := s.db.GetStats()
	if err != nil {
		RespondInternalError(w, "Failed to get stats")
		return
	}

	RespondJSON(w, http.StatusOK, StatsResponse{
		SpeciesCount: stats.SpeciesCount,
		HybridCount:  stats.HybridCount,
		TaxaCount:    stats.TaxaCount,
		SourceCount:  stats.SourceCount,
	})
}
