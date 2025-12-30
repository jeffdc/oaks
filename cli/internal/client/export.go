package client

import (
	"encoding/json"
	"io"
	"net/http"
)

// Export retrieves the full export from the API.
// The response is a JSON object containing all species data.
func (c *Client) Export() (json.RawMessage, error) {
	resp, err := c.doRequest(http.MethodGet, "/api/v1/export", nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.parseError(resp)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	return json.RawMessage(data), nil
}

// ExportToWriter writes the export directly to a writer.
// This is more efficient for large exports as it doesn't buffer the entire response.
func (c *Client) ExportToWriter(w io.Writer) error {
	resp, err := c.doRequest(http.MethodGet, "/api/v1/export", nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return c.parseError(resp)
	}

	_, err = io.Copy(w, resp.Body)
	return err
}
