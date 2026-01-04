package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/jeff/oaks/api/internal/db"
	"github.com/jeff/oaks/api/internal/models"
)

// ArticleRequest is the request body for creating or updating an article.
type ArticleRequest struct {
	Title       string   `json:"title"`
	Author      string   `json:"author"`
	Content     *string  `json:"content,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	IsPublished bool     `json:"is_published"`
}

// ArticleResponse is the response for a single article.
type ArticleResponse struct {
	ID          int64    `json:"id"`
	Slug        string   `json:"slug"`
	Title       string   `json:"title"`
	Author      string   `json:"author"`
	Content     *string  `json:"content,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	IsPublished bool     `json:"is_published"`
	CreatedAt   string   `json:"created_at"`
	UpdatedAt   string   `json:"updated_at"`
	PublishedAt *string  `json:"published_at,omitempty"`
}

// articleToResponse converts a models.Article to ArticleResponse.
func articleToResponse(a *models.Article) ArticleResponse {
	resp := ArticleResponse{
		ID:          a.ID,
		Slug:        a.Slug,
		Title:       a.Title,
		Author:      a.Author,
		Content:     a.Content,
		IsPublished: a.IsPublished,
		CreatedAt:   a.CreatedAt,
		UpdatedAt:   a.UpdatedAt,
		PublishedAt: a.PublishedAt,
	}
	if len(a.Tags) > 0 {
		resp.Tags = a.Tags
	}
	return resp
}

// handleListArticles handles GET /api/v1/articles
func (s *Server) handleListArticles(w http.ResponseWriter, r *http.Request) {
	params := &db.ArticleListParams{}

	// Check for optional tag filter
	if tagParam := r.URL.Query().Get("tag"); tagParam != "" {
		params.Tag = &tagParam
	}

	// Check for optional published filter
	if publishedParam := r.URL.Query().Get("published"); publishedParam != "" {
		if publishedParam == "true" {
			published := true
			params.IsPublished = &published
		} else if publishedParam == "false" {
			published := false
			params.IsPublished = &published
		}
	}

	// If not authenticated, only show published articles
	if !s.isAuthenticated(r) {
		published := true
		params.IsPublished = &published
	}

	articles, err := s.db.ListArticles(params)
	if err != nil {
		s.logger.Error("failed to list articles", "error", err)
		RespondInternalError(w, "Failed to retrieve articles")
		return
	}

	// Convert to response format
	data := make([]ArticleResponse, 0, len(articles))
	for _, a := range articles {
		data = append(data, articleToResponse(a))
	}

	// Return list response
	resp := NewListResponse(data, len(data), len(data), 0)
	RespondJSON(w, http.StatusOK, resp)
}

// handleGetArticle handles GET /api/v1/articles/{slug}
func (s *Server) handleGetArticle(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	article, err := s.db.GetArticle(slug)
	if err != nil {
		s.logger.Error("failed to get article", "error", err, "slug", slug)
		RespondInternalError(w, "Failed to retrieve article")
		return
	}

	if article == nil {
		RespondNotFound(w, "Article", slug)
		return
	}

	// If not authenticated and article is not published, deny access
	if !article.IsPublished && !s.isAuthenticated(r) {
		RespondNotFound(w, "Article", slug)
		return
	}

	RespondJSON(w, http.StatusOK, articleToResponse(article))
}

// handleCreateArticle handles POST /api/v1/articles
func (s *Server) handleCreateArticle(w http.ResponseWriter, r *http.Request) {
	var req ArticleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondValidationError(w, []ValidationError{
			{Field: "body", Message: "invalid JSON body"},
		})
		return
	}

	// Validate required fields
	var errors []ValidationError
	if req.Title == "" {
		errors = append(errors, ValidationError{Field: "title", Message: "is required"})
	}
	if req.Author == "" {
		errors = append(errors, ValidationError{Field: "author", Message: "is required"})
	}
	if len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Create the article
	now := time.Now().UTC().Format(time.RFC3339)
	article := &models.Article{
		Title:       req.Title,
		Author:      req.Author,
		Content:     req.Content,
		Tags:        req.Tags,
		IsPublished: req.IsPublished,
		CreatedAt:   now,
		UpdatedAt:   now,
	}
	if article.Tags == nil {
		article.Tags = []string{}
	}

	// Set published_at if publishing
	if req.IsPublished {
		article.PublishedAt = &now
	}

	if err := s.db.InsertArticle(article); err != nil {
		s.logger.Error("failed to insert article", "error", err)
		RespondInternalError(w, "Failed to create article")
		return
	}

	RespondJSON(w, http.StatusCreated, articleToResponse(article))
}

// handleUpdateArticle handles PUT /api/v1/articles/{slug}
func (s *Server) handleUpdateArticle(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	// Check if article exists
	existing, err := s.db.GetArticle(slug)
	if err != nil {
		s.logger.Error("failed to get article", "error", err, "slug", slug)
		RespondInternalError(w, "Failed to update article")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Article", slug)
		return
	}

	// Parse request body
	var req ArticleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		RespondValidationError(w, []ValidationError{
			{Field: "body", Message: "invalid JSON body"},
		})
		return
	}

	// Validate required fields
	var errors []ValidationError
	if req.Title == "" {
		errors = append(errors, ValidationError{Field: "title", Message: "is required"})
	}
	if req.Author == "" {
		errors = append(errors, ValidationError{Field: "author", Message: "is required"})
	}
	if len(errors) > 0 {
		RespondValidationError(w, errors)
		return
	}

	// Update the article
	now := time.Now().UTC().Format(time.RFC3339)
	existing.Title = req.Title
	existing.Author = req.Author
	existing.Content = req.Content
	existing.Tags = req.Tags
	existing.UpdatedAt = now
	if existing.Tags == nil {
		existing.Tags = []string{}
	}

	// Handle publishing state changes
	wasPublished := existing.IsPublished
	existing.IsPublished = req.IsPublished

	// Set published_at when first published
	if req.IsPublished && !wasPublished {
		existing.PublishedAt = &now
	}

	if err := s.db.UpdateArticle(existing); err != nil {
		s.logger.Error("failed to update article", "error", err)
		RespondInternalError(w, "Failed to update article")
		return
	}

	RespondJSON(w, http.StatusOK, articleToResponse(existing))
}

// handleDeleteArticle handles DELETE /api/v1/articles/{slug}
func (s *Server) handleDeleteArticle(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")

	// Check if article exists before deleting
	existing, err := s.db.GetArticle(slug)
	if err != nil {
		s.logger.Error("failed to get article", "error", err, "slug", slug)
		RespondInternalError(w, "Failed to delete article")
		return
	}
	if existing == nil {
		RespondNotFound(w, "Article", slug)
		return
	}

	if err := s.db.DeleteArticle(slug); err != nil {
		s.logger.Error("failed to delete article", "error", err)
		RespondInternalError(w, "Failed to delete article")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// handleListArticleTags handles GET /api/v1/articles/tags
func (s *Server) handleListArticleTags(w http.ResponseWriter, r *http.Request) {
	// If not authenticated, only show tags from published articles
	publishedOnly := !s.isAuthenticated(r)

	tags, err := s.db.ListArticleTags(publishedOnly)
	if err != nil {
		s.logger.Error("failed to list article tags", "error", err)
		RespondInternalError(w, "Failed to retrieve article tags")
		return
	}

	if tags == nil {
		tags = []db.ArticleTagCount{}
	}

	RespondJSON(w, http.StatusOK, tags)
}

// isAuthenticated checks if the request has a valid Bearer token.
func (s *Server) isAuthenticated(r *http.Request) bool {
	bearerToken := extractBearerToken(r)
	return bearerToken != "" && ValidateAPIKey(bearerToken, s.apiKey)
}
