package db

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/jeff/oaks/api/internal/models"
)

// ArticleListParams contains optional filters for listing articles
type ArticleListParams struct {
	Tag         *string
	IsPublished *bool
}

// ArticleTagCount represents a tag with its usage count
type ArticleTagCount struct {
	Tag   string `json:"tag"`
	Count int    `json:"count"`
}

// GenerateSlug creates a URL-friendly slug from a title.
// Converts to lowercase, replaces spaces with hyphens, removes special chars.
func GenerateSlug(title string) string {
	slug := strings.ToLower(title)
	// Replace spaces and underscores with hyphens
	slug = strings.ReplaceAll(slug, " ", "-")
	slug = strings.ReplaceAll(slug, "_", "-")
	// Remove characters that aren't alphanumeric or hyphens
	var result strings.Builder
	for _, r := range slug {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			result.WriteRune(r)
		}
	}
	slug = result.String()
	// Collapse multiple hyphens into one
	for strings.Contains(slug, "--") {
		slug = strings.ReplaceAll(slug, "--", "-")
	}
	// Trim leading/trailing hyphens
	slug = strings.Trim(slug, "-")
	return slug
}

// GenerateUniqueSlug creates a unique slug, appending -2, -3, etc. if collision
func (db *Database) GenerateUniqueSlug(title string, excludeID int64) (string, error) {
	baseSlug := GenerateSlug(title)
	if baseSlug == "" {
		baseSlug = "article"
	}

	slug := baseSlug
	suffix := 1

	for {
		var count int
		var err error
		if excludeID > 0 {
			// When updating, exclude the current article from collision check
			err = db.conn.QueryRow(
				`SELECT COUNT(*) FROM articles WHERE slug = ? AND id != ?`,
				slug, excludeID,
			).Scan(&count)
		} else {
			err = db.conn.QueryRow(
				`SELECT COUNT(*) FROM articles WHERE slug = ?`,
				slug,
			).Scan(&count)
		}
		if err != nil {
			return "", fmt.Errorf("failed to check slug uniqueness: %w", err)
		}

		if count == 0 {
			return slug, nil
		}

		suffix++
		slug = fmt.Sprintf("%s-%d", baseSlug, suffix)
	}
}

// InsertArticle inserts a new article and returns the created article
func (db *Database) InsertArticle(article *models.Article) error {
	// Generate unique slug from title
	slug, err := db.GenerateUniqueSlug(article.Title, 0)
	if err != nil {
		return err
	}
	article.Slug = slug

	// Marshal tags to JSON
	tagsJSON, err := json.Marshal(article.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	isPublished := 0
	if article.IsPublished {
		isPublished = 1
	}

	result, err := db.conn.Exec(
		`INSERT INTO articles (slug, title, author, content, tags, is_published, created_at, updated_at, published_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		article.Slug, article.Title, article.Author, article.Content, string(tagsJSON),
		isPublished, article.CreatedAt, article.UpdatedAt, article.PublishedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to insert article: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("failed to get last insert id: %w", err)
	}
	article.ID = id

	return nil
}

// GetArticle gets an article by slug
func (db *Database) GetArticle(slug string) (*models.Article, error) {
	row := db.conn.QueryRow(
		`SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
		 FROM articles WHERE slug = ?`,
		slug,
	)

	return scanArticle(row)
}

// GetArticleByID gets an article by ID
func (db *Database) GetArticleByID(id int64) (*models.Article, error) {
	row := db.conn.QueryRow(
		`SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
		 FROM articles WHERE id = ?`,
		id,
	)

	return scanArticle(row)
}

// scanArticle scans a single article row
func scanArticle(row *sql.Row) (*models.Article, error) {
	var a models.Article
	var tagsJSON sql.NullString
	var isPublished int

	err := row.Scan(
		&a.ID, &a.Slug, &a.Title, &a.Author, &a.Content, &tagsJSON,
		&isPublished, &a.CreatedAt, &a.UpdatedAt, &a.PublishedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get article: %w", err)
	}

	a.IsPublished = isPublished != 0
	if tagsJSON.Valid && tagsJSON.String != "" {
		if err := json.Unmarshal([]byte(tagsJSON.String), &a.Tags); err != nil {
			return nil, fmt.Errorf("failed to unmarshal tags: %w", err)
		}
	}
	if a.Tags == nil {
		a.Tags = []string{}
	}

	return &a, nil
}

// UpdateArticle updates an existing article
func (db *Database) UpdateArticle(article *models.Article) error {
	// Check if title changed and regenerate slug if needed
	existing, err := db.GetArticleByID(article.ID)
	if err != nil {
		return err
	}
	if existing == nil {
		return fmt.Errorf("article not found: %d", article.ID)
	}

	// If title changed, generate a new unique slug
	if article.Title != existing.Title {
		slug, err := db.GenerateUniqueSlug(article.Title, article.ID)
		if err != nil {
			return err
		}
		article.Slug = slug
	}

	// Marshal tags to JSON
	tagsJSON, err := json.Marshal(article.Tags)
	if err != nil {
		return fmt.Errorf("failed to marshal tags: %w", err)
	}

	isPublished := 0
	if article.IsPublished {
		isPublished = 1
	}

	_, err = db.conn.Exec(
		`UPDATE articles SET slug = ?, title = ?, author = ?, content = ?, tags = ?,
		 is_published = ?, updated_at = ?, published_at = ?
		 WHERE id = ?`,
		article.Slug, article.Title, article.Author, article.Content, string(tagsJSON),
		isPublished, article.UpdatedAt, article.PublishedAt, article.ID,
	)
	if err != nil {
		return fmt.Errorf("failed to update article: %w", err)
	}

	return nil
}

// DeleteArticle deletes an article by slug
func (db *Database) DeleteArticle(slug string) error {
	result, err := db.conn.Exec(`DELETE FROM articles WHERE slug = ?`, slug)
	if err != nil {
		return fmt.Errorf("failed to delete article: %w", err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("article not found: %s", slug)
	}
	return nil
}

// ListArticles lists articles with optional filters
func (db *Database) ListArticles(params *ArticleListParams) ([]*models.Article, error) {
	var args []interface{}
	var conditions []string

	baseQuery := `SELECT id, slug, title, author, content, tags, is_published, created_at, updated_at, published_at
	              FROM articles`

	if params != nil {
		if params.IsPublished != nil {
			conditions = append(conditions, "is_published = ?")
			if *params.IsPublished {
				args = append(args, 1)
			} else {
				args = append(args, 0)
			}
		}
		if params.Tag != nil && *params.Tag != "" {
			// Search for tag in JSON array
			// Using LIKE for simplicity with JSON array stored as string
			conditions = append(conditions, `tags LIKE ?`)
			args = append(args, "%\""+escapeLike(*params.Tag)+"\"%")
		}
	}

	query := baseQuery
	if len(conditions) > 0 {
		query += " WHERE " + strings.Join(conditions, " AND ")
	}
	query += " ORDER BY updated_at DESC"

	rows, err := db.conn.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to list articles: %w", err)
	}
	defer rows.Close()

	var articles []*models.Article
	for rows.Next() {
		var a models.Article
		var tagsJSON sql.NullString
		var isPublished int

		if err := rows.Scan(
			&a.ID, &a.Slug, &a.Title, &a.Author, &a.Content, &tagsJSON,
			&isPublished, &a.CreatedAt, &a.UpdatedAt, &a.PublishedAt,
		); err != nil {
			return nil, fmt.Errorf("failed to scan article: %w", err)
		}

		a.IsPublished = isPublished != 0
		if tagsJSON.Valid && tagsJSON.String != "" {
			if err := json.Unmarshal([]byte(tagsJSON.String), &a.Tags); err != nil {
				return nil, fmt.Errorf("failed to unmarshal tags: %w", err)
			}
		}
		if a.Tags == nil {
			a.Tags = []string{}
		}

		articles = append(articles, &a)
	}

	return articles, rows.Err()
}

// ListPublishedArticles returns only published articles (convenience method)
func (db *Database) ListPublishedArticles() ([]*models.Article, error) {
	published := true
	return db.ListArticles(&ArticleListParams{IsPublished: &published})
}

// ListArticleTags returns all unique tags with counts
func (db *Database) ListArticleTags(publishedOnly bool) ([]ArticleTagCount, error) {
	query := `SELECT tags FROM articles`
	if publishedOnly {
		query += " WHERE is_published = 1"
	}

	rows, err := db.conn.Query(query)
	if err != nil {
		return nil, fmt.Errorf("failed to query article tags: %w", err)
	}
	defer rows.Close()

	// Count tags across all articles
	tagCounts := make(map[string]int)
	for rows.Next() {
		var tagsJSON sql.NullString
		if err := rows.Scan(&tagsJSON); err != nil {
			return nil, fmt.Errorf("failed to scan tags: %w", err)
		}

		if tagsJSON.Valid && tagsJSON.String != "" {
			var tags []string
			if err := json.Unmarshal([]byte(tagsJSON.String), &tags); err != nil {
				continue // Skip malformed tags
			}
			for _, tag := range tags {
				tagCounts[tag]++
			}
		}
	}

	// Convert to slice and sort by count descending
	var result []ArticleTagCount
	for tag, count := range tagCounts {
		result = append(result, ArticleTagCount{Tag: tag, Count: count})
	}

	// Sort by count descending, then alphabetically
	for i := 0; i < len(result); i++ {
		for j := i + 1; j < len(result); j++ {
			if result[j].Count > result[i].Count ||
				(result[j].Count == result[i].Count && result[j].Tag < result[i].Tag) {
				result[i], result[j] = result[j], result[i]
			}
		}
	}

	return result, rows.Err()
}
