package client

import (
	"net/http"
	"net/url"
)

// TaxonRequest represents the request body for creating/updating a taxon.
type TaxonRequest struct {
	Name   string      `json:"name"`
	Level  TaxonLevel  `json:"level"`
	Parent *string     `json:"parent,omitempty"`
	Author *string     `json:"author,omitempty"`
	Notes  *string     `json:"notes,omitempty"`
	Links  []TaxonLink `json:"links,omitempty"`
}

// TaxaListResponse contains the list of taxa.
type TaxaListResponse struct {
	Data       []*Taxon   `json:"data"`
	Pagination Pagination `json:"pagination"`
}

// ListTaxa retrieves all taxa, optionally filtered by level.
func (c *Client) ListTaxa(level *TaxonLevel) (*TaxaListResponse, error) {
	path := "/api/v1/taxa"
	if level != nil {
		query := url.Values{}
		query.Set("level", string(*level))
		path += "?" + query.Encode()
	}

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result TaxaListResponse
	if err := c.parseResponse(resp, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// GetTaxon retrieves a single taxon by level and name.
func (c *Client) GetTaxon(level TaxonLevel, name string) (*Taxon, error) {
	path := "/api/v1/taxa/" + url.PathEscape(string(level)) + "/" + url.PathEscape(name)

	resp, err := c.doRequest(http.MethodGet, path, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var taxon Taxon
	if err := c.parseResponse(resp, &taxon); err != nil {
		return nil, err
	}

	return &taxon, nil
}

// CreateTaxon creates a new taxon.
func (c *Client) CreateTaxon(req *TaxonRequest) (*Taxon, error) {
	resp, err := c.doRequest(http.MethodPost, "/api/v1/taxa", req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var taxon Taxon
	if err := c.parseResponse(resp, &taxon); err != nil {
		return nil, err
	}

	return &taxon, nil
}

// UpdateTaxon updates an existing taxon.
func (c *Client) UpdateTaxon(level TaxonLevel, name string, req *TaxonRequest) (*Taxon, error) {
	path := "/api/v1/taxa/" + url.PathEscape(string(level)) + "/" + url.PathEscape(name)

	resp, err := c.doRequest(http.MethodPut, path, req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var taxon Taxon
	if err := c.parseResponse(resp, &taxon); err != nil {
		return nil, err
	}

	return &taxon, nil
}

// DeleteTaxon deletes a taxon by level and name.
func (c *Client) DeleteTaxon(level TaxonLevel, name string) error {
	path := "/api/v1/taxa/" + url.PathEscape(string(level)) + "/" + url.PathEscape(name)

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

// TaxonToRequest converts a Taxon to a TaxonRequest.
func TaxonToRequest(taxon *Taxon) *TaxonRequest {
	return &TaxonRequest{
		Name:   taxon.Name,
		Level:  taxon.Level,
		Parent: taxon.Parent,
		Author: taxon.Author,
		Notes:  taxon.Notes,
		Links:  taxon.Links,
	}
}
