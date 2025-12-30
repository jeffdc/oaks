package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRespondJSON(t *testing.T) {
	tests := []struct {
		name       string
		status     int
		data       interface{}
		wantStatus int
		wantBody   string
	}{
		{
			name:       "success with data",
			status:     http.StatusOK,
			data:       map[string]string{"message": "hello"},
			wantStatus: http.StatusOK,
			wantBody:   `{"message":"hello"}`,
		},
		{
			name:       "success with nil data",
			status:     http.StatusNoContent,
			data:       nil,
			wantStatus: http.StatusNoContent,
			wantBody:   "",
		},
		{
			name:       "created status",
			status:     http.StatusCreated,
			data:       map[string]int{"id": 123},
			wantStatus: http.StatusCreated,
			wantBody:   `{"id":123}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			RespondJSON(w, tt.status, tt.data)

			if w.Code != tt.wantStatus {
				t.Errorf("status = %d, want %d", w.Code, tt.wantStatus)
			}

			if w.Header().Get("Content-Type") != "application/json" {
				t.Errorf("Content-Type = %q, want %q", w.Header().Get("Content-Type"), "application/json")
			}

			if tt.wantBody != "" {
				var got, want interface{}
				if err := json.Unmarshal(w.Body.Bytes(), &got); err != nil {
					t.Fatalf("failed to unmarshal response body: %v", err)
				}
				if err := json.Unmarshal([]byte(tt.wantBody), &want); err != nil {
					t.Fatalf("failed to unmarshal expected body: %v", err)
				}
				gotJSON, _ := json.Marshal(got)
				wantJSON, _ := json.Marshal(want)
				if !bytes.Equal(gotJSON, wantJSON) {
					t.Errorf("body = %s, want %s", gotJSON, wantJSON)
				}
			}
		})
	}
}

func TestRespondError(t *testing.T) {
	w := httptest.NewRecorder()
	RespondError(w, http.StatusBadRequest, ErrCodeValidation, "invalid input")

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Error.Code != ErrCodeValidation {
		t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeValidation)
	}
	if resp.Error.Message != "invalid input" {
		t.Errorf("error message = %q, want %q", resp.Error.Message, "invalid input")
	}
}

func TestRespondValidationError(t *testing.T) {
	w := httptest.NewRecorder()
	errors := []ValidationError{
		{Field: "name", Message: "name is required"},
		{Field: "email", Message: "invalid email format"},
	}
	RespondValidationError(w, errors)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", w.Code, http.StatusBadRequest)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Error.Code != ErrCodeValidation {
		t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeValidation)
	}
	if resp.Error.Message != "Validation failed" {
		t.Errorf("error message = %q, want %q", resp.Error.Message, "Validation failed")
	}

	// Check details
	details, ok := resp.Error.Details.(map[string]interface{})
	if !ok {
		t.Fatalf("details is not a map: %T", resp.Error.Details)
	}
	errList, ok := details["errors"].([]interface{})
	if !ok {
		t.Fatalf("errors is not a list: %T", details["errors"])
	}
	if len(errList) != 2 {
		t.Errorf("len(errors) = %d, want 2", len(errList))
	}
}

func TestRespondNotFound(t *testing.T) {
	w := httptest.NewRecorder()
	RespondNotFound(w, "species", "quercus-alba")

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want %d", w.Code, http.StatusNotFound)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Error.Code != ErrCodeNotFound {
		t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeNotFound)
	}
	if resp.Error.Message != "species 'quercus-alba' not found" {
		t.Errorf("error message = %q, want %q", resp.Error.Message, "species 'quercus-alba' not found")
	}
}

func TestRespondUnauthorized(t *testing.T) {
	tests := []struct {
		name        string
		message     string
		wantMessage string
	}{
		{
			name:        "custom message",
			message:     "Invalid API key",
			wantMessage: "Invalid API key",
		},
		{
			name:        "empty message uses default",
			message:     "",
			wantMessage: "Authentication required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			RespondUnauthorized(w, tt.message)

			if w.Code != http.StatusUnauthorized {
				t.Errorf("status = %d, want %d", w.Code, http.StatusUnauthorized)
			}

			var resp ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to unmarshal response: %v", err)
			}

			if resp.Error.Code != ErrCodeUnauthorized {
				t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeUnauthorized)
			}
			if resp.Error.Message != tt.wantMessage {
				t.Errorf("error message = %q, want %q", resp.Error.Message, tt.wantMessage)
			}
		})
	}
}

func TestRespondConflict(t *testing.T) {
	w := httptest.NewRecorder()
	RespondConflict(w, "Resource already exists")

	if w.Code != http.StatusConflict {
		t.Errorf("status = %d, want %d", w.Code, http.StatusConflict)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Error.Code != ErrCodeConflict {
		t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeConflict)
	}
}

func TestRespondRateLimited(t *testing.T) {
	w := httptest.NewRecorder()
	RespondRateLimited(w)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("status = %d, want %d", w.Code, http.StatusTooManyRequests)
	}

	var resp ErrorResponse
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to unmarshal response: %v", err)
	}

	if resp.Error.Code != ErrCodeRateLimited {
		t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeRateLimited)
	}
	if resp.Error.Message != "Rate limit exceeded" {
		t.Errorf("error message = %q, want %q", resp.Error.Message, "Rate limit exceeded")
	}
}

func TestRespondInternalError(t *testing.T) {
	tests := []struct {
		name        string
		message     string
		wantMessage string
	}{
		{
			name:        "custom message",
			message:     "Database connection failed",
			wantMessage: "Database connection failed",
		},
		{
			name:        "empty message uses default",
			message:     "",
			wantMessage: "An internal error occurred",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			RespondInternalError(w, tt.message)

			if w.Code != http.StatusInternalServerError {
				t.Errorf("status = %d, want %d", w.Code, http.StatusInternalServerError)
			}

			var resp ErrorResponse
			if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
				t.Fatalf("failed to unmarshal response: %v", err)
			}

			if resp.Error.Code != ErrCodeInternal {
				t.Errorf("error code = %q, want %q", resp.Error.Code, ErrCodeInternal)
			}
			if resp.Error.Message != tt.wantMessage {
				t.Errorf("error message = %q, want %q", resp.Error.Message, tt.wantMessage)
			}
		})
	}
}

func TestHTTPStatus(t *testing.T) {
	tests := []struct {
		code   string
		status int
	}{
		{ErrCodeValidation, http.StatusBadRequest},
		{ErrCodeUnauthorized, http.StatusUnauthorized},
		{ErrCodeNotFound, http.StatusNotFound},
		{ErrCodeConflict, http.StatusConflict},
		{ErrCodeRateLimited, http.StatusTooManyRequests},
		{ErrCodeInternal, http.StatusInternalServerError},
		{"UNKNOWN_CODE", http.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.code, func(t *testing.T) {
			got := HTTPStatus(tt.code)
			if got != tt.status {
				t.Errorf("HTTPStatus(%q) = %d, want %d", tt.code, got, tt.status)
			}
		})
	}
}

func TestNewListResponse(t *testing.T) {
	type Item struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	}

	tests := []struct {
		name        string
		data        []Item
		total       int
		limit       int
		offset      int
		wantHasMore bool
	}{
		{
			name:        "first page with more pages",
			data:        []Item{{1, "a"}, {2, "b"}},
			total:       5,
			limit:       2,
			offset:      0,
			wantHasMore: true,
		},
		{
			name:        "last page",
			data:        []Item{{5, "e"}},
			total:       5,
			limit:       2,
			offset:      4,
			wantHasMore: false,
		},
		{
			name:        "exactly fills page",
			data:        []Item{{3, "c"}, {4, "d"}},
			total:       4,
			limit:       2,
			offset:      2,
			wantHasMore: false,
		},
		{
			name:        "empty data",
			data:        []Item{},
			total:       0,
			limit:       10,
			offset:      0,
			wantHasMore: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp := NewListResponse(tt.data, tt.total, tt.limit, tt.offset)

			if len(resp.Data) != len(tt.data) {
				t.Errorf("len(Data) = %d, want %d", len(resp.Data), len(tt.data))
			}
			if resp.Pagination.Total != tt.total {
				t.Errorf("Total = %d, want %d", resp.Pagination.Total, tt.total)
			}
			if resp.Pagination.Limit != tt.limit {
				t.Errorf("Limit = %d, want %d", resp.Pagination.Limit, tt.limit)
			}
			if resp.Pagination.Offset != tt.offset {
				t.Errorf("Offset = %d, want %d", resp.Pagination.Offset, tt.offset)
			}
			if resp.Pagination.HasMore != tt.wantHasMore {
				t.Errorf("HasMore = %v, want %v", resp.Pagination.HasMore, tt.wantHasMore)
			}
		})
	}
}

func TestNewAPIError(t *testing.T) {
	err := NewAPIError(ErrCodeNotFound, "resource not found")

	if err.Code != ErrCodeNotFound {
		t.Errorf("Code = %q, want %q", err.Code, ErrCodeNotFound)
	}
	if err.Message != "resource not found" {
		t.Errorf("Message = %q, want %q", err.Message, "resource not found")
	}
	if err.Details != nil {
		t.Errorf("Details = %v, want nil", err.Details)
	}
}

func TestNewAPIErrorWithDetails(t *testing.T) {
	details := map[string]string{"field": "name"}
	err := NewAPIErrorWithDetails(ErrCodeValidation, "validation failed", details)

	if err.Code != ErrCodeValidation {
		t.Errorf("Code = %q, want %q", err.Code, ErrCodeValidation)
	}
	if err.Message != "validation failed" {
		t.Errorf("Message = %q, want %q", err.Message, "validation failed")
	}
	if err.Details == nil {
		t.Error("Details is nil, want non-nil")
	}
	d, ok := err.Details.(map[string]string)
	if !ok {
		t.Fatalf("Details is %T, want map[string]string", err.Details)
	}
	if d["field"] != "name" {
		t.Errorf("Details[field] = %q, want %q", d["field"], "name")
	}
}
