package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
)

// Pagination contains pagination metadata for list responses.
type Pagination struct {
	Total   int  `json:"total"`
	Limit   int  `json:"limit"`
	Offset  int  `json:"offset"`
	HasMore bool `json:"hasMore"`
}

// ListResponse is a generic response type for paginated list endpoints.
type ListResponse[T any] struct {
	Data       []T        `json:"data"`
	Pagination Pagination `json:"pagination"`
}

// NewListResponse creates a new ListResponse with the given data and pagination.
func NewListResponse[T any](data []T, total, limit, offset int) ListResponse[T] {
	hasMore := offset+len(data) < total
	return ListResponse[T]{
		Data: data,
		Pagination: Pagination{
			Total:   total,
			Limit:   limit,
			Offset:  offset,
			HasMore: hasMore,
		},
	}
}

// RespondJSON writes a JSON response with the given status code and data.
func RespondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)

	if data != nil {
		if err := json.NewEncoder(w).Encode(data); err != nil {
			// Log error but response headers are already sent
			// In production, this would be logged to a proper logger
			return
		}
	}
}

// RespondError writes a JSON error response with the given status, code, and message.
func RespondError(w http.ResponseWriter, status int, code, message string) {
	resp := ErrorResponse{
		Error: NewAPIError(code, message),
	}
	RespondJSON(w, status, resp)
}

// RespondValidationError writes a validation error response with field-level errors.
func RespondValidationError(w http.ResponseWriter, errors []ValidationError) {
	resp := ErrorResponse{
		Error: NewAPIErrorWithDetails(
			ErrCodeValidation,
			"Validation failed",
			ValidationErrors{Errors: errors},
		),
	}
	RespondJSON(w, http.StatusBadRequest, resp)
}

// RespondNotFound writes a not found error response for the given resource and ID.
func RespondNotFound(w http.ResponseWriter, resource, id string) {
	message := fmt.Sprintf("%s '%s' not found", resource, id)
	RespondError(w, http.StatusNotFound, ErrCodeNotFound, message)
}

// RespondUnauthorized writes an unauthorized error response.
func RespondUnauthorized(w http.ResponseWriter, message string) {
	if message == "" {
		message = "Authentication required"
	}
	RespondError(w, http.StatusUnauthorized, ErrCodeUnauthorized, message)
}

// RespondConflict writes a conflict error response.
func RespondConflict(w http.ResponseWriter, message string) {
	RespondError(w, http.StatusConflict, ErrCodeConflict, message)
}

// RespondRateLimited writes a rate limited error response.
func RespondRateLimited(w http.ResponseWriter) {
	RespondError(w, http.StatusTooManyRequests, ErrCodeRateLimited, "Rate limit exceeded")
}

// RespondInternalError writes an internal server error response.
// The message should be user-safe; do not expose internal error details.
func RespondInternalError(w http.ResponseWriter, message string) {
	if message == "" {
		message = "An internal error occurred"
	}
	RespondError(w, http.StatusInternalServerError, ErrCodeInternal, message)
}

// CascadeConflictDetails contains details about blocking references
type CascadeConflictDetails struct {
	BlockingHybrids []string `json:"blocking_hybrids"`
}

// RespondCascadeConflict writes a 409 Conflict response for cascade protection
func RespondCascadeConflict(w http.ResponseWriter, blockingHybrids []string) {
	count := len(blockingHybrids)
	message := fmt.Sprintf("Cannot delete: %d hybrid", count)
	if count != 1 {
		message += "s"
	}
	message += " reference this species as a parent"

	resp := ErrorResponse{
		Error: NewAPIErrorWithDetails(
			ErrCodeConflict,
			message,
			CascadeConflictDetails{BlockingHybrids: blockingHybrids},
		),
	}
	RespondJSON(w, http.StatusConflict, resp)
}
