package api

import "net/http"

// Error codes for API responses.
const (
	// ErrCodeValidation indicates a validation error (400).
	ErrCodeValidation = "VALIDATION_ERROR"

	// ErrCodeUnauthorized indicates an authentication failure (401).
	ErrCodeUnauthorized = "UNAUTHORIZED"

	// ErrCodeNotFound indicates a resource was not found (404).
	ErrCodeNotFound = "NOT_FOUND"

	// ErrCodeConflict indicates a resource conflict (409).
	ErrCodeConflict = "CONFLICT"

	// ErrCodeRateLimited indicates rate limiting (429).
	ErrCodeRateLimited = "RATE_LIMITED"

	// ErrCodeInternal indicates an internal server error (500).
	ErrCodeInternal = "INTERNAL_ERROR"
)

// APIError represents an error in API responses.
type APIError struct {
	Code    string      `json:"code"`
	Message string      `json:"message"`
	Details interface{} `json:"details,omitempty"`
}

// ErrorResponse wraps an APIError for JSON responses.
type ErrorResponse struct {
	Error APIError `json:"error"`
}

// ValidationError represents a field-level validation error.
type ValidationError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// ValidationErrors is a collection of validation errors.
type ValidationErrors struct {
	Errors []ValidationError `json:"errors"`
}

// HTTPStatus returns the appropriate HTTP status code for an error code.
func HTTPStatus(code string) int {
	switch code {
	case ErrCodeValidation:
		return http.StatusBadRequest
	case ErrCodeUnauthorized:
		return http.StatusUnauthorized
	case ErrCodeNotFound:
		return http.StatusNotFound
	case ErrCodeConflict:
		return http.StatusConflict
	case ErrCodeRateLimited:
		return http.StatusTooManyRequests
	case ErrCodeInternal:
		return http.StatusInternalServerError
	default:
		return http.StatusInternalServerError
	}
}

// NewAPIError creates a new APIError with the given code and message.
func NewAPIError(code, message string) APIError {
	return APIError{
		Code:    code,
		Message: message,
	}
}

// NewAPIErrorWithDetails creates a new APIError with details.
func NewAPIErrorWithDetails(code, message string, details interface{}) APIError {
	return APIError{
		Code:    code,
		Message: message,
		Details: details,
	}
}
