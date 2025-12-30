package client

import (
	"fmt"
	"net/http"
)

// SourceRequest represents the request body for creating/updating a source.
type SourceRequest struct {
	SourceType  string  `json:"source_type"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
	Author      *string `json:"author,omitempty"`
	Year        *int    `json:"year,omitempty"`
	URL         *string `json:"url,omitempty"`
	ISBN        *string `json:"isbn,omitempty"`
	DOI         *string `json:"doi,omitempty"`
	Notes       *string `json:"notes,omitempty"`
	License     *string `json:"license,omitempty"`
	LicenseURL  *string `json:"license_url,omitempty"`
}

// ListSources retrieves all sources.
func (c *Client) ListSources() ([]*Source, error) {
	resp, err := c.doRequest(http.MethodGet, "/api/v1/sources", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var sources []*Source
	if err := c.parseResponse(resp, &sources); err != nil {
		return nil, err
	}

	return sources, nil
}

// GetSource retrieves a single source by ID.
func (c *Client) GetSource(id int64) (*Source, error) {
	path := fmt.Sprintf("/api/v1/sources/%d", id)

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var source Source
	if err := c.parseResponse(resp, &source); err != nil {
		return nil, err
	}

	return &source, nil
}

// CreateSource creates a new source.
func (c *Client) CreateSource(req *SourceRequest) (*Source, error) {
	resp, err := c.doRequest(http.MethodPost, "/api/v1/sources", req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var source Source
	if err := c.parseResponse(resp, &source); err != nil {
		return nil, err
	}

	return &source, nil
}

// UpdateSource updates an existing source.
func (c *Client) UpdateSource(id int64, req *SourceRequest) (*Source, error) {
	path := fmt.Sprintf("/api/v1/sources/%d", id)

	resp, err := c.doRequest(http.MethodPut, path, req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var source Source
	if err := c.parseResponse(resp, &source); err != nil {
		return nil, err
	}

	return &source, nil
}

// DeleteSource deletes a source by ID.
func (c *Client) DeleteSource(id int64) error {
	path := fmt.Sprintf("/api/v1/sources/%d", id)

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

// SourceToRequest converts a Source to a SourceRequest.
func SourceToRequest(source *Source) *SourceRequest {
	return &SourceRequest{
		SourceType:  source.SourceType,
		Name:        source.Name,
		Description: source.Description,
		Author:      source.Author,
		Year:        source.Year,
		URL:         source.URL,
		ISBN:        source.ISBN,
		DOI:         source.DOI,
		Notes:       source.Notes,
		License:     source.License,
		LicenseURL:  source.LicenseURL,
	}
}
