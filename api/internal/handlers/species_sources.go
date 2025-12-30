package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/api/internal/models"
)

// SpeciesSourceRequest represents the request body for creating/updating a species-source.
type SpeciesSourceRequest struct {
	SourceID         int64    `json:"source_id"`
	LocalNames       []string `json:"local_names,omitempty"`
	Range            *string  `json:"range,omitempty"`
	GrowthHabit      *string  `json:"growth_habit,omitempty"`
	Leaves           *string  `json:"leaves,omitempty"`
	Flowers          *string  `json:"flowers,omitempty"`
	Fruits           *string  `json:"fruits,omitempty"`
	Bark             *string  `json:"bark,omitempty"`
	Twigs            *string  `json:"twigs,omitempty"`
	Buds             *string  `json:"buds,omitempty"`
	HardinessHabitat *string  `json:"hardiness_habitat,omitempty"`
	Miscellaneous    *string  `json:"miscellaneous,omitempty"`
	URL              *string  `json:"url,omitempty"`
	IsPreferred      bool     `json:"is_preferred"`
}

// validateSpeciesSourceRequest validates a species-source request.
func validateSpeciesSourceRequest(req SpeciesSourceRequest) []ValidationError {
	var errors []ValidationError

	if req.SourceID <= 0 {
		errors = append(errors, ValidationError{
			Field:   "source_id",
			Message: "source_id must be a positive integer",
		})
	}

	return errors
}

// handleListSpeciesSources handles GET /api/v1/species/{name}/sources
func (s *Server) handleListSpeciesSources(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	sources, err := s.db.GetSpeciesSources(name)
	if err != nil {
		s.logger.Error("failed to get species sources", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}

	// Ensure we return an empty array rather than null
	if sources == nil {
		sources = []*models.SpeciesSource{}
	}

	RespondJSON(w, http.StatusOK, sources)
}

// handleGetSpeciesSource handles GET /api/v1/species/{name}/sources/{sourceId}
func (s *Server) handleGetSpeciesSource(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	sourceIDParam := chi.URLParam(r, "sourceId")
	sourceID, err := strconv.ParseInt(sourceIDParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid source ID")
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	speciesSource, err := s.db.GetSpeciesSourceBySourceID(name, sourceID)
	if err != nil {
		s.logger.Error("failed to get species source", "name", name, "sourceId", sourceID, "error", err)
		RespondInternalError(w, "")
		return
	}
	if speciesSource == nil {
		RespondNotFound(w, "SpeciesSource", sourceIDParam)
		return
	}

	RespondJSON(w, http.StatusOK, speciesSource)
}

// handleCreateSpeciesSource handles POST /api/v1/species/{name}/sources
func (s *Server) handleCreateSpeciesSource(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	var req SpeciesSourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid JSON body")
		return
	}

	if errors := validateSpeciesSourceRequest(req); len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	// Check if source exists
	source, err := s.db.GetSource(req.SourceID)
	if err != nil {
		s.logger.Error("failed to check source existence", "sourceId", req.SourceID, "error", err)
		RespondInternalError(w, "")
		return
	}
	if source == nil {
		RespondNotFound(w, "Source", strconv.FormatInt(req.SourceID, 10))
		return
	}

	// Check if species-source combination already exists
	existing, err := s.db.GetSpeciesSourceBySourceID(name, req.SourceID)
	if err != nil {
		s.logger.Error("failed to check existing species source", "name", name, "sourceId", req.SourceID, "error", err)
		RespondInternalError(w, "")
		return
	}
	if existing != nil {
		RespondConflict(w, "species-source combination already exists")
		return
	}

	speciesSource := requestToSpeciesSource(name, &req)
	if err := s.db.SaveSpeciesSource(speciesSource); err != nil {
		s.logger.Error("failed to create species source", "name", name, "sourceId", req.SourceID, "error", err)
		RespondInternalError(w, "")
		return
	}

	RespondJSON(w, http.StatusCreated, speciesSource)
}

// handleUpdateSpeciesSource handles PUT /api/v1/species/{name}/sources/{sourceId}
func (s *Server) handleUpdateSpeciesSource(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	sourceIDParam := chi.URLParam(r, "sourceId")
	sourceID, err := strconv.ParseInt(sourceIDParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid source ID")
		return
	}

	var req SpeciesSourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid JSON body")
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	// Get existing species-source record
	existing, err := s.db.GetSpeciesSourceBySourceID(name, sourceID)
	if err != nil {
		s.logger.Error("failed to get species source for update", "name", name, "sourceId", sourceID, "error", err)
		RespondInternalError(w, "")
		return
	}
	if existing == nil {
		RespondNotFound(w, "SpeciesSource", sourceIDParam)
		return
	}

	// Merge updates into existing record
	speciesSource := mergeSpeciesSource(existing, &req)
	if err := s.db.SaveSpeciesSource(speciesSource); err != nil {
		s.logger.Error("failed to update species source", "name", name, "sourceId", sourceID, "error", err)
		RespondInternalError(w, "")
		return
	}

	RespondJSON(w, http.StatusOK, speciesSource)
}

// handleDeleteSpeciesSource handles DELETE /api/v1/species/{name}/sources/{sourceId}
func (s *Server) handleDeleteSpeciesSource(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	sourceIDParam := chi.URLParam(r, "sourceId")
	sourceID, err := strconv.ParseInt(sourceIDParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid source ID")
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	// Check if species-source record exists
	existing, err := s.db.GetSpeciesSourceBySourceID(name, sourceID)
	if err != nil {
		s.logger.Error("failed to get species source for delete", "name", name, "sourceId", sourceID, "error", err)
		RespondInternalError(w, "")
		return
	}
	if existing == nil {
		RespondNotFound(w, "SpeciesSource", sourceIDParam)
		return
	}

	if err := s.db.DeleteSpeciesSource(name, sourceID); err != nil {
		s.logger.Error("failed to delete species source", "name", name, "sourceId", sourceID, "error", err)
		RespondInternalError(w, "")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// requestToSpeciesSource converts a request to a SpeciesSource model.
func requestToSpeciesSource(scientificName string, req *SpeciesSourceRequest) *models.SpeciesSource {
	ss := models.NewSpeciesSource(scientificName, req.SourceID)
	ss.Range = req.Range
	ss.GrowthHabit = req.GrowthHabit
	ss.Leaves = req.Leaves
	ss.Flowers = req.Flowers
	ss.Fruits = req.Fruits
	ss.Bark = req.Bark
	ss.Twigs = req.Twigs
	ss.Buds = req.Buds
	ss.HardinessHabitat = req.HardinessHabitat
	ss.Miscellaneous = req.Miscellaneous
	ss.URL = req.URL
	ss.IsPreferred = req.IsPreferred
	if req.LocalNames != nil {
		ss.LocalNames = req.LocalNames
	}
	return ss
}

// mergeSpeciesSource merges updates from a request into an existing SpeciesSource.
func mergeSpeciesSource(existing *models.SpeciesSource, req *SpeciesSourceRequest) *models.SpeciesSource {
	ss := *existing

	if req.LocalNames != nil {
		ss.LocalNames = req.LocalNames
	}
	if req.Range != nil {
		ss.Range = req.Range
	}
	if req.GrowthHabit != nil {
		ss.GrowthHabit = req.GrowthHabit
	}
	if req.Leaves != nil {
		ss.Leaves = req.Leaves
	}
	if req.Flowers != nil {
		ss.Flowers = req.Flowers
	}
	if req.Fruits != nil {
		ss.Fruits = req.Fruits
	}
	if req.Bark != nil {
		ss.Bark = req.Bark
	}
	if req.Twigs != nil {
		ss.Twigs = req.Twigs
	}
	if req.Buds != nil {
		ss.Buds = req.Buds
	}
	if req.HardinessHabitat != nil {
		ss.HardinessHabitat = req.HardinessHabitat
	}
	if req.Miscellaneous != nil {
		ss.Miscellaneous = req.Miscellaneous
	}
	if req.URL != nil {
		ss.URL = req.URL
	}
	ss.IsPreferred = req.IsPreferred

	return &ss
}
