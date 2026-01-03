package handlers

import (
	"encoding/json"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/api/internal/db"
	"github.com/jeff/oaks/api/internal/models"
)

// SpeciesListParams contains query parameters for species list endpoint
type SpeciesListParams struct {
	Limit      int
	Offset     int
	Subgenus   *string
	Section    *string
	Subsection *string
	Complex    *string
	Hybrid     *bool
	SourceID   *int64
}

// SpeciesRequest represents the request body for creating/updating a species
type SpeciesRequest struct {
	ScientificName       string   `json:"scientific_name"`
	Author               *string  `json:"author,omitempty"`
	IsHybrid             bool     `json:"is_hybrid"`
	ConservationStatus   *string  `json:"conservation_status,omitempty"`
	Subgenus             *string  `json:"subgenus,omitempty"`
	Section              *string  `json:"section,omitempty"`
	Subsection           *string  `json:"subsection,omitempty"`
	Complex              *string  `json:"complex,omitempty"`
	Parent1              *string  `json:"parent1,omitempty"`
	Parent2              *string  `json:"parent2,omitempty"`
	Hybrids              []string `json:"hybrids,omitempty"`
	CloselyRelatedTo     []string `json:"closely_related_to,omitempty"`
	SubspeciesVarieties  []string `json:"subspecies_varieties,omitempty"`
	Synonyms             []string `json:"synonyms,omitempty"`
}

const (
	defaultLimit = 50
	maxLimit     = 500
)

// Valid subgenera for validation
var validSubgenera = map[string]bool{
	"Quercus":         true,
	"Cerris":          true,
	"Cyclobalanopsis": true,
}

// Valid IUCN conservation status codes
var validConservationStatus = map[string]bool{
	"EX": true, // Extinct
	"EW": true, // Extinct in the Wild
	"CR": true, // Critically Endangered
	"EN": true, // Endangered
	"VU": true, // Vulnerable
	"NT": true, // Near Threatened
	"LC": true, // Least Concern
	"DD": true, // Data Deficient
	"NE": true, // Not Evaluated
}

// parseSpeciesListParams extracts and validates query parameters for list endpoint
func parseSpeciesListParams(query url.Values) (*SpeciesListParams, []ValidationError) {
	params := &SpeciesListParams{
		Limit:  defaultLimit,
		Offset: 0,
	}
	var errors []ValidationError

	// Parse limit
	if limitStr := query.Get("limit"); limitStr != "" {
		limit, err := strconv.Atoi(limitStr)
		if err != nil || limit < 1 {
			errors = append(errors, ValidationError{
				Field:   "limit",
				Message: "must be a positive integer",
			})
		} else if limit > maxLimit {
			params.Limit = maxLimit
		} else {
			params.Limit = limit
		}
	}

	// Parse offset
	if offsetStr := query.Get("offset"); offsetStr != "" {
		offset, err := strconv.Atoi(offsetStr)
		if err != nil || offset < 0 {
			errors = append(errors, ValidationError{
				Field:   "offset",
				Message: "must be a non-negative integer",
			})
		} else {
			params.Offset = offset
		}
	}

	// Parse subgenus filter
	if subgenus := query.Get("subgenus"); subgenus != "" {
		params.Subgenus = &subgenus
	}

	// Parse section filter
	if section := query.Get("section"); section != "" {
		params.Section = &section
	}

	// Parse subsection filter
	if subsection := query.Get("subsection"); subsection != "" {
		params.Subsection = &subsection
	}

	// Parse complex filter
	if complex := query.Get("complex"); complex != "" {
		params.Complex = &complex
	}

	// Parse hybrid filter
	if hybridStr := query.Get("hybrid"); hybridStr != "" {
		hybrid := strings.ToLower(hybridStr) == "true"
		params.Hybrid = &hybrid
	}

	// Parse source_id filter
	if sourceIDStr := query.Get("source_id"); sourceIDStr != "" {
		sourceID, err := strconv.ParseInt(sourceIDStr, 10, 64)
		if err != nil || sourceID < 1 {
			errors = append(errors, ValidationError{
				Field:   "source_id",
				Message: "must be a positive integer",
			})
		} else {
			params.SourceID = &sourceID
		}
	}

	return params, errors
}

// validateSpeciesRequest validates a species create/update request
func validateSpeciesRequest(req *SpeciesRequest, isCreate bool) []ValidationError {
	var errors []ValidationError

	// Validate scientific_name
	if isCreate {
		if req.ScientificName == "" {
			errors = append(errors, ValidationError{
				Field:   "scientific_name",
				Message: "is required",
			})
		} else if len(req.ScientificName) < 2 || len(req.ScientificName) > 100 {
			errors = append(errors, ValidationError{
				Field:   "scientific_name",
				Message: "must be between 2 and 100 characters",
			})
		}
	}

	// Validate subgenus if provided
	if req.Subgenus != nil && *req.Subgenus != "" {
		if !validSubgenera[*req.Subgenus] {
			errors = append(errors, ValidationError{
				Field:   "subgenus",
				Message: "must be one of: Quercus, Cerris, Cyclobalanopsis",
			})
		}
	}

	// Validate conservation_status if provided
	if req.ConservationStatus != nil && *req.ConservationStatus != "" {
		if !validConservationStatus[*req.ConservationStatus] {
			errors = append(errors, ValidationError{
				Field:   "conservation_status",
				Message: "must be a valid IUCN code (EX, EW, CR, EN, VU, NT, LC, DD, NE)",
			})
		}
	}

	return errors
}

// handleListSpecies handles GET /api/v1/species
func (s *Server) handleListSpecies(w http.ResponseWriter, r *http.Request) {
	params, validationErrors := parseSpeciesListParams(r.URL.Query())
	if len(validationErrors) > 0 {
		RespondValidationError(w, validationErrors)
		return
	}

	filter := &db.OakEntryFilter{
		Subgenus:   params.Subgenus,
		Section:    params.Section,
		Subsection: params.Subsection,
		Complex:    params.Complex,
		Hybrid:     params.Hybrid,
		SourceID:   params.SourceID,
	}

	// Get total count
	total, err := s.db.CountOakEntries(filter)
	if err != nil {
		s.logger.Error("failed to count species", "error", err)
		RespondInternalError(w, "")
		return
	}

	// Get paginated entries
	entries, err := s.db.ListOakEntriesPaginated(params.Limit, params.Offset, filter)
	if err != nil {
		s.logger.Error("failed to list species", "error", err)
		RespondInternalError(w, "")
		return
	}

	// Ensure we never return nil
	if entries == nil {
		entries = []*models.OakEntry{}
	}

	resp := NewListResponse(entries, total, params.Limit, params.Offset)
	RespondJSON(w, http.StatusOK, resp)
}

// handleGetSpecies handles GET /api/v1/species/{name}
func (s *Server) handleGetSpecies(w http.ResponseWriter, r *http.Request) {
	nameEncoded := chi.URLParam(r, "name")
	if nameEncoded == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}
	name, err := url.PathUnescape(nameEncoded)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid species name encoding")
		return
	}

	entry, err := s.db.GetOakEntry(name)
	if err != nil {
		s.logger.Error("failed to get species", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}

	if entry == nil {
		RespondNotFound(w, "Species", name)
		return
	}

	RespondJSON(w, http.StatusOK, entry)
}

// handleGetSpeciesFull handles GET /api/v1/species/{name}/full
// Returns species with all source data embedded, including source metadata
func (s *Server) handleGetSpeciesFull(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "name")
	if name == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}

	entry, err := s.db.GetOakEntryWithSources(name)
	if err != nil {
		s.logger.Error("failed to get full species", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}

	if entry == nil {
		RespondNotFound(w, "Species", name)
		return
	}

	RespondJSON(w, http.StatusOK, entry)
}

// handleSearchSpecies handles GET /api/v1/species/search?q=
func (s *Server) handleSearchSpecies(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "query parameter 'q' is required")
		return
	}

	// Limit search results
	limit := defaultLimit
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 && parsed <= maxLimit {
			limit = parsed
		}
	}

	entries, err := s.db.SearchOakEntriesFull(query, limit)
	if err != nil {
		s.logger.Error("failed to search species", "query", query, "error", err)
		RespondInternalError(w, "")
		return
	}

	if entries == nil {
		entries = []*models.OakEntry{}
	}

	RespondJSON(w, http.StatusOK, map[string]interface{}{
		"data":  entries,
		"query": query,
		"count": len(entries),
	})
}

// handleCreateSpecies handles POST /api/v1/species
func (s *Server) handleCreateSpecies(w http.ResponseWriter, r *http.Request) {
	var req SpeciesRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid JSON body")
		return
	}

	// Validate request
	if errors := validateSpeciesRequest(&req, true); len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Check if species already exists
	exists, err := s.db.OakEntryExists(req.ScientificName)
	if err != nil {
		s.logger.Error("failed to check species existence", "name", req.ScientificName, "error", err)
		RespondInternalError(w, "")
		return
	}
	if exists {
		RespondConflict(w, "species already exists: "+req.ScientificName)
		return
	}

	// Create the entry
	entry := requestToOakEntry(&req)
	if err := s.db.SaveOakEntry(entry); err != nil {
		s.logger.Error("failed to create species", "name", req.ScientificName, "error", err)
		RespondInternalError(w, "")
		return
	}

	RespondJSON(w, http.StatusCreated, entry)
}

// handleUpdateSpecies handles PUT /api/v1/species/{name}
func (s *Server) handleUpdateSpecies(w http.ResponseWriter, r *http.Request) {
	nameEncoded := chi.URLParam(r, "name")
	if nameEncoded == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}
	name, err := url.PathUnescape(nameEncoded)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid species name encoding")
		return
	}

	var req SpeciesRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid JSON body")
		return
	}

	// Validate request (not a create)
	if errors := validateSpeciesRequest(&req, false); len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Get existing entry
	existing, err := s.db.GetOakEntry(name)
	if err != nil {
		s.logger.Error("failed to get species for update", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Species", name)
		return
	}

	// Merge updates into existing entry
	entry := mergeOakEntry(existing, &req)
	if err := s.db.SaveOakEntry(entry); err != nil {
		s.logger.Error("failed to update species", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}

	RespondJSON(w, http.StatusOK, entry)
}

// handleDeleteSpecies handles DELETE /api/v1/species/{name}
func (s *Server) handleDeleteSpecies(w http.ResponseWriter, r *http.Request) {
	nameEncoded := chi.URLParam(r, "name")
	if nameEncoded == "" {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "species name is required")
		return
	}
	name, err := url.PathUnescape(nameEncoded)
	if err != nil {
		RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid species name encoding")
		return
	}

	// Check if species exists
	exists, err := s.db.OakEntryExists(name)
	if err != nil {
		s.logger.Error("failed to check species existence for delete", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if !exists {
		RespondNotFound(w, "Species", name)
		return
	}

	// Check for hybrids referencing this species as a parent (cascade protection)
	blockingHybrids, err := s.db.GetHybridsReferencingParent(name)
	if err != nil {
		s.logger.Error("failed to check hybrid references for delete", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}
	if len(blockingHybrids) > 0 {
		RespondCascadeConflict(w, blockingHybrids)
		return
	}

	// Delete the entry (cascades to species_sources via ON DELETE CASCADE)
	if err := s.db.DeleteOakEntry(name); err != nil {
		s.logger.Error("failed to delete species", "name", name, "error", err)
		RespondInternalError(w, "")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// requestToOakEntry converts a SpeciesRequest to an OakEntry
func requestToOakEntry(req *SpeciesRequest) *models.OakEntry {
	entry := models.NewOakEntry(req.ScientificName)
	entry.Author = req.Author
	entry.IsHybrid = req.IsHybrid
	entry.ConservationStatus = req.ConservationStatus
	entry.Subgenus = req.Subgenus
	entry.Section = req.Section
	entry.Subsection = req.Subsection
	entry.Complex = req.Complex
	entry.Parent1 = req.Parent1
	entry.Parent2 = req.Parent2
	if req.Hybrids != nil {
		entry.Hybrids = req.Hybrids
	}
	if req.CloselyRelatedTo != nil {
		entry.CloselyRelatedTo = req.CloselyRelatedTo
	}
	if req.SubspeciesVarieties != nil {
		entry.SubspeciesVarieties = req.SubspeciesVarieties
	}
	if req.Synonyms != nil {
		entry.Synonyms = req.Synonyms
	}
	return entry
}

// mergeOakEntry merges updates from a request into an existing entry
func mergeOakEntry(existing *models.OakEntry, req *SpeciesRequest) *models.OakEntry {
	// Start with the existing entry
	entry := *existing

	// Update fields if provided in request
	if req.Author != nil {
		entry.Author = req.Author
	}
	entry.IsHybrid = req.IsHybrid
	if req.ConservationStatus != nil {
		entry.ConservationStatus = req.ConservationStatus
	}
	if req.Subgenus != nil {
		entry.Subgenus = req.Subgenus
	}
	if req.Section != nil {
		entry.Section = req.Section
	}
	if req.Subsection != nil {
		entry.Subsection = req.Subsection
	}
	if req.Complex != nil {
		entry.Complex = req.Complex
	}
	if req.Parent1 != nil {
		entry.Parent1 = req.Parent1
	}
	if req.Parent2 != nil {
		entry.Parent2 = req.Parent2
	}
	if req.Hybrids != nil {
		entry.Hybrids = req.Hybrids
	}
	if req.CloselyRelatedTo != nil {
		entry.CloselyRelatedTo = req.CloselyRelatedTo
	}
	if req.SubspeciesVarieties != nil {
		entry.SubspeciesVarieties = req.SubspeciesVarieties
	}
	if req.Synonyms != nil {
		entry.Synonyms = req.Synonyms
	}

	return &entry
}
