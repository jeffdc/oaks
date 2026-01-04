<script>
  import { base } from '$app/paths';
  import MarkdownRenderer from './MarkdownRenderer.svelte';
  import { canEdit } from '$lib/stores/authStore.js';

  /**
   * ArticleView - Displays a single article with full content
   *
   * Props:
   * - article: Article object
   * - onEdit: Callback when edit button is clicked (auth only)
   */

  /** @type {Object} Article to display */
  export let article = null;
  /** @type {() => void} Callback when edit button is clicked */
  export let onEdit = () => {};

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
</script>

{#if article}
  <article class="article-view">
    <!-- Back link -->
    <a href="{base}/articles/" class="back-link">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <polyline points="15 18 9 12 15 6"></polyline>
      </svg>
      Back to Articles
    </a>

    <!-- Article header -->
    <header class="article-header">
      {#if !article.is_published}
        <span class="draft-badge">Draft</span>
      {/if}
      <h1>{article.title}</h1>
      <div class="article-meta">
        <span class="author">By {article.author}</span>
        <span class="separator">|</span>
        <time datetime={article.published_at || article.updated_at}>
          {formatDate(article.published_at || article.updated_at)}
        </time>
        {#if $canEdit}
          <button class="edit-btn" onclick={onEdit} title="Edit article">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
            </svg>
          </button>
        {/if}
      </div>
      {#if article.tags && article.tags.length > 0}
        <div class="article-tags">
          {#each article.tags as tag}
            <a href="{base}/articles/?tag={encodeURIComponent(tag)}" class="tag">{tag}</a>
          {/each}
        </div>
      {/if}
    </header>

    <!-- Article content -->
    <div class="article-content">
      {#if article.content}
        <MarkdownRenderer content={article.content} />
      {:else}
        <p class="no-content">This article has no content yet.</p>
      {/if}
    </div>

    <!-- Footer with dates -->
    <footer class="article-footer">
      {#if article.published_at}
        <p>Published: {formatDate(article.published_at)}</p>
      {/if}
      <p>Last updated: {formatDate(article.updated_at)}</p>
    </footer>
  </article>
{:else}
  <div class="not-found">
    <h1>Article Not Found</h1>
    <p>The article you're looking for doesn't exist.</p>
    <a href="{base}/articles/" class="back-link">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
        <polyline points="15 18 9 12 15 6"></polyline>
      </svg>
      Back to Articles
    </a>
  </div>
{/if}

<style>
  .article-view {
    max-width: 800px;
    margin: 0 auto;
    padding: 2rem 1rem;
  }

  .back-link {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    margin-bottom: 1.5rem;
    font-size: 0.875rem;
    color: var(--color-forest-600);
    text-decoration: none;
  }

  .back-link:hover {
    color: var(--color-forest-700);
    text-decoration: underline;
  }

  .article-header {
    position: relative;
    margin-bottom: 2rem;
    padding-bottom: 1.5rem;
    border-bottom: 1px solid var(--color-border);
  }

  .draft-badge {
    display: inline-block;
    margin-bottom: 0.75rem;
    padding: 0.25rem 0.625rem;
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: var(--color-warning-text, #92400e);
    background-color: var(--color-warning-bg, #fef3c7);
    border-radius: 0.25rem;
  }

  h1 {
    margin: 0 0 0.75rem 0;
    font-size: 2rem;
    font-weight: 700;
    line-height: 1.25;
    color: var(--color-text-primary);
    font-family: var(--font-serif);
  }

  .article-meta {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9375rem;
    color: var(--color-text-secondary);
  }

  .separator {
    color: var(--color-border);
  }

  .edit-btn {
    margin-left: auto;
    padding: 0.375rem;
    color: var(--color-text-tertiary);
    background: none;
    border: none;
    border-radius: 0.25rem;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .edit-btn:hover {
    color: var(--color-forest-600);
    background-color: var(--color-forest-50);
  }

  .article-tags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.375rem;
    margin-top: 1rem;
  }

  .tag {
    padding: 0.25rem 0.625rem;
    font-size: 0.8125rem;
    color: var(--color-forest-700);
    background-color: var(--color-forest-50);
    border-radius: 0.375rem;
    text-decoration: none;
    transition: all 0.15s ease;
  }

  .tag:hover {
    background-color: var(--color-forest-100);
  }

  .article-content {
    font-size: 1.0625rem;
    line-height: 1.75;
    color: var(--color-text-primary);
  }

  .article-content :global(h2) {
    margin-top: 2rem;
    margin-bottom: 1rem;
    font-size: 1.5rem;
    font-weight: 600;
    font-family: var(--font-serif);
  }

  .article-content :global(h3) {
    margin-top: 1.5rem;
    margin-bottom: 0.75rem;
    font-size: 1.25rem;
    font-weight: 600;
  }

  .article-content :global(p) {
    margin-bottom: 1.25rem;
  }

  .article-content :global(ul),
  .article-content :global(ol) {
    margin-bottom: 1.25rem;
    padding-left: 1.5rem;
  }

  .article-content :global(li) {
    margin-bottom: 0.5rem;
  }

  .article-content :global(blockquote) {
    margin: 1.5rem 0;
    padding: 1rem 1.5rem;
    background-color: var(--color-forest-50);
    border-left: 4px solid var(--color-forest-400);
    color: var(--color-text-secondary);
  }

  .article-content :global(code) {
    padding: 0.125rem 0.375rem;
    font-size: 0.875em;
    font-family: var(--font-mono, monospace);
    background-color: var(--color-background);
    border-radius: 0.25rem;
  }

  .article-content :global(pre) {
    margin: 1.5rem 0;
    padding: 1rem;
    overflow-x: auto;
    background-color: var(--color-background);
    border-radius: 0.5rem;
  }

  .article-content :global(pre code) {
    padding: 0;
    background: none;
  }

  .no-content {
    padding: 2rem;
    text-align: center;
    color: var(--color-text-secondary);
    background-color: var(--color-background);
    border-radius: 0.5rem;
  }

  .article-footer {
    margin-top: 3rem;
    padding-top: 1rem;
    border-top: 1px solid var(--color-border);
    font-size: 0.8125rem;
    color: var(--color-text-tertiary);
  }

  .article-footer p {
    margin: 0.25rem 0;
  }

  .not-found {
    max-width: 800px;
    margin: 0 auto;
    padding: 4rem 1rem;
    text-align: center;
  }

  .not-found h1 {
    margin-bottom: 0.5rem;
    font-size: 1.5rem;
    color: var(--color-text-primary);
  }

  .not-found p {
    margin-bottom: 1.5rem;
    color: var(--color-text-secondary);
  }

  .not-found .back-link {
    justify-content: center;
  }

  /* Mobile */
  @media (max-width: 640px) {
    .article-view {
      padding: 1rem;
    }

    h1 {
      font-size: 1.5rem;
    }

    .article-meta {
      flex-wrap: wrap;
      font-size: 0.875rem;
    }

    .article-content {
      font-size: 1rem;
    }
  }
</style>
