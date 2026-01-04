<script>
  import MarkdownRenderer from './MarkdownRenderer.svelte';

  let {
    value = '',
    placeholder = 'Write markdown content...',
    onchange = () => {},
    class: className = '',
    rows = 10
  } = $props();

  let activeTab = $state('write');
  let textareaValue = $state(value);

  // Sync external value changes
  $effect(() => {
    textareaValue = value;
  });

  function handleInput(event) {
    textareaValue = event.target.value;
    onchange(textareaValue);
  }

  function setTab(tab) {
    activeTab = tab;
  }
</script>

<div class="markdown-editor {className}">
  <div class="editor-tabs">
    <button
      type="button"
      class="editor-tab"
      class:active={activeTab === 'write'}
      onclick={() => setTab('write')}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
        <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
      </svg>
      Write
    </button>
    <button
      type="button"
      class="editor-tab"
      class:active={activeTab === 'preview'}
      onclick={() => setTab('preview')}
    >
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
        <circle cx="12" cy="12" r="3" />
      </svg>
      Preview
    </button>
  </div>

  <div class="editor-content">
    {#if activeTab === 'write'}
      <textarea
        class="editor-textarea"
        {placeholder}
        {rows}
        value={textareaValue}
        oninput={handleInput}
      ></textarea>
      <div class="editor-hint">
        Markdown supported: **bold**, *italic*, [links](url), - lists, ## headings
      </div>
    {:else}
      <div class="editor-preview">
        {#if textareaValue}
          <MarkdownRenderer content={textareaValue} />
        {:else}
          <p class="preview-empty">Nothing to preview</p>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .markdown-editor {
    border: 1px solid var(--color-border);
    border-radius: 0.5rem;
    overflow: hidden;
    background-color: var(--color-surface);
  }

  .editor-tabs {
    display: flex;
    gap: 0;
    background-color: var(--color-forest-50);
    border-bottom: 1px solid var(--color-border);
  }

  .editor-tab {
    display: inline-flex;
    align-items: center;
    gap: 0.375rem;
    padding: 0.625rem 1rem;
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-text-secondary);
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: all 0.15s ease;
  }

  .editor-tab:hover {
    color: var(--color-text-primary);
    background-color: var(--color-forest-100);
  }

  .editor-tab.active {
    color: var(--color-forest-700);
    border-bottom-color: var(--color-forest-600);
    background-color: var(--color-surface);
  }

  .editor-tab:focus-visible {
    outline: 2px solid var(--color-forest-500);
    outline-offset: -2px;
  }

  .editor-content {
    min-height: 200px;
  }

  .editor-textarea {
    width: 100%;
    min-height: 200px;
    padding: 1rem;
    font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    font-size: 0.875rem;
    line-height: 1.6;
    color: var(--color-text-primary);
    background-color: var(--color-surface);
    border: none;
    resize: vertical;
  }

  .editor-textarea:focus {
    outline: none;
  }

  .editor-textarea::placeholder {
    color: var(--color-text-tertiary);
  }

  .editor-hint {
    padding: 0.5rem 1rem;
    font-size: 0.75rem;
    color: var(--color-text-tertiary);
    background-color: var(--color-forest-50);
    border-top: 1px solid var(--color-border);
  }

  .editor-preview {
    padding: 1rem;
    min-height: 200px;
  }

  .preview-empty {
    color: var(--color-text-tertiary);
    font-style: italic;
  }
</style>
