package client

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestListTaxa_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/taxa" {
			t.Errorf("path = %s, want /api/v1/taxa", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(TaxaListResponse{
			Data: []*Taxon{
				{Name: "Quercus", Level: TaxonLevelSubgenus},
				{Name: "Lobatae", Level: TaxonLevelSection},
			},
			Pagination: Pagination{Total: 2, Limit: 100, Offset: 0},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, err := c.ListTaxa(nil)
	if err != nil {
		t.Fatalf("ListTaxa() error = %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("got %d taxa, want 2", len(resp.Data))
	}
}

func TestListTaxa_WithLevelFilter(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		level := r.URL.Query().Get("level")
		if level != "section" {
			t.Errorf("level = %s, want section", level)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(TaxaListResponse{
			Data:       []*Taxon{{Name: "Lobatae", Level: TaxonLevelSection}},
			Pagination: Pagination{Total: 1},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	level := TaxonLevelSection
	resp, err := c.ListTaxa(&level)
	if err != nil {
		t.Fatalf("ListTaxa() error = %v", err)
	}

	if len(resp.Data) != 1 {
		t.Errorf("got %d taxa, want 1", len(resp.Data))
	}
}

func TestGetTaxon_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/taxa/section/Lobatae" {
			t.Errorf("path = %s, want /api/v1/taxa/section/Lobatae", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		parent := "Quercus"
		json.NewEncoder(w).Encode(Taxon{
			Name:   "Lobatae",
			Level:  TaxonLevelSection,
			Parent: &parent,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	taxon, err := c.GetTaxon(TaxonLevelSection, "Lobatae")
	if err != nil {
		t.Fatalf("GetTaxon() error = %v", err)
	}

	if taxon.Name != "Lobatae" {
		t.Errorf("Name = %s, want Lobatae", taxon.Name)
	}
	if taxon.Level != TaxonLevelSection {
		t.Errorf("Level = %s, want section", taxon.Level)
	}
}

func TestGetTaxon_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.GetTaxon(TaxonLevelSection, "Nonexistent")
	if err == nil {
		t.Fatal("expected error for not found taxon")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestCreateTaxon_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if r.URL.Path != "/api/v1/taxa" {
			t.Errorf("path = %s, want /api/v1/taxa", r.URL.Path)
		}

		body, _ := io.ReadAll(r.Body)
		var req TaxonRequest
		json.Unmarshal(body, &req)

		if req.Name != "Virentes" {
			t.Errorf("Name = %s, want Virentes", req.Name)
		}
		if req.Level != TaxonLevelSection {
			t.Errorf("Level = %s, want section", req.Level)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(Taxon{
			Name:   req.Name,
			Level:  req.Level,
			Parent: req.Parent,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	parent := "Quercus"
	taxon, err := c.CreateTaxon(&TaxonRequest{
		Name:   "Virentes",
		Level:  TaxonLevelSection,
		Parent: &parent,
	})
	if err != nil {
		t.Fatalf("CreateTaxon() error = %v", err)
	}

	if taxon.Name != "Virentes" {
		t.Errorf("Name = %s, want Virentes", taxon.Name)
	}
}

func TestUpdateTaxon_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			t.Errorf("method = %s, want PUT", r.Method)
		}
		if r.URL.Path != "/api/v1/taxa/section/Lobatae" {
			t.Errorf("path = %s, want /api/v1/taxa/section/Lobatae", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		notes := "Updated notes"
		json.NewEncoder(w).Encode(Taxon{
			Name:  "Lobatae",
			Level: TaxonLevelSection,
			Notes: &notes,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	notes := "Updated notes"
	taxon, err := c.UpdateTaxon(TaxonLevelSection, "Lobatae", &TaxonRequest{
		Name:  "Lobatae",
		Level: TaxonLevelSection,
		Notes: &notes,
	})
	if err != nil {
		t.Fatalf("UpdateTaxon() error = %v", err)
	}

	if taxon.Notes == nil || *taxon.Notes != "Updated notes" {
		t.Errorf("Notes = %v, want 'Updated notes'", taxon.Notes)
	}
}

func TestDeleteTaxon_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			t.Errorf("method = %s, want DELETE", r.Method)
		}
		if r.URL.Path != "/api/v1/taxa/subsection/Test" {
			t.Errorf("path = %s, want /api/v1/taxa/subsection/Test", r.URL.Path)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteTaxon(TaxonLevelSubsection, "Test")
	if err != nil {
		t.Fatalf("DeleteTaxon() error = %v", err)
	}
}

func TestDeleteTaxon_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteTaxon(TaxonLevelSection, "Nonexistent")
	if err == nil {
		t.Fatal("expected error for not found taxon")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestTaxonToRequest(t *testing.T) {
	parent := "Quercus"
	author := "Trel."
	notes := "Test notes"
	taxon := &Taxon{
		Name:   "Lobatae",
		Level:  TaxonLevelSection,
		Parent: &parent,
		Author: &author,
		Notes:  &notes,
		Links: []TaxonLink{
			{Label: "Wikipedia", URL: "https://en.wikipedia.org/wiki/Lobatae"},
		},
	}

	req := TaxonToRequest(taxon)

	if req.Name != "Lobatae" {
		t.Errorf("Name = %s, want Lobatae", req.Name)
	}
	if req.Level != TaxonLevelSection {
		t.Errorf("Level = %s, want section", req.Level)
	}
	if *req.Parent != "Quercus" {
		t.Errorf("Parent = %s, want Quercus", *req.Parent)
	}
	if *req.Author != "Trel." {
		t.Errorf("Author = %s, want Trel.", *req.Author)
	}
	if len(req.Links) != 1 {
		t.Errorf("got %d links, want 1", len(req.Links))
	}
}

func TestTaxa_URLEscaping(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// r.URL.Path is decoded; verify special chars are handled correctly
		// Spaces in taxon names should work
		if r.URL.Path != "/api/v1/taxa/complex/Red Oaks" {
			t.Errorf("path = %s, want /api/v1/taxa/complex/Red Oaks", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(Taxon{Name: "Red Oaks", Level: TaxonLevelComplex})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	taxon, err := c.GetTaxon(TaxonLevelComplex, "Red Oaks")
	if err != nil {
		t.Fatalf("GetTaxon() error = %v", err)
	}

	if taxon.Name != "Red Oaks" {
		t.Errorf("Name = %s, want 'Red Oaks'", taxon.Name)
	}
}
