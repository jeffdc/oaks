<script>
  import { goto } from '$app/navigation';
  import { page } from '$app/stores';
  import { base } from '$app/paths';
  import ArticleList from '$lib/components/ArticleList.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
  import { fetchArticles, fetchArticleTags } from '$lib/apiClient.js';
  import { toast } from '$lib/stores/toastStore.js';

  // State using Svelte 5 runes
  let articles = $state([]);
  let tags = $state([]);
  let isLoading = $state(true);
  let error = $state(null);
  let lastLoadedTag = $state(undefined);

  // Edit modal state
  let isCreateModalOpen = $state(false);
  let ArticleEditForm = $state(null);

  // Derived values
  let selectedTag = $derived($page.url.searchParams.get('tag'));

  // Effect to load data when tag changes (client-side only)
  $effect(() => {
    if (selectedTag !== lastLoadedTag) {
      lastLoadedTag = selectedTag;
      loadData();
    }
  });

  async function loadData() {
    isLoading = true;
    error = null;
    try {
      const [articlesData, tagsData] = await Promise.all([
        fetchArticles({ tag: selectedTag }),
        fetchArticleTags()
      ]);
      articles = articlesData || [];
      tags = tagsData || [];
    } catch (err) {
      console.error('Failed to load articles:', err);
      error = err.message || 'Failed to load articles';
      toast.error('Failed to load articles');
    } finally {
      isLoading = false;
    }
  }

  function handleTagSelect(tag) {
    const url = new URL($page.url);
    if (tag) {
      url.searchParams.set('tag', tag);
    } else {
      url.searchParams.delete('tag');
    }
    goto(url.toString(), { replaceState: true, noScroll: true });
  }

  async function handleCreate() {
    // Lazy load the form component to avoid SSR issues with MarkdownEditor
    if (!ArticleEditForm) {
      const module = await import('$lib/components/ArticleEditForm.svelte');
      ArticleEditForm = module.default;
    }
    isCreateModalOpen = true;
  }

  async function handleSaveNew(formData) {
    try {
      const { createArticle } = await import('$lib/apiClient.js');
      const result = await createArticle(formData);
      toast.success('Article created');
      isCreateModalOpen = false;
      // Navigate to the new article
      goto(`${base}/articles/${result.slug}/`);
      return null;
    } catch (err) {
      console.error('Failed to create article:', err);
      if (err.fieldErrors) {
        return err.fieldErrors;
      }
      toast.error(err.message || 'Failed to create article');
      return null;
    }
  }
</script>

<svelte:head>
  <title>Articles - Oak Compendium</title>
</svelte:head>

{#if isLoading}
  <div class="loading-container">
    <LoadingSpinner />
  </div>
{:else if error}
  <div class="error-container">
    <p>{error}</p>
    <button onclick={loadData}>Retry</button>
  </div>
{:else}
  <ArticleList
    {articles}
    {tags}
    {selectedTag}
    onTagSelect={handleTagSelect}
    onCreate={handleCreate}
  />
{/if}

<!-- Create Article Modal (lazy loaded) -->
{#if ArticleEditForm}
  <svelte:component
    this={ArticleEditForm}
    isOpen={isCreateModalOpen}
    onClose={() => isCreateModalOpen = false}
    onSave={handleSaveNew}
  />
{/if}

<style>
  .loading-container {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 50vh;
  }

  .error-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 50vh;
    gap: 1rem;
    color: var(--color-text-secondary);
  }

  .error-container button {
    padding: 0.5rem 1rem;
    color: white;
    background-color: var(--color-forest-600);
    border: none;
    border-radius: 0.5rem;
    cursor: pointer;
  }

  .error-container button:hover {
    background-color: var(--color-forest-700);
  }
</style>
