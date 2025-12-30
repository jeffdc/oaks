package client

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestListSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/species" {
			t.Errorf("path = %s, want /api/v1/species", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SpeciesListResponse{
			Data: []*OakEntry{
				{ScientificName: "alba", IsHybrid: false},
				{ScientificName: "rubra", IsHybrid: false},
			},
			Pagination: Pagination{Total: 2, Limit: 50, Offset: 0},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, err := c.ListSpecies(nil)
	if err != nil {
		t.Fatalf("ListSpecies() error = %v", err)
	}

	if len(resp.Data) != 2 {
		t.Errorf("got %d species, want 2", len(resp.Data))
	}
	if resp.Pagination.Total != 2 {
		t.Errorf("Total = %d, want 2", resp.Pagination.Total)
	}
}

func TestListSpecies_WithParams(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()

		if q.Get("limit") != "10" {
			t.Errorf("limit = %s, want 10", q.Get("limit"))
		}
		if q.Get("offset") != "20" {
			t.Errorf("offset = %s, want 20", q.Get("offset"))
		}
		if q.Get("subgenus") != "Quercus" {
			t.Errorf("subgenus = %s, want Quercus", q.Get("subgenus"))
		}
		if q.Get("hybrid") != "true" {
			t.Errorf("hybrid = %s, want true", q.Get("hybrid"))
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SpeciesListResponse{
			Data:       []*OakEntry{},
			Pagination: Pagination{Total: 0, Limit: 10, Offset: 20},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	subgenus := "Quercus"
	hybrid := true
	_, err := c.ListSpecies(&SpeciesListParams{
		Limit:    10,
		Offset:   20,
		Subgenus: &subgenus,
		Hybrid:   &hybrid,
	})
	if err != nil {
		t.Fatalf("ListSpecies() error = %v", err)
	}
}

func TestGetSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba" {
			t.Errorf("path = %s, want /api/v1/species/alba", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(OakEntry{
			ScientificName: "alba",
			IsHybrid:       false,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	entry, err := c.GetSpecies("alba")
	if err != nil {
		t.Fatalf("GetSpecies() error = %v", err)
	}

	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", entry.ScientificName)
	}
}

func TestGetSpecies_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.GetSpecies("nonexistent")
	if err == nil {
		t.Fatal("expected error for not found species")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestSearchSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			t.Errorf("method = %s, want GET", r.Method)
		}
		if r.URL.Query().Get("q") != "alba" {
			t.Errorf("query = %s, want alba", r.URL.Query().Get("q"))
		}
		if r.URL.Query().Get("limit") != "5" {
			t.Errorf("limit = %s, want 5", r.URL.Query().Get("limit"))
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SpeciesSearchResponse{
			Data:  []*OakEntry{{ScientificName: "alba"}},
			Query: "alba",
			Count: 1,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	resp, err := c.SearchSpecies("alba", 5)
	if err != nil {
		t.Fatalf("SearchSpecies() error = %v", err)
	}

	if resp.Count != 1 {
		t.Errorf("Count = %d, want 1", resp.Count)
	}
	if resp.Query != "alba" {
		t.Errorf("Query = %s, want alba", resp.Query)
	}
}

func TestCreateSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if r.URL.Path != "/api/v1/species" {
			t.Errorf("path = %s, want /api/v1/species", r.URL.Path)
		}

		body, _ := io.ReadAll(r.Body)
		var req SpeciesRequest
		json.Unmarshal(body, &req)

		if req.ScientificName != "newspecies" {
			t.Errorf("ScientificName = %s, want newspecies", req.ScientificName)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(OakEntry{
			ScientificName: req.ScientificName,
			IsHybrid:       req.IsHybrid,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	entry, err := c.CreateSpecies(&SpeciesRequest{
		ScientificName: "newspecies",
		IsHybrid:       false,
	})
	if err != nil {
		t.Fatalf("CreateSpecies() error = %v", err)
	}

	if entry.ScientificName != "newspecies" {
		t.Errorf("ScientificName = %s, want newspecies", entry.ScientificName)
	}
}

func TestCreateSpecies_Conflict(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusConflict)
		json.NewEncoder(w).Encode(map[string]string{
			"code":    "conflict",
			"message": "species already exists",
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	_, err := c.CreateSpecies(&SpeciesRequest{ScientificName: "existing"})
	if err == nil {
		t.Fatal("expected error for conflict")
	}
	if !IsConflictError(err) {
		t.Errorf("expected conflict error, got %v", err)
	}
}

func TestUpdateSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			t.Errorf("method = %s, want PUT", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba" {
			t.Errorf("path = %s, want /api/v1/species/alba", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(OakEntry{
			ScientificName: "alba",
			IsHybrid:       false,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	entry, err := c.UpdateSpecies("alba", &SpeciesRequest{ScientificName: "alba"})
	if err != nil {
		t.Fatalf("UpdateSpecies() error = %v", err)
	}

	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", entry.ScientificName)
	}
}

func TestDeleteSpecies_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			t.Errorf("method = %s, want DELETE", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba" {
			t.Errorf("path = %s, want /api/v1/species/alba", r.URL.Path)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteSpecies("alba")
	if err != nil {
		t.Fatalf("DeleteSpecies() error = %v", err)
	}
}

func TestDeleteSpecies_NotFound(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteSpecies("nonexistent")
	if err == nil {
		t.Fatal("expected error for not found species")
	}
	if !IsNotFoundError(err) {
		t.Errorf("expected not found error, got %v", err)
	}
}

func TestListSpeciesSources_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/species/alba/sources" {
			t.Errorf("path = %s, want /api/v1/species/alba/sources", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		leaves := "Large lobed leaves"
		json.NewEncoder(w).Encode([]*SpeciesSource{
			{ID: 1, ScientificName: "alba", SourceID: 1, Leaves: &leaves},
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	sources, err := c.ListSpeciesSources("alba")
	if err != nil {
		t.Fatalf("ListSpeciesSources() error = %v", err)
	}

	if len(sources) != 1 {
		t.Errorf("got %d sources, want 1", len(sources))
	}
}

func TestGetSpeciesSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/species/alba/sources/1" {
			t.Errorf("path = %s, want /api/v1/species/alba/sources/1", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SpeciesSource{
			ID:             1,
			ScientificName: "alba",
			SourceID:       1,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	source, err := c.GetSpeciesSource("alba", 1)
	if err != nil {
		t.Fatalf("GetSpeciesSource() error = %v", err)
	}

	if source.ID != 1 {
		t.Errorf("ID = %d, want 1", source.ID)
	}
}

func TestCreateSpeciesSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Errorf("method = %s, want POST", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba/sources" {
			t.Errorf("path = %s, want /api/v1/species/alba/sources", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(SpeciesSource{
			ID:             1,
			ScientificName: "alba",
			SourceID:       2,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	source, err := c.CreateSpeciesSource("alba", &SpeciesSource{SourceID: 2})
	if err != nil {
		t.Fatalf("CreateSpeciesSource() error = %v", err)
	}

	if source.SourceID != 2 {
		t.Errorf("SourceID = %d, want 2", source.SourceID)
	}
}

func TestUpdateSpeciesSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			t.Errorf("method = %s, want PUT", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba/sources/1" {
			t.Errorf("path = %s, want /api/v1/species/alba/sources/1", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(SpeciesSource{
			ID:             1,
			ScientificName: "alba",
			SourceID:       1,
		})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	source, err := c.UpdateSpeciesSource("alba", 1, &SpeciesSource{SourceID: 1})
	if err != nil {
		t.Fatalf("UpdateSpeciesSource() error = %v", err)
	}

	if source.ID != 1 {
		t.Errorf("ID = %d, want 1", source.ID)
	}
}

func TestDeleteSpeciesSource_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodDelete {
			t.Errorf("method = %s, want DELETE", r.Method)
		}
		if r.URL.Path != "/api/v1/species/alba/sources/1" {
			t.Errorf("path = %s, want /api/v1/species/alba/sources/1", r.URL.Path)
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()

	c := newTestClient(t, server)
	err := c.DeleteSpeciesSource("alba", 1)
	if err != nil {
		t.Fatalf("DeleteSpeciesSource() error = %v", err)
	}
}

func TestGetSpeciesWithSources_Success(t *testing.T) {
	callCount := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		callCount++
		w.Header().Set("Content-Type", "application/json")

		switch r.URL.Path {
		case "/api/v1/species/alba":
			json.NewEncoder(w).Encode(OakEntry{ScientificName: "alba"})
		case "/api/v1/species/alba/sources":
			json.NewEncoder(w).Encode([]*SpeciesSource{{ID: 1, SourceID: 1}})
		default:
			t.Errorf("unexpected path: %s", r.URL.Path)
		}
	}))
	defer server.Close()

	c := newTestClient(t, server)
	entry, sources, err := c.GetSpeciesWithSources("alba")
	if err != nil {
		t.Fatalf("GetSpeciesWithSources() error = %v", err)
	}

	if entry.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", entry.ScientificName)
	}
	if len(sources) != 1 {
		t.Errorf("got %d sources, want 1", len(sources))
	}
	if callCount != 2 {
		t.Errorf("server called %d times, want 2", callCount)
	}
}

func TestEntryToRequest(t *testing.T) {
	author := "L."
	subgenus := "Quercus"
	entry := &OakEntry{
		ScientificName: "alba",
		Author:         &author,
		IsHybrid:       false,
		Subgenus:       &subgenus,
		Synonyms:       []string{"syn1", "syn2"},
	}

	req := EntryToRequest(entry)

	if req.ScientificName != "alba" {
		t.Errorf("ScientificName = %s, want alba", req.ScientificName)
	}
	if *req.Author != "L." {
		t.Errorf("Author = %s, want L.", *req.Author)
	}
	if req.IsHybrid {
		t.Error("IsHybrid = true, want false")
	}
	if *req.Subgenus != "Quercus" {
		t.Errorf("Subgenus = %s, want Quercus", *req.Subgenus)
	}
	if len(req.Synonyms) != 2 {
		t.Errorf("got %d synonyms, want 2", len(req.Synonyms))
	}
}

func TestSpecies_URLEscaping(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// r.URL.Path is decoded; verify special chars are handled correctly
		// The × character is a multiplication sign (U+00D7)
		if r.URL.Path != "/api/v1/species/×bebbiana" {
			t.Errorf("path = %s, want /api/v1/species/×bebbiana", r.URL.Path)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(OakEntry{ScientificName: "×bebbiana", IsHybrid: true})
	}))
	defer server.Close()

	c := newTestClient(t, server)
	entry, err := c.GetSpecies("×bebbiana")
	if err != nil {
		t.Fatalf("GetSpecies() error = %v", err)
	}

	if entry.ScientificName != "×bebbiana" {
		t.Errorf("ScientificName = %s, want '×bebbiana'", entry.ScientificName)
	}
}
