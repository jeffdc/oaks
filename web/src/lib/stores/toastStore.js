import { writable } from 'svelte/store';

/**
 * Toast notification store
 *
 * Usage:
 *   import { toast } from '$lib/stores/toastStore.js';
 *   toast.success('Species updated successfully');
 *   toast.error('Failed to save: ' + error.message);
 *   toast.warning('Connection lost. Changes preserved.');
 *   toast.info('Syncing with server...');
 */

// Internal store for toast messages
const { subscribe, update } = writable([]);

let nextId = 1;

/**
 * Add a toast notification
 * @param {string} message - The message to display
 * @param {string} type - Toast type: 'success', 'error', 'warning', 'info'
 * @param {number} duration - Auto-dismiss duration in ms (0 = no auto-dismiss)
 * @returns {number} Toast ID for manual dismissal
 */
function addToast(message, type = 'info', duration = 3000) {
  const id = nextId++;

  update(toasts => [
    ...toasts,
    { id, message, type, duration }
  ]);

  // Auto-dismiss after duration (if duration > 0)
  if (duration > 0) {
    setTimeout(() => {
      dismiss(id);
    }, duration);
  }

  return id;
}

/**
 * Dismiss a toast by ID
 * @param {number} id - Toast ID to dismiss
 */
function dismiss(id) {
  update(toasts => toasts.filter(t => t.id !== id));
}

/**
 * Dismiss all toasts
 */
function dismissAll() {
  update(() => []);
}

// Public API
export const toast = {
  subscribe,

  /**
   * Show a success toast (green, checkmark)
   * @param {string} message
   * @param {number} duration - Default 3000ms
   */
  success: (message, duration = 3000) => addToast(message, 'success', duration),

  /**
   * Show an error toast (red, X icon)
   * @param {string} message
   * @param {number} duration - Default 5000ms (longer for errors)
   */
  error: (message, duration = 5000) => addToast(message, 'error', duration),

  /**
   * Show a warning toast (yellow, warning icon)
   * @param {string} message
   * @param {number} duration - Default 4000ms
   */
  warning: (message, duration = 4000) => addToast(message, 'warning', duration),

  /**
   * Show an info toast (blue, info icon)
   * @param {string} message
   * @param {number} duration - Default 3000ms
   */
  info: (message, duration = 3000) => addToast(message, 'info', duration),

  /**
   * Dismiss a specific toast
   * @param {number} id
   */
  dismiss,

  /**
   * Dismiss all toasts
   */
  dismissAll
};
