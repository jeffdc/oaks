<script>
  import { marked } from 'marked';
  import DOMPurify from 'dompurify';

  let { content = '', class: className = '' } = $props();

  // Configure marked for GitHub-flavored markdown
  marked.setOptions({
    gfm: true,
    breaks: true,
  });

  // Render markdown to sanitized HTML
  let renderedHtml = $derived.by(() => {
    if (!content) return '';
    // marked.parse returns string synchronously when async option is false (default)
    const rawHtml = /** @type {string} */ (marked.parse(content));
    return DOMPurify.sanitize(rawHtml);
  });
</script>

{#if content}
  <div class="prose-content {className}">
    {@html renderedHtml}
  </div>
{/if}

<style>
  /* Component inherits from .prose-content in app.css */
</style>
