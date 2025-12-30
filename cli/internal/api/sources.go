package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/cli/internal/models"
)

// SourceRequest represents the request body for creating/updating a source.
type SourceRequest struct {
	SourceType  string  `json:"source_type"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	Author      *string `json:"author,omitempty"`
	Year        *int    `json:"year,omitempty"`
	URL         *string `json:"url,omitempty"`
	ISBN        *string `json:"isbn,omitempty"`
	DOI         *string `json:"doi,omitempty"`
	Notes       *string `json:"notes,omitempty"`
	License     *string `json:"license,omitempty"`
	LicenseURL  *string `json:"license_url,omitempty"`
}

// validateSourceRequest validates a source request and returns validation errors.
func validateSourceRequest(req SourceRequest) []ValidationError {
	var errors []ValidationError

	if req.SourceType == "" {
		errors = append(errors, ValidationError{
			Field:   "source_type",
			Message: "source_type is required",
		})
	}

	if req.Name == "" {
		errors = append(errors, ValidationError{
			Field:   "name",
			Message: "name is required",
		})
	}

	return errors
}

// handleListSources handles GET /api/v1/sources
func (s *Server) handleListSources(w http.ResponseWriter, r *http.Request) {
	sources, err := s.db.ListSources()
	if err != nil {
		s.logger.Error("failed to list sources", "error", err)
		RespondInternalError(w, "Failed to retrieve sources")
		return
	}

	// Ensure we return an empty array rather than null
	if sources == nil {
		sources = []*models.Source{}
	}

	RespondJSON(w, http.StatusOK, sources)
}

// handleGetSource handles GET /api/v1/sources/{id}
func (s *Server) handleGetSource(w http.ResponseWriter, r *http.Request) {
	idParam := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "Invalid source ID")
		return
	}

	source, err := s.db.GetSource(id)
	if err != nil {
		s.logger.Error("failed to get source", "error", err, "id", id)
		RespondInternalError(w, "Failed to retrieve source")
		return
	}

	if source == nil {
		RespondNotFound(w, "Source", idParam)
		return
	}

	RespondJSON(w, http.StatusOK, source)
}

// handleCreateSource handles POST /api/v1/sources
func (s *Server) handleCreateSource(w http.ResponseWriter, r *http.Request) {
	var req SourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "Invalid JSON body")
		return
	}

	if errors := validateSourceRequest(req); len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	source := &models.Source{
		SourceType:  req.SourceType,
		Name:        req.Name,
		Description: req.Description,
		Author:      req.Author,
		Year:        req.Year,
		URL:         req.URL,
		ISBN:        req.ISBN,
		DOI:         req.DOI,
		Notes:       req.Notes,
		License:     req.License,
		LicenseURL:  req.LicenseURL,
	}

	id, err := s.db.InsertSource(source)
	if err != nil {
		s.logger.Error("failed to create source", "error", err)
		RespondInternalError(w, "Failed to create source")
		return
	}

	source.ID = id
	RespondJSON(w, http.StatusCreated, source)
}

// handleUpdateSource handles PUT /api/v1/sources/{id}
func (s *Server) handleUpdateSource(w http.ResponseWriter, r *http.Request) {
	idParam := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "Invalid source ID")
		return
	}

	// Check if source exists
	existing, err := s.db.GetSource(id)
	if err != nil {
		s.logger.Error("failed to get source for update", "error", err, "id", id)
		RespondInternalError(w, "Failed to retrieve source")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Source", idParam)
		return
	}

	var req SourceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "Invalid JSON body")
		return
	}

	if errors := validateSourceRequest(req); len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	source := &models.Source{
		ID:          id,
		SourceType:  req.SourceType,
		Name:        req.Name,
		Description: req.Description,
		Author:      req.Author,
		Year:        req.Year,
		URL:         req.URL,
		ISBN:        req.ISBN,
		DOI:         req.DOI,
		Notes:       req.Notes,
		License:     req.License,
		LicenseURL:  req.LicenseURL,
	}

	if err := s.db.UpdateSource(source); err != nil {
		s.logger.Error("failed to update source", "error", err, "id", id)
		RespondInternalError(w, "Failed to update source")
		return
	}

	RespondJSON(w, http.StatusOK, source)
}

// handleDeleteSource handles DELETE /api/v1/sources/{id}
func (s *Server) handleDeleteSource(w http.ResponseWriter, r *http.Request) {
	idParam := chi.URLParam(r, "id")
	id, err := strconv.ParseInt(idParam, 10, 64)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "Invalid source ID")
		return
	}

	// Check if source exists first
	existing, err := s.db.GetSource(id)
	if err != nil {
		s.logger.Error("failed to get source for delete", "error", err, "id", id)
		RespondInternalError(w, "Failed to retrieve source")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Source", idParam)
		return
	}

	if err := s.db.DeleteSource(id); err != nil {
		s.logger.Error("failed to delete source", "error", err, "id", id)
		RespondInternalError(w, "Failed to delete source")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
