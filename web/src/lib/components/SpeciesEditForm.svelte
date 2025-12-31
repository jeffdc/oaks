<script>
  import EditModal from './EditModal.svelte';

  /** @type {Object} Species object to edit */
  export let species;
  /** @type {boolean} Whether the modal is open */
  export let isOpen;
  /** @type {() => void} Handler called when modal should close */
  export let onClose;
  /** @type {(species: Object) => void} Handler called when save completes */
  export let onSave;

  let isSaving = false;

  async function handleSave() {
    isSaving = true;
    try {
      // TODO: Implement actual save logic via API
      await onSave(species);
      onClose();
    } catch (error) {
      console.error('Failed to save species:', error);
    } finally {
      isSaving = false;
    }
  }
</script>

<EditModal
  title="Edit Species: Quercus {species?.name || ''}"
  {isOpen}
  {isSaving}
  {onClose}
  onSave={handleSave}
>
  <p style="color: var(--color-text-secondary); text-align: center; padding: 2rem;">
    Species editing form coming soon.
  </p>
</EditModal>
