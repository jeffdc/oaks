package client

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestListSources_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/sources" {
			t.Errorf("path = %s, want /api/v1/sources", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode([]*Source{
			{ID: 1, Name: "iNaturalist", SourceType: "website"},
			{ID: 2, Name: "Oaks of the World", SourceType: "website"},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	sources, err := c.ListSources()
	if err != nil {
		t.Fatalf("ListSources() error = %v", err)
	}

	if len(sources) != 2 {
		t.Errorf("got %d sources, want 2", len(sources))
	}
	if sources[0].Name != "iNaturalist" {
		t.Errorf("sources[0].Name = %s, want iNaturalist", sources[0].Name)
	}
}

func TestGetSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/sources/1" {
			t.Errorf("path = %s, want /api/v1/sources/1", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		desc := "A community-driven biodiversity database"
		json.NewEncoder(w).Encode(Source{
			ID:          1,
			Name:        "iNaturalist",
			SourceType:  "website",
			Description: &desc,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	source, err := c.GetSource(1)
	if err != nil {
		t.Fatalf("GetSource() error = %v", err)
	}

	if source.ID != 1 {
		t.Errorf("ID = %d, want 1", source.ID)
	}
	if source.Name != "iNaturalist" {
		t.Errorf("Name = %s, want iNaturalist", source.Name)
	}
}

func TestGetSource_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.GetSource(999)
	if err == nil {
		t.Fatal("expected error for not found source")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestCreateSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if r.URL.Path != "/api/v1/sources" {
			t.Errorf("path = %s, want /api/v1/sources", r.URL.Path)
		}

		body, _ := io.ReadAll(r.Body)
		var req SourceRequest
		json.Unmarshal(body, &req)

		if req.Name != "New Source" {
			t.Errorf("Name = %s, want 'New Source'", req.Name)
		}
		if req.SourceType != "book" {
			t.Errorf("SourceType = %s, want book", req.SourceType)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(Source{
			ID:         3,
			Name:       req.Name,
			SourceType: req.SourceType,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	source, err := c.CreateSource(&SourceRequest{
		Name:       "New Source",
		SourceType: "book",
	})
	if err != nil {
		t.Fatalf("CreateSource() error = %v", err)
	}

	if source.ID != 3 {
		t.Errorf("ID = %d, want 3", source.ID)
	}
	if source.Name != "New Source" {
		t.Errorf("Name = %s, want 'New Source'", source.Name)
	}
}

func TestUpdateSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			t.Errorf("method = %s, want PUT", r.Method)
		}
		if r.URL.Path != "/api/v1/sources/1" {
			t.Errorf("path = %s, want /api/v1/sources/1", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		notes := "Updated notes"
		json.NewEncoder(w).Encode(Source{
			ID:         1,
			Name:       "iNaturalist",
			SourceType: "website",
			Notes:      &notes,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	notes := "Updated notes"
	source, err := c.UpdateSource(1, &SourceRequest{
		Name:       "iNaturalist",
		SourceType: "website",
		Notes:      &notes,
	})
	if err != nil {
		t.Fatalf("UpdateSource() error = %v", err)
	}

	if source.Notes == nil || *source.Notes != "Updated notes" {
		t.Errorf("Notes = %v, want 'Updated notes'", source.Notes)
	}
}

func TestDeleteSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			t.Errorf("method = %s, want DELETE", r.Method)
		}
		if r.URL.Path != "/api/v1/sources/1" {
			t.Errorf("path = %s, want /api/v1/sources/1", r.URL.Path)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteSource(1)
	if err != nil {
		t.Fatalf("DeleteSource() error = %v", err)
	}
}

func TestDeleteSource_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteSource(999)
	if err == nil {
		t.Fatal("expected error for not found source")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestSourceToRequest(t *testing.T) {
	desc := "A biodiversity database"
	author := "California Academy of Sciences"
	year := 2008
	url := "https://www.inaturalist.org"
	notes := "Primary source for taxonomy"
	license := "CC-BY-NC"
	licenseURL := "https://creativecommons.org/licenses/by-nc/4.0/"

	source := &Source{
		ID:          1,
		SourceType:  "website",
		Name:        "iNaturalist",
		Description: &desc,
		Author:      &author,
		Year:        &year,
		URL:         &url,
		Notes:       &notes,
		License:     &license,
		LicenseURL:  &licenseURL,
	}

	req := SourceToRequest(source)

	if req.SourceType != "website" {
		t.Errorf("SourceType = %s, want website", req.SourceType)
	}
	if req.Name != "iNaturalist" {
		t.Errorf("Name = %s, want iNaturalist", req.Name)
	}
	if *req.Description != desc {
		t.Errorf("Description = %s, want %s", *req.Description, desc)
	}
	if *req.Author != author {
		t.Errorf("Author = %s, want %s", *req.Author, author)
	}
	if *req.Year != year {
		t.Errorf("Year = %d, want %d", *req.Year, year)
	}
	if *req.URL != url {
		t.Errorf("URL = %s, want %s", *req.URL, url)
	}
	if *req.Notes != notes {
		t.Errorf("Notes = %s, want %s", *req.Notes, notes)
	}
	if *req.License != license {
		t.Errorf("License = %s, want %s", *req.License, license)
	}
	if *req.LicenseURL != licenseURL {
		t.Errorf("LicenseURL = %s, want %s", *req.LicenseURL, licenseURL)
	}
}

func TestSourceToRequest_NilFields(t *testing.T) {
	source := &Source{
		ID:         1,
		SourceType: "personal",
		Name:       "Field Notes",
	}

	req := SourceToRequest(source)

	if req.Description != nil {
		t.Error("Description should be nil")
	}
	if req.Author != nil {
		t.Error("Author should be nil")
	}
	if req.Year != nil {
		t.Error("Year should be nil")
	}
	if req.URL != nil {
		t.Error("URL should be nil")
	}
}
