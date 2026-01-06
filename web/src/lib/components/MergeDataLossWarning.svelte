<script>
  /**
   * MergeDataLossWarning - Warning component for data that will be lost during merge
   *
   * Displays a prominent warning when the user has unchecked sources that contain
   * synonym-only data, which will be permanently lost after the merge.
   */

  /** @type {{ uncheckedSources: string[] }} */
  let { uncheckedSources = [] } = $props();
</script>

{#if uncheckedSources.length > 0}
  <div class="warning-box data-loss-warning">
    <div class="warning-header">
      <svg class="warning-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
      </svg>
      <span class="warning-title">Data Loss Warning</span>
    </div>
    <p class="warning-description">
      The following source data will NOT be transferred and will be permanently lost:
    </p>
    <ul class="warning-list">
      {#each uncheckedSources as sourceName}
        <li>{sourceName}</li>
      {/each}
    </ul>
    <p class="warning-hint">
      To include this data, check the "Include this source" boxes above.
    </p>
  </div>
{/if}

<style>
  .warning-box {
    padding: 1rem 1.25rem;
    border-radius: 0.75rem;
    border-left: 4px solid;
  }

  .data-loss-warning {
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
    margin: 0 0 0.5rem 0;
  }

  .warning-list {
    margin: 0 0 0.75rem 0;
    padding-left: 1.5rem;
    list-style-type: disc;
  }

  .warning-list li {
    font-size: 0.875rem;
    font-weight: 500;
    color: var(--color-warning-text, #92400e);
    margin-bottom: 0.25rem;
  }

  .warning-hint {
    font-size: 0.8125rem;
    color: var(--color-warning-text, #92400e);
    opacity: 0.85;
    margin: 0;
  }
</style>
