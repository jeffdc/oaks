package client

import (
	"fmt"
	"net/http"
	"net/url"
	"strconv"
)

// SpeciesListParams contains parameters for listing species.
type SpeciesListParams struct {
	Limit    int
	Offset   int
	Subgenus *string
	Section  *string
	Hybrid   *bool
}

// SpeciesListResponse contains the paginated list of species.
type SpeciesListResponse struct {
	Data       []*OakEntry `json:"data"`
	Pagination Pagination  `json:"pagination"`
}

// Pagination contains pagination metadata.
type Pagination struct {
	Total  int `json:"total"`
	Limit  int `json:"limit"`
	Offset int `json:"offset"`
}

// SpeciesSearchResponse contains search results.
type SpeciesSearchResponse struct {
	Data  []*OakEntry `json:"data"`
	Query string      `json:"query"`
	Count int         `json:"count"`
}

// SpeciesRequest represents the request body for creating/updating a species.
type SpeciesRequest struct {
	ScientificName     string   `json:"scientific_name"`
	Author             *string  `json:"author,omitempty"`
	IsHybrid           bool     `json:"is_hybrid"`
	ConservationStatus *string  `json:"conservation_status,omitempty"`
	Subgenus           *string  `json:"subgenus,omitempty"`
	Section            *string  `json:"section,omitempty"`
	Subsection         *string  `json:"subsection,omitempty"`
	Complex            *string  `json:"complex,omitempty"`
	Parent1            *string  `json:"parent1,omitempty"`
	Parent2            *string  `json:"parent2,omitempty"`
	Synonyms           []string `json:"synonyms,omitempty"`
}

// ListSpecies retrieves a paginated list of species.
func (c *Client) ListSpecies(params *SpeciesListParams) (*SpeciesListResponse, error) {
	path := "/api/v1/species"
	if params != nil {
		query := url.Values{}
		if params.Limit > 0 {
			query.Set("limit", strconv.Itoa(params.Limit))
		}
		if params.Offset > 0 {
			query.Set("offset", strconv.Itoa(params.Offset))
		}
		if params.Subgenus != nil {
			query.Set("subgenus", *params.Subgenus)
		}
		if params.Section != nil {
			query.Set("section", *params.Section)
		}
		if params.Hybrid != nil {
			query.Set("hybrid", strconv.FormatBool(*params.Hybrid))
		}
		if len(query) > 0 {
			path += "?" + query.Encode()
		}
	}

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result SpeciesListResponse
	if err := c.parseResponse(resp, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// GetSpecies retrieves a single species by name.
func (c *Client) GetSpecies(name string) (*OakEntry, error) {
	path := "/api/v1/species/" + url.PathEscape(name)

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var entry OakEntry
	if err := c.parseResponse(resp, &entry); err != nil {
		return nil, err
	}

	return &entry, nil
}

// SearchSpecies searches for species matching the query.
func (c *Client) SearchSpecies(query string, limit int) (*SpeciesSearchResponse, error) {
	params := url.Values{}
	params.Set("q", query)
	if limit > 0 {
		params.Set("limit", strconv.Itoa(limit))
	}
	path := "/api/v1/species/search?" + params.Encode()

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result SpeciesSearchResponse
	if err := c.parseResponse(resp, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// CreateSpecies creates a new species.
func (c *Client) CreateSpecies(req *SpeciesRequest) (*OakEntry, error) {
	resp, err := c.doRequest(http.MethodPost, "/api/v1/species", req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var entry OakEntry
	if err := c.parseResponse(resp, &entry); err != nil {
		return nil, err
	}

	return &entry, nil
}

// UpdateSpecies updates an existing species.
func (c *Client) UpdateSpecies(name string, req *SpeciesRequest) (*OakEntry, error) {
	path := "/api/v1/species/" + url.PathEscape(name)

	resp, err := c.doRequest(http.MethodPut, path, req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var entry OakEntry
	if err := c.parseResponse(resp, &entry); err != nil {
		return nil, err
	}

	return &entry, nil
}

// DeleteSpecies deletes a species by name.
func (c *Client) DeleteSpecies(name string) error {
	path := "/api/v1/species/" + url.PathEscape(name)

	resp, err := c.doRequest(http.MethodDelete, path, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		return c.parseError(resp)
	}

	return nil
}

// EntryToRequest converts an OakEntry to a SpeciesRequest.
func EntryToRequest(entry *OakEntry) *SpeciesRequest {
	return &SpeciesRequest{
		ScientificName:     entry.ScientificName,
		Author:             entry.Author,
		IsHybrid:           entry.IsHybrid,
		ConservationStatus: entry.ConservationStatus,
		Subgenus:           entry.Subgenus,
		Section:            entry.Section,
		Subsection:         entry.Subsection,
		Complex:            entry.Complex,
		Parent1:            entry.Parent1,
		Parent2:            entry.Parent2,
		Synonyms:           entry.Synonyms,
	}
}

// GetSpeciesWithSources retrieves a species along with its source data.
func (c *Client) GetSpeciesWithSources(name string) (*OakEntry, []*SpeciesSource, error) {
	entry, err := c.GetSpecies(name)
	if err != nil {
		return nil, nil, err
	}

	sources, err := c.ListSpeciesSources(name)
	if err != nil {
		return entry, nil, fmt.Errorf("failed to get species sources: %w", err)
	}

	return entry, sources, nil
}

// ListSpeciesSources retrieves all source data for a species.
func (c *Client) ListSpeciesSources(name string) ([]*SpeciesSource, error) {
	path := "/api/v1/species/" + url.PathEscape(name) + "/sources"

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sources []*SpeciesSource
	if err := c.parseResponse(resp, &sources); err != nil {
		return nil, err
	}

	return sources, nil
}

// GetSpeciesSource retrieves a specific source entry for a species.
func (c *Client) GetSpeciesSource(name string, sourceID int64) (*SpeciesSource, error) {
	path := fmt.Sprintf("/api/v1/species/%s/sources/%d", url.PathEscape(name), sourceID)

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var source SpeciesSource
	if err := c.parseResponse(resp, &source); err != nil {
		return nil, err
	}

	return &source, nil
}

// CreateSpeciesSource creates a new source entry for a species.
func (c *Client) CreateSpeciesSource(name string, source *SpeciesSource) (*SpeciesSource, error) {
	path := "/api/v1/species/" + url.PathEscape(name) + "/sources"

	resp, err := c.doRequest(http.MethodPost, path, source)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result SpeciesSource
	if err := c.parseResponse(resp, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// UpdateSpeciesSource updates a source entry for a species.
func (c *Client) UpdateSpeciesSource(name string, sourceID int64, source *SpeciesSource) (*SpeciesSource, error) {
	path := fmt.Sprintf("/api/v1/species/%s/sources/%d", url.PathEscape(name), sourceID)

	resp, err := c.doRequest(http.MethodPut, path, source)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result SpeciesSource
	if err := c.parseResponse(resp, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// DeleteSpeciesSource deletes a source entry for a species.
func (c *Client) DeleteSpeciesSource(name string, sourceID int64) error {
	path := fmt.Sprintf("/api/v1/species/%s/sources/%d", url.PathEscape(name), sourceID)

	resp, err := c.doRequest(http.MethodDelete, path, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusNoContent {
		return c.parseError(resp)
	}

	return nil
}
