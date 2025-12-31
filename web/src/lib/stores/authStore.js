// authStore.js - API key management with localStorage persistence
// Also manages connectivity state for edit permissions
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import { checkApiHealth } from '../apiClient.js';

const API_KEY_STORAGE_KEY = 'oak_api_key';
const HEALTH_CHECK_INTERVAL_MS = 60000; // 60 seconds

function createAuthStore() {
  // Only access localStorage in browser (not during SSR)
  const initialValue = browser ? localStorage.getItem(API_KEY_STORAGE_KEY) || '' : '';
  const apiKey = writable(initialValue);

  return {
    subscribe: apiKey.subscribe,
    setKey: (key) => {
      if (browser) {
        localStorage.setItem(API_KEY_STORAGE_KEY, key);
      }
      apiKey.set(key);
    },
    clearKey: () => {
      if (browser) {
        localStorage.removeItem(API_KEY_STORAGE_KEY);
      }
      apiKey.set('');
    }
  };
}

export const authStore = createAuthStore();
export const isAuthenticated = derived(authStore, $key => !!$key);

// =============================================================================
// Connectivity Stores
// =============================================================================

// Online status from navigator.onLine + events
export const isOnline = writable(browser ? navigator.onLine : true);

// API availability from periodic health checks
export const apiAvailable = writable(true); // Optimistic default

// Derived canEdit: all three conditions must be true
export const canEdit = derived(
  [isAuthenticated, isOnline, apiAvailable],
  ([$isAuthenticated, $isOnline, $apiAvailable]) =>
    $isAuthenticated && $isOnline && $apiAvailable
);

/**
 * Get reason why editing is disabled
 * @returns {string|null} Reason string, or null if editing is allowed
 */
export function getCannotEditReason() {
  if (!get(isAuthenticated)) return 'Not authenticated';
  if (!get(isOnline)) return 'Offline';
  if (!get(apiAvailable)) return 'API unavailable';
  return null;
}

// =============================================================================
// Connectivity Management (browser-only)
// =============================================================================

let healthCheckInterval = null;
let healthCheckInFlight = false;

async function performHealthCheck() {
  // Debounce: skip if already in flight
  if (healthCheckInFlight) return;

  healthCheckInFlight = true;
  try {
    const healthy = await checkApiHealth();
    apiAvailable.set(healthy);
  } catch {
    apiAvailable.set(false);
  } finally {
    healthCheckInFlight = false;
  }
}

function startHealthChecks() {
  if (healthCheckInterval) return;

  // Immediate check on start
  performHealthCheck();

  // Periodic checks
  healthCheckInterval = setInterval(performHealthCheck, HEALTH_CHECK_INTERVAL_MS);
}

function stopHealthChecks() {
  if (healthCheckInterval) {
    clearInterval(healthCheckInterval);
    healthCheckInterval = null;
  }
}

function handleVisibilityChange() {
  if (document.hidden) {
    stopHealthChecks();
  } else {
    startHealthChecks();
  }
}

function handleOnline() {
  isOnline.set(true);
  // Trigger immediate health check when coming online
  performHealthCheck();
}

function handleOffline() {
  isOnline.set(false);
  // API is definitely unavailable when offline
  apiAvailable.set(false);
}

// Initialize connectivity monitoring in browser
if (browser) {
  // Online/offline events
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);

  // Visibility API for pausing health checks
  document.addEventListener('visibilitychange', handleVisibilityChange);

  // Start health checks if page is visible
  if (!document.hidden) {
    startHealthChecks();
  }
}
