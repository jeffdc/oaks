<script>
  import { base } from '$app/paths';
  import { canEdit } from '$lib/stores/authStore.js';

  /**
   * ArticleList - Displays a list of articles with tag filtering
   *
   * Props:
   * - articles: Array of article objects
   * - selectedTag: Currently selected tag filter (or null)
   * - tags: Array of {tag, count} objects for filter chips
   * - onTagSelect: Callback when a tag is selected/deselected
   * - onCreate: Callback when "New Article" is clicked (auth only)
   */

  /** @type {Array<Object>} List of articles to display */
  export let articles = [];
  /** @type {string|null} Currently selected tag filter */
  export let selectedTag = null;
  /** @type {Array<{tag: string, count: number}>} Available tags with counts */
  export let tags = [];
  /** @type {(tag: string|null) => void} Callback when tag filter changes */
  export let onTagSelect = () => {};
  /** @type {() => void} Callback when create button is clicked */
  export let onCreate = () => {};

  /**
   * Format a date string for display
   * @param {string} dateStr - ISO 8601 date string
   * @returns {string} Formatted date
   */
  function formatDate(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  }

  /**
   * Get a preview of the article content
   * @param {string|null} content - Article markdown content
   * @returns {string} First 150 chars of content, stripped of markdown
   */
  function getPreview(content) {
    if (!content) return '';
    // Strip markdown formatting for preview
    const stripped = content
      .replace(/^#{1,6}\s+/gm, '')  // Remove headings
      .replace(/\*\*([^*]+)\*\*/g, '$1')  // Remove bold
      .replace(/\*([^*]+)\*/g, '$1')  // Remove italic
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')  // Remove links
      .replace(/`([^`]+)`/g, '$1')  // Remove inline code
      .replace(/```[\s\S]*?```/g, '')  // Remove code blocks
      .replace(/\n+/g, ' ')  // Replace newlines with spaces
      .trim();
    return stripped.length > 150 ? stripped.substring(0, 150) + '...' : stripped;
  }
</script>

<div class="article-list">
  <!-- Header with title and create button -->
  <div class="header">
    <h1>Articles</h1>
    {#if $canEdit}
      <button class="btn btn-primary" onclick={onCreate}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <line x1="12" y1="5" x2="12" y2="19"></line>
          <line x1="5" y1="12" x2="19" y2="12"></line>
        </svg>
        New Article
      </button>
    {/if}
  </div>

  <!-- Tag filter chips -->
  {#if tags.length > 0}
    <div class="tag-filters">
      <button
        class="tag-chip"
        class:active={selectedTag === null}
        onclick={() => onTagSelect(null)}
      >
        All
      </button>
      {#each tags as { tag, count }}
        <button
          class="tag-chip"
          class:active={selectedTag === tag}
          onclick={() => onTagSelect(selectedTag === tag ? null : tag)}
        >
          {tag} <span class="count">({count})</span>
        </button>
      {/each}
    </div>
  {/if}

  <!-- Article cards -->
  {#if articles.length === 0}
    <div class="empty-state">
      <p>No articles found{selectedTag ? ` with tag "${selectedTag}"` : ''}.</p>
    </div>
  {:else}
    <div class="articles-grid">
      {#each articles as article}
        <a href="{base}/articles/{article.slug}/" class="article-card" class:draft={!article.is_published}>
          {#if !article.is_published}
            <span class="draft-badge">Draft</span>
          {/if}
          <h2 class="article-title">{article.title}</h2>
          <div class="article-meta">
            <span class="author">{article.author}</span>
            <span class="separator">|</span>
            <span class="date">{formatDate(article.published_at || article.updated_at)}</span>
          </div>
          {#if article.tags && article.tags.length > 0}
            <div class="article-tags">
              {#each article.tags as tag}
                <span class="tag">{tag}</span>
              {/each}
            </div>
          {/if}
          <p class="article-preview">{getPreview(article.content)}</p>
        </a>
      {/each}
    </div>
  {/if}
</div>

<style>
  .article-list {
    max-width: 900px;
    margin: 0 auto;
    padding: 2rem 1rem;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1.5rem;
  }

  h1 {
    margin: 0;
    font-size: 1.75rem;
    font-weight: 600;
    color: var(--color-text-primary);
    font-family: var(--font-serif);
  }

  .btn {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 1rem;
    font-size: 0.875rem;
    font-weight: 500;
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
    transition: background-color 0.15s ease;
  }

  .btn-primary {
    color: white;
    background-color: var(--color-forest-600);
  }

  .btn-primary:hover {
    background-color: var(--color-forest-700);
  }

  .tag-filters {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-bottom: 1.5rem;
  }

  .tag-chip {
    display: inline-flex;
    align-items: center;
    gap: 0.25rem;
    padding: 0.375rem 0.75rem;
    font-size: 0.8125rem;
    font-weight: 500;
    color: var(--color-text-secondary);
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 9999px;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .tag-chip:hover {
    background-color: var(--color-forest-50);
    border-color: var(--color-forest-200);
    color: var(--color-forest-700);
  }

  .tag-chip.active {
    background-color: var(--color-forest-600);
    border-color: var(--color-forest-600);
    color: white;
  }

  .tag-chip .count {
    opacity: 0.7;
  }

  .empty-state {
    padding: 3rem;
    text-align: center;
    color: var(--color-text-secondary);
    background-color: var(--color-surface);
    border-radius: 0.5rem;
    border: 1px solid var(--color-border);
  }

  .articles-grid {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .article-card {
    display: block;
    position: relative;
    padding: 1.25rem 1.5rem;
    background-color: var(--color-surface);
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    text-decoration: none;
    transition: all 0.15s ease;
  }

  .article-card:hover {
    border-color: var(--color-forest-300);
    box-shadow: var(--shadow-md);
  }

  .article-card.draft {
    border-left: 3px solid var(--color-warning, #f59e0b);
  }

  .draft-badge {
    position: absolute;
    top: 0.75rem;
    right: 0.75rem;
    padding: 0.125rem 0.5rem;
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-warning-text, #92400e);
    background-color: var(--color-warning-bg, #fef3c7);
    border-radius: 0.25rem;
  }

  .article-title {
    margin: 0 0 0.5rem 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--color-text-primary);
    font-family: var(--font-serif);
  }

  .article-meta {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.75rem;
    font-size: 0.8125rem;
    color: var(--color-text-secondary);
  }

  .separator {
    color: var(--color-border);
  }

  .article-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.375rem;
    margin-bottom: 0.75rem;
  }

  .tag {
    padding: 0.125rem 0.5rem;
    font-size: 0.75rem;
    color: var(--color-forest-700);
    background-color: var(--color-forest-50);
    border-radius: 0.25rem;
  }

  .article-preview {
    margin: 0;
    font-size: 0.9375rem;
    line-height: 1.5;
    color: var(--color-text-secondary);
  }

  /* Mobile */
  @media (max-width: 640px) {
    .article-list {
      padding: 1rem;
    }

    .header {
      flex-direction: column;
      align-items: flex-start;
      gap: 1rem;
    }

    h1 {
      font-size: 1.5rem;
    }

    .tag-filters {
      overflow-x: auto;
      flex-wrap: nowrap;
      -webkit-overflow-scrolling: touch;
      padding-bottom: 0.5rem;
    }

    .article-card {
      padding: 1rem;
    }

    .article-title {
      font-size: 1rem;
      padding-right: 3rem; /* Make room for draft badge */
    }
  }
</style>
