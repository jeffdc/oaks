package api

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/cli/internal/models"
)

// TaxonRequest is the request body for creating or updating a taxon.
type TaxonRequest struct {
	Name   string             `json:"name"`
	Level  models.TaxonLevel  `json:"level"`
	Parent *string            `json:"parent,omitempty"`
	Author *string            `json:"author,omitempty"`
	Notes  *string            `json:"notes,omitempty"`
	Links  []models.TaxonLink `json:"links,omitempty"`
}

// TaxonResponse is the response for a single taxon.
type TaxonResponse struct {
	Name   string             `json:"name"`
	Level  models.TaxonLevel  `json:"level"`
	Parent *string            `json:"parent,omitempty"`
	Author *string            `json:"author,omitempty"`
	Notes  *string            `json:"notes,omitempty"`
	Links  []models.TaxonLink `json:"links,omitempty"`
}

// taxonToResponse converts a models.Taxon to TaxonResponse.
func taxonToResponse(t *models.Taxon) TaxonResponse {
	resp := TaxonResponse{
		Name:   t.Name,
		Level:  t.Level,
		Parent: t.Parent,
		Author: t.Author,
		Notes:  t.Notes,
	}
	if len(t.Links) > 0 {
		resp.Links = t.Links
	}
	return resp
}

// validTaxonLevels is the set of valid taxon levels.
var validTaxonLevels = map[models.TaxonLevel]bool{
	models.TaxonLevelSubgenus:   true,
	models.TaxonLevelSection:    true,
	models.TaxonLevelSubsection: true,
	models.TaxonLevelComplex:    true,
}

// parseTaxonLevel parses and validates a taxon level string.
func parseTaxonLevel(s string) (models.TaxonLevel, bool) {
	level := models.TaxonLevel(strings.ToLower(s))
	return level, validTaxonLevels[level]
}

// handleListTaxa handles GET /api/v1/taxa
func (s *Server) handleListTaxa(w http.ResponseWriter, r *http.Request) {
	// Check for optional level filter
	var levelPtr *models.TaxonLevel
	if levelParam := r.URL.Query().Get("level"); levelParam != "" {
		level, valid := parseTaxonLevel(levelParam)
		if !valid {
			RespondValidationError(w, []ValidationError{
				{Field: "level", Message: "must be one of: subgenus, section, subsection, complex"},
			})
			return
		}
		levelPtr = &level
	}

	taxa, err := s.db.ListTaxa(levelPtr)
	if err != nil {
		s.logger.Error("failed to list taxa", "error", err)
		RespondInternalError(w, "Failed to retrieve taxa")
		return
	}

	// Convert to response format
	data := make([]TaxonResponse, 0, len(taxa))
	for _, t := range taxa {
		data = append(data, taxonToResponse(t))
	}

	// Return paginated response (all results, no pagination needed for taxa)
	resp := NewListResponse(data, len(data), len(data), 0)
	RespondJSON(w, http.StatusOK, resp)
}

// handleGetTaxon handles GET /api/v1/taxa/{level}/{name}
func (s *Server) handleGetTaxon(w http.ResponseWriter, r *http.Request) {
	levelParam := chi.URLParam(r, "level")
	name := chi.URLParam(r, "name")

	level, valid := parseTaxonLevel(levelParam)
	if !valid {
		RespondValidationError(w, []ValidationError{
			{Field: "level", Message: "must be one of: subgenus, section, subsection, complex"},
		})
		return
	}

	taxon, err := s.db.GetTaxon(name, level)
	if err != nil {
		s.logger.Error("failed to get taxon", "error", err, "name", name, "level", level)
		RespondInternalError(w, "Failed to retrieve taxon")
		return
	}

	if taxon == nil {
		RespondNotFound(w, "Taxon", name+" ["+string(level)+"]")
		return
	}

	RespondJSON(w, http.StatusOK, taxonToResponse(taxon))
}

// handleCreateTaxon handles POST /api/v1/taxa
func (s *Server) handleCreateTaxon(w http.ResponseWriter, r *http.Request) {
	var req TaxonRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondValidationError(w, []ValidationError{
			{Field: "body", Message: "invalid JSON body"},
		})
		return
	}

	// Validate required fields
	var errors []ValidationError
	if req.Name == "" {
		errors = append(errors, ValidationError{Field: "name", Message: "is required"})
	}
	if req.Level == "" {
		errors = append(errors, ValidationError{Field: "level", Message: "is required"})
	} else if !validTaxonLevels[req.Level] {
		errors = append(errors, ValidationError{Field: "level", Message: "must be one of: subgenus, section, subsection, complex"})
	}
	if len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Check if taxon already exists
	existing, err := s.db.GetTaxon(req.Name, req.Level)
	if err != nil {
		s.logger.Error("failed to check for existing taxon", "error", err)
		RespondInternalError(w, "Failed to create taxon")
		return
	}
	if existing != nil {
		RespondConflict(w, "Taxon already exists: "+req.Name+" ["+string(req.Level)+"]")
		return
	}

	// Create the taxon
	taxon := &models.Taxon{
		Name:   req.Name,
		Level:  req.Level,
		Parent: req.Parent,
		Author: req.Author,
		Notes:  req.Notes,
		Links:  req.Links,
	}
	if taxon.Links == nil {
		taxon.Links = []models.TaxonLink{}
	}

	if err := s.db.InsertTaxon(taxon); err != nil {
		s.logger.Error("failed to insert taxon", "error", err)
		RespondInternalError(w, "Failed to create taxon")
		return
	}

	RespondJSON(w, http.StatusCreated, taxonToResponse(taxon))
}

// handleUpdateTaxon handles PUT /api/v1/taxa/{level}/{name}
func (s *Server) handleUpdateTaxon(w http.ResponseWriter, r *http.Request) {
	levelParam := chi.URLParam(r, "level")
	name := chi.URLParam(r, "name")

	level, valid := parseTaxonLevel(levelParam)
	if !valid {
		RespondValidationError(w, []ValidationError{
			{Field: "level", Message: "must be one of: subgenus, section, subsection, complex"},
		})
		return
	}

	// Check if taxon exists
	existing, err := s.db.GetTaxon(name, level)
	if err != nil {
		s.logger.Error("failed to get taxon", "error", err, "name", name, "level", level)
		RespondInternalError(w, "Failed to update taxon")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Taxon", name+" ["+string(level)+"]")
		return
	}

	// Parse request body
	var req TaxonRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondValidationError(w, []ValidationError{
			{Field: "body", Message: "invalid JSON body"},
		})
		return
	}

	// Update the taxon (name and level cannot be changed via PUT)
	existing.Parent = req.Parent
	existing.Author = req.Author
	existing.Notes = req.Notes
	if req.Links != nil {
		existing.Links = req.Links
	}

	if err := s.db.UpdateTaxon(existing); err != nil {
		s.logger.Error("failed to update taxon", "error", err)
		RespondInternalError(w, "Failed to update taxon")
		return
	}

	RespondJSON(w, http.StatusOK, taxonToResponse(existing))
}

// handleDeleteTaxon handles DELETE /api/v1/taxa/{level}/{name}
func (s *Server) handleDeleteTaxon(w http.ResponseWriter, r *http.Request) {
	levelParam := chi.URLParam(r, "level")
	name := chi.URLParam(r, "name")

	level, valid := parseTaxonLevel(levelParam)
	if !valid {
		RespondValidationError(w, []ValidationError{
			{Field: "level", Message: "must be one of: subgenus, section, subsection, complex"},
		})
		return
	}

	// Check if taxon exists before deleting
	existing, err := s.db.GetTaxon(name, level)
	if err != nil {
		s.logger.Error("failed to get taxon", "error", err, "name", name, "level", level)
		RespondInternalError(w, "Failed to delete taxon")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Taxon", name+" ["+string(level)+"]")
		return
	}

	if err := s.db.DeleteTaxon(name, level); err != nil {
		s.logger.Error("failed to delete taxon", "error", err)
		RespondInternalError(w, "Failed to delete taxon")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
