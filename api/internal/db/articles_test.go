package db

import (
	"testing"
	"time"

	"github.com/jeff/oaks/api/internal/models"
)

func TestGenerateSlug(t *testing.T) {
	tests := []struct {
		title    string
		expected string
	}{
		{"Hello World", "hello-world"},
		{"Oak Tree Guide", "oak-tree-guide"},
		{"UPPERCASE TITLE", "uppercase-title"},
		{"Multiple   Spaces", "multiple-spaces"},
		{"Special @#$% Characters!", "special-characters"},
		{"Hyphens-Already-Present", "hyphens-already-present"},
		{"Underscores_To_Hyphens", "underscores-to-hyphens"},
		{"123 Numbers Work", "123-numbers-work"},
		{"   Leading/Trailing   ", "leadingtrailing"},
		{"", ""},
		{"---Multiple---Hyphens---", "multiple-hyphens"},
	}

	for _, tt := range tests {
		t.Run(tt.title, func(t *testing.T) {
			result := GenerateSlug(tt.title)
			if result != tt.expected {
				t.Errorf("GenerateSlug(%q) = %q, want %q", tt.title, result, tt.expected)
			}
		})
	}
}

func TestArticleCRUD(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)
	article := &models.Article{
		Title:       "Test Article",
		Author:      "Test Author",
		Content:     strPtr("This is test content"),
		Tags:        []string{"oak", "guide"},
		IsPublished: false,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	// Insert
	err := db.InsertArticle(article)
	if err != nil {
		t.Fatalf("InsertArticle failed: %v", err)
	}
	if article.ID == 0 {
		t.Fatal("expected non-zero ID after insert")
	}
	if article.Slug != "test-article" {
		t.Errorf("expected slug 'test-article', got '%s'", article.Slug)
	}

	// Get by slug
	retrieved, err := db.GetArticle("test-article")
	if err != nil {
		t.Fatalf("GetArticle failed: %v", err)
	}
	if retrieved == nil {
		t.Fatal("expected article, got nil")
	}
	if retrieved.Title != "Test Article" {
		t.Errorf("expected 'Test Article', got '%s'", retrieved.Title)
	}
	if len(retrieved.Tags) != 2 {
		t.Errorf("expected 2 tags, got %d", len(retrieved.Tags))
	}

	// Get by ID
	byID, err := db.GetArticleByID(article.ID)
	if err != nil {
		t.Fatalf("GetArticleByID failed: %v", err)
	}
	if byID == nil {
		t.Fatal("expected article by ID, got nil")
	}
	if byID.Slug != "test-article" {
		t.Errorf("expected slug 'test-article', got '%s'", byID.Slug)
	}

	// Update
	article.Title = "Updated Article"
	article.Content = strPtr("Updated content")
	article.UpdatedAt = time.Now().Format(time.RFC3339)
	err = db.UpdateArticle(article)
	if err != nil {
		t.Fatalf("UpdateArticle failed: %v", err)
	}

	// Verify update (slug should change since title changed)
	updated, err := db.GetArticle("updated-article")
	if err != nil {
		t.Fatalf("GetArticle after update failed: %v", err)
	}
	if updated == nil {
		t.Fatal("expected updated article, got nil")
	}
	if updated.Title != "Updated Article" {
		t.Errorf("expected 'Updated Article', got '%s'", updated.Title)
	}

	// Delete
	err = db.DeleteArticle("updated-article")
	if err != nil {
		t.Fatalf("DeleteArticle failed: %v", err)
	}

	// Verify deleted
	deleted, err := db.GetArticle("updated-article")
	if err != nil {
		t.Fatalf("GetArticle after delete failed: %v", err)
	}
	if deleted != nil {
		t.Error("expected nil after delete")
	}
}

func TestArticleGetNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	article, err := db.GetArticle("non-existent")
	if err != nil {
		t.Fatalf("GetArticle failed: %v", err)
	}
	if article != nil {
		t.Errorf("expected nil for non-existent article, got %+v", article)
	}

	byID, err := db.GetArticleByID(99999)
	if err != nil {
		t.Fatalf("GetArticleByID failed: %v", err)
	}
	if byID != nil {
		t.Errorf("expected nil for non-existent ID, got %+v", byID)
	}
}

func TestArticleDeleteNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	err := db.DeleteArticle("non-existent")
	if err == nil {
		t.Fatal("expected error deleting non-existent article")
	}
}

func TestArticleSlugCollision(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)

	// Create first article
	article1 := &models.Article{
		Title:     "Oak Guide",
		Author:    "Author 1",
		CreatedAt: now,
		UpdatedAt: now,
	}
	err := db.InsertArticle(article1)
	if err != nil {
		t.Fatalf("InsertArticle 1 failed: %v", err)
	}
	if article1.Slug != "oak-guide" {
		t.Errorf("expected slug 'oak-guide', got '%s'", article1.Slug)
	}

	// Create second article with same title
	article2 := &models.Article{
		Title:     "Oak Guide",
		Author:    "Author 2",
		CreatedAt: now,
		UpdatedAt: now,
	}
	err = db.InsertArticle(article2)
	if err != nil {
		t.Fatalf("InsertArticle 2 failed: %v", err)
	}
	if article2.Slug != "oak-guide-2" {
		t.Errorf("expected slug 'oak-guide-2', got '%s'", article2.Slug)
	}

	// Create third article with same title
	article3 := &models.Article{
		Title:     "Oak Guide",
		Author:    "Author 3",
		CreatedAt: now,
		UpdatedAt: now,
	}
	err = db.InsertArticle(article3)
	if err != nil {
		t.Fatalf("InsertArticle 3 failed: %v", err)
	}
	if article3.Slug != "oak-guide-3" {
		t.Errorf("expected slug 'oak-guide-3', got '%s'", article3.Slug)
	}
}

func TestArticleSlugNotChangedOnSameTitleUpdate(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)
	article := &models.Article{
		Title:     "Original Title",
		Author:    "Author",
		CreatedAt: now,
		UpdatedAt: now,
	}

	err := db.InsertArticle(article)
	if err != nil {
		t.Fatalf("InsertArticle failed: %v", err)
	}
	originalSlug := article.Slug

	// Update without changing title
	article.Content = strPtr("New content")
	article.UpdatedAt = time.Now().Format(time.RFC3339)
	err = db.UpdateArticle(article)
	if err != nil {
		t.Fatalf("UpdateArticle failed: %v", err)
	}

	// Slug should remain the same
	if article.Slug != originalSlug {
		t.Errorf("slug should not change when title unchanged: expected %s, got %s", originalSlug, article.Slug)
	}
}

func TestArticleListAll(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)
	articles := []*models.Article{
		{Title: "Article 1", Author: "Author", CreatedAt: now, UpdatedAt: now},
		{Title: "Article 2", Author: "Author", CreatedAt: now, UpdatedAt: now},
		{Title: "Article 3", Author: "Author", CreatedAt: now, UpdatedAt: now},
	}

	for _, a := range articles {
		if err := db.InsertArticle(a); err != nil {
			t.Fatalf("InsertArticle failed: %v", err)
		}
	}

	list, err := db.ListArticles(nil)
	if err != nil {
		t.Fatalf("ListArticles failed: %v", err)
	}
	if len(list) != 3 {
		t.Errorf("expected 3 articles, got %d", len(list))
	}
}

func TestArticleListByPublished(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)
	publishedAt := now

	// Create mix of published and draft articles
	draft := &models.Article{Title: "Draft", Author: "A", IsPublished: false, CreatedAt: now, UpdatedAt: now}
	published1 := &models.Article{Title: "Published 1", Author: "A", IsPublished: true, CreatedAt: now, UpdatedAt: now, PublishedAt: &publishedAt}
	published2 := &models.Article{Title: "Published 2", Author: "A", IsPublished: true, CreatedAt: now, UpdatedAt: now, PublishedAt: &publishedAt}

	for _, a := range []*models.Article{draft, published1, published2} {
		if err := db.InsertArticle(a); err != nil {
			t.Fatalf("InsertArticle failed: %v", err)
		}
	}

	// List only published
	isPublished := true
	list, err := db.ListArticles(&ArticleListParams{IsPublished: &isPublished})
	if err != nil {
		t.Fatalf("ListArticles (published) failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 published articles, got %d", len(list))
	}

	// List only drafts
	isDraft := false
	list, err = db.ListArticles(&ArticleListParams{IsPublished: &isDraft})
	if err != nil {
		t.Fatalf("ListArticles (draft) failed: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("expected 1 draft article, got %d", len(list))
	}

	// Test convenience method
	publishedList, err := db.ListPublishedArticles()
	if err != nil {
		t.Fatalf("ListPublishedArticles failed: %v", err)
	}
	if len(publishedList) != 2 {
		t.Errorf("expected 2 from ListPublishedArticles, got %d", len(publishedList))
	}
}

func TestArticleListByTag(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)

	// Create articles with different tags
	article1 := &models.Article{Title: "Oak Basics", Author: "A", Tags: []string{"oak", "beginner"}, CreatedAt: now, UpdatedAt: now}
	article2 := &models.Article{Title: "Oak Expert", Author: "A", Tags: []string{"oak", "advanced"}, CreatedAt: now, UpdatedAt: now}
	article3 := &models.Article{Title: "Maple Guide", Author: "A", Tags: []string{"maple", "beginner"}, CreatedAt: now, UpdatedAt: now}

	for _, a := range []*models.Article{article1, article2, article3} {
		if err := db.InsertArticle(a); err != nil {
			t.Fatalf("InsertArticle failed: %v", err)
		}
	}

	// Filter by "oak" tag
	oakTag := "oak"
	list, err := db.ListArticles(&ArticleListParams{Tag: &oakTag})
	if err != nil {
		t.Fatalf("ListArticles (tag=oak) failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 oak articles, got %d", len(list))
	}

	// Filter by "beginner" tag
	beginnerTag := "beginner"
	list, err = db.ListArticles(&ArticleListParams{Tag: &beginnerTag})
	if err != nil {
		t.Fatalf("ListArticles (tag=beginner) failed: %v", err)
	}
	if len(list) != 2 {
		t.Errorf("expected 2 beginner articles, got %d", len(list))
	}

	// Filter by non-existent tag
	noTag := "nonexistent"
	list, err = db.ListArticles(&ArticleListParams{Tag: &noTag})
	if err != nil {
		t.Fatalf("ListArticles (tag=nonexistent) failed: %v", err)
	}
	if len(list) != 0 {
		t.Errorf("expected 0 articles for non-existent tag, got %d", len(list))
	}
}

func TestArticleListCombinedFilters(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)

	// Create mix of articles
	draft := &models.Article{Title: "Draft Oak", Author: "A", Tags: []string{"oak"}, IsPublished: false, CreatedAt: now, UpdatedAt: now}
	publishedOak := &models.Article{Title: "Published Oak", Author: "A", Tags: []string{"oak"}, IsPublished: true, CreatedAt: now, UpdatedAt: now}
	publishedMaple := &models.Article{Title: "Published Maple", Author: "A", Tags: []string{"maple"}, IsPublished: true, CreatedAt: now, UpdatedAt: now}

	for _, a := range []*models.Article{draft, publishedOak, publishedMaple} {
		if err := db.InsertArticle(a); err != nil {
			t.Fatalf("InsertArticle failed: %v", err)
		}
	}

	// Filter by published AND oak tag
	isPublished := true
	oakTag := "oak"
	list, err := db.ListArticles(&ArticleListParams{IsPublished: &isPublished, Tag: &oakTag})
	if err != nil {
		t.Fatalf("ListArticles (combined filters) failed: %v", err)
	}
	if len(list) != 1 {
		t.Errorf("expected 1 published oak article, got %d", len(list))
	}
	if list[0].Title != "Published Oak" {
		t.Errorf("expected 'Published Oak', got '%s'", list[0].Title)
	}
}

func TestArticleTagCounts(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)

	// Create articles with various tags
	articles := []*models.Article{
		{Title: "Article 1", Author: "A", Tags: []string{"oak", "guide"}, IsPublished: true, CreatedAt: now, UpdatedAt: now},
		{Title: "Article 2", Author: "A", Tags: []string{"oak", "reference"}, IsPublished: true, CreatedAt: now, UpdatedAt: now},
		{Title: "Article 3", Author: "A", Tags: []string{"oak"}, IsPublished: false, CreatedAt: now, UpdatedAt: now},
		{Title: "Article 4", Author: "A", Tags: []string{"maple"}, IsPublished: true, CreatedAt: now, UpdatedAt: now},
	}

	for _, a := range articles {
		if err := db.InsertArticle(a); err != nil {
			t.Fatalf("InsertArticle failed: %v", err)
		}
	}

	// Get tag counts for published only
	counts, err := db.ListArticleTags(true)
	if err != nil {
		t.Fatalf("ListArticleTags (published) failed: %v", err)
	}

	// Should have oak(2), guide(1), reference(1), maple(1)
	tagMap := make(map[string]int)
	for _, tc := range counts {
		tagMap[tc.Tag] = tc.Count
	}

	if tagMap["oak"] != 2 {
		t.Errorf("expected oak count 2, got %d", tagMap["oak"])
	}
	if tagMap["guide"] != 1 {
		t.Errorf("expected guide count 1, got %d", tagMap["guide"])
	}

	// Get tag counts for all articles (including drafts)
	allCounts, err := db.ListArticleTags(false)
	if err != nil {
		t.Fatalf("ListArticleTags (all) failed: %v", err)
	}

	allTagMap := make(map[string]int)
	for _, tc := range allCounts {
		allTagMap[tc.Tag] = tc.Count
	}

	if allTagMap["oak"] != 3 {
		t.Errorf("expected oak count 3 (including draft), got %d", allTagMap["oak"])
	}
}

func TestArticleEmptyTags(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	now := time.Now().Format(time.RFC3339)
	article := &models.Article{
		Title:     "No Tags",
		Author:    "Author",
		Tags:      nil,
		CreatedAt: now,
		UpdatedAt: now,
	}

	err := db.InsertArticle(article)
	if err != nil {
		t.Fatalf("InsertArticle failed: %v", err)
	}

	retrieved, err := db.GetArticle(article.Slug)
	if err != nil {
		t.Fatalf("GetArticle failed: %v", err)
	}

	// Tags should be empty slice, not nil
	if retrieved.Tags == nil {
		t.Error("expected empty slice for tags, got nil")
	}
	if len(retrieved.Tags) != 0 {
		t.Errorf("expected 0 tags, got %d", len(retrieved.Tags))
	}
}

func TestGenerateUniqueSlugEmptyTitle(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	// Empty title should default to "article"
	slug, err := db.GenerateUniqueSlug("", 0)
	if err != nil {
		t.Fatalf("GenerateUniqueSlug failed: %v", err)
	}
	if slug != "article" {
		t.Errorf("expected 'article' for empty title, got '%s'", slug)
	}
}

func TestArticleUpdateNonExistent(t *testing.T) {
	db, cleanup := testDB(t)
	defer cleanup()

	article := &models.Article{
		ID:        99999,
		Title:     "Non-existent",
		Author:    "Author",
		CreatedAt: time.Now().Format(time.RFC3339),
		UpdatedAt: time.Now().Format(time.RFC3339),
	}

	err := db.UpdateArticle(article)
	if err == nil {
		t.Fatal("expected error updating non-existent article")
	}
}
