package client

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestExport_Success(t *testing.T) {
	exportData := map[string]interface{}{
		"species": []map[string]interface{}{
			{"name": "alba", "is_hybrid": false},
			{"name": "rubra", "is_hybrid": false},
		},
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/export" {
			t.Errorf("path = %s, want /api/v1/export", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(exportData)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	data, err := c.Export()
	if err != nil {
		t.Fatalf("Export() error = %v", err)
	}

	// Verify we got valid JSON
	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("failed to unmarshal export data: %v", err)
	}

	species, ok := result["species"].([]interface{})
	if !ok {
		t.Fatal("export data missing species array")
	}
	if len(species) != 2 {
		t.Errorf("got %d species, want 2", len(species))
	}
}

func TestExport_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.Export()
	if err == nil {
		t.Fatal("expected error for server error response")
	}
}

func TestExportToWriter_Success(t *testing.T) {
	exportData := `{"species":[{"name":"alba"},{"name":"rubra"}]}`

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/export" {
			t.Errorf("path = %s, want /api/v1/export", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(exportData))
	}))
	defer server.Close()

	c := newTestClient(t, server)
	var buf bytes.Buffer
	err := c.ExportToWriter(&buf)
	if err != nil {
		t.Fatalf("ExportToWriter() error = %v", err)
	}

	if buf.String() != exportData {
		t.Errorf("got %q, want %q", buf.String(), exportData)
	}
}

func TestExportToWriter_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	var buf bytes.Buffer
	err := c.ExportToWriter(&buf)
	if err == nil {
		t.Fatal("expected error for server error response")
	}
}

func TestExport_LargeResponse(t *testing.T) {
	// Generate a larger response to test streaming
	species := make([]map[string]interface{}, 100)
	for i := 0; i < 100; i++ {
		species[i] = map[string]interface{}{
			"name":      "species" + string(rune('A'+i%26)),
			"is_hybrid": i%2 == 0,
		}
	}
	exportData := map[string]interface{}{"species": species}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(exportData)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	data, err := c.Export()
	if err != nil {
		t.Fatalf("Export() error = %v", err)
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatalf("failed to unmarshal export data: %v", err)
	}

	species2, ok := result["species"].([]interface{})
	if !ok {
		t.Fatal("export data missing species array")
	}
	if len(species2) != 100 {
		t.Errorf("got %d species, want 100", len(species2))
	}
}

func TestExport_Unauthorized(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.Export()
	if err == nil {
		t.Fatal("expected error for unauthorized response")
	}
	if !IsAuthError(err) {
		t.Errorf("expected auth error, got %v", err)
	}
}
