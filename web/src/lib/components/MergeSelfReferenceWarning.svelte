<script>
  /**
   * MergeSelfReferenceWarning - Warning component for self-references after merge
   *
   * Detects and displays warnings when the target species would reference itself
   * after the synonym is merged into it.
   */

  /**
   * @typedef {Object} SelfReferenceIssue
   * @property {string} field - The field name containing the self-reference
   * @property {string} value - The value that would become a self-reference
   * @property {string} hint - Guidance for fixing the issue
   */

  /** @type {{ issues: SelfReferenceIssue[] }} */
  let { issues = [] } = $props();
</script>

{#if issues.length > 0}
  <div class="warning-box self-reference-warning">
    <div class="warning-header">
      <svg class="warning-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
      </svg>
      <span class="warning-title">Self-Reference Warning</span>
    </div>
    <p class="warning-description">
      After merge, this species would reference itself:
    </p>
    <ul class="issue-list">
      {#each issues as issue}
        <li class="issue-item">
          <span class="issue-detail">
            "<strong>{issue.field}</strong>" contains "<em>{issue.value}</em>" - will become self-reference
          </span>
          <span class="issue-hint">{issue.hint}</span>
        </li>
      {/each}
    </ul>
  </div>
{/if}

<style>
  .warning-box {
    padding: 1rem 1.25rem;
    border-radius: 0.75rem;
    border-left: 4px solid;
  }

  .self-reference-warning {
    background-color: var(--color-warning-bg, #fef3c7);
    border-left-color: var(--color-warning, #f59e0b);
  }

  .warning-header {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-bottom: 0.75rem;
  }

  .warning-icon {
    width: 1.25rem;
    height: 1.25rem;
    color: var(--color-warning, #f59e0b);
    flex-shrink: 0;
  }

  .warning-title {
    font-size: 0.9375rem;
    font-weight: 600;
    color: var(--color-warning-text, #92400e);
  }

  .warning-description {
    font-size: 0.875rem;
    color: var(--color-warning-text, #92400e);
    margin: 0 0 0.75rem 0;
  }

  .issue-list {
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .issue-item {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    padding: 0.75rem;
    background-color: rgba(255, 255, 255, 0.5);
    border-radius: 0.5rem;
    margin-bottom: 0.5rem;
  }

  .issue-item:last-child {
    margin-bottom: 0;
  }

  .issue-detail {
    font-size: 0.875rem;
    color: var(--color-warning-text, #92400e);
  }

  .issue-detail strong {
    font-weight: 600;
  }

  .issue-detail em {
    font-style: italic;
    font-family: var(--font-serif);
  }

  .issue-hint {
    font-size: 0.8125rem;
    color: var(--color-warning-text, #92400e);
    opacity: 0.85;
    padding-left: 0.5rem;
    border-left: 2px solid var(--color-warning, #f59e0b);
  }
</style>
