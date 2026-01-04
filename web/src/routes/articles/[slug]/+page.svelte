<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { base } from '$app/paths';
  import ArticleView from '$lib/components/ArticleView.svelte';
  import ArticleEditForm from '$lib/components/ArticleEditForm.svelte';
  import DeleteConfirmDialog from '$lib/components/DeleteConfirmDialog.svelte';
  import LoadingSpinner from '$lib/components/LoadingSpinner.svelte';
  import { fetchArticle, updateArticle, deleteArticle } from '$lib/apiClient.js';
  import { toast } from '$lib/stores/toastStore.js';

  let article = null;
  let isLoading = true;
  let error = null;

  // Edit modal state
  let isEditModalOpen = false;

  // Delete dialog state
  let isDeleteDialogOpen = false;
  let isDeleting = false;

  $: slug = $page.params.slug;

  async function loadArticle() {
    isLoading = true;
    error = null;
    try {
      article = await fetchArticle(slug);
    } catch (err) {
      console.error('Failed to load article:', err);
      if (err.status === 404) {
        article = null;
      } else {
        error = err.message || 'Failed to load article';
        toast.error('Failed to load article');
      }
    } finally {
      isLoading = false;
    }
  }

  onMount(loadArticle);

  // Reload when slug changes
  $: if (slug) {
    loadArticle();
  }

  function handleEdit() {
    isEditModalOpen = true;
  }

  async function handleSaveEdit(formData) {
    try {
      const result = await updateArticle(slug, formData);
      toast.success('Article updated');
      isEditModalOpen = false;

      // If slug changed, navigate to the new URL
      if (result.slug !== slug) {
        goto(`${base}/articles/${result.slug}/`, { replaceState: true });
      } else {
        // Reload article data
        article = result;
      }
      return null;
    } catch (err) {
      console.error('Failed to update article:', err);
      if (err.fieldErrors) {
        return err.fieldErrors;
      }
      toast.error(err.message || 'Failed to update article');
      return null;
    }
  }

  async function handleDelete() {
    isDeleting = true;
    try {
      await deleteArticle(slug);
      toast.success('Article deleted');
      isDeleteDialogOpen = false;
      goto(`${base}/articles/`);
    } catch (err) {
      console.error('Failed to delete article:', err);
      toast.error(err.message || 'Failed to delete article');
    } finally {
      isDeleting = false;
    }
  }
</script>

<svelte:head>
  <title>{article?.title || 'Article'} - Oak Compendium</title>
</svelte:head>

{#if isLoading}
  <div class="loading-container">
    <LoadingSpinner />
  </div>
{:else if error}
  <div class="error-container">
    <p>{error}</p>
    <button onclick={loadArticle}>Retry</button>
  </div>
{:else}
  <ArticleView
    {article}
    onEdit={handleEdit}
  />
{/if}

<!-- Edit Article Modal -->
{#if article}
  <ArticleEditForm
    {article}
    isOpen={isEditModalOpen}
    onClose={() => isEditModalOpen = false}
    onSave={handleSaveEdit}
    onDelete={() => isDeleteDialogOpen = true}
  />

  <!-- Delete Confirmation Dialog -->
  <DeleteConfirmDialog
    isOpen={isDeleteDialogOpen}
    entityType="Article"
    entityName={article.title}
    onClose={() => isDeleteDialogOpen = false}
    onConfirm={handleDelete}
    isDeleting={isDeleting}
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
