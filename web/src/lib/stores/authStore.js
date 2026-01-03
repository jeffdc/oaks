// authStore.js - API key management with localStorage persistence
// Also manages connectivity state for edit permissions
import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import { checkApiHealth } from '../apiClient.js';
import { toast } from './toastStore.js';

const API_KEY_STORAGE_KEY = 'oak_api_key';
const API_KEY_TIMESTAMP_KEY = 'oak_api_key_timestamp';
const SESSION_TIMEOUT_KEY = 'oak_session_timeout_hours';
const DEFAULT_SESSION_TIMEOUT_HOURS = 24;
const HEALTH_CHECK_INTERVAL_MS = 60000; // 60 seconds
const SESSION_CHECK_INTERVAL_MS = 60000; // Check session validity every 60 seconds

/**
 * Get configured session timeout in milliseconds
 */
function getSessionTimeoutMs() {
  if (!browser) return DEFAULT_SESSION_TIMEOUT_HOURS * 60 * 60 * 1000;
  const hours = parseInt(localStorage.getItem(SESSION_TIMEOUT_KEY) || String(DEFAULT_SESSION_TIMEOUT_HOURS), 10);
  return hours * 60 * 60 * 1000;
}

/**
 * Check if the current session is still valid (not expired)
 */
function isSessionValid() {
  if (!browser) return true;
  const timestamp = localStorage.getItem(API_KEY_TIMESTAMP_KEY);
  if (!timestamp) return false; // No timestamp means invalid session

  const elapsed = Date.now() - parseInt(timestamp, 10);
  return elapsed < getSessionTimeoutMs();
}

/**
 * Get remaining session time in milliseconds
 * Returns 0 if session is expired or no session exists
 */
function getSessionTimeRemaining() {
  if (!browser) return 0;
  const timestamp = localStorage.getItem(API_KEY_TIMESTAMP_KEY);
  if (!timestamp) return 0;

  const elapsed = Date.now() - parseInt(timestamp, 10);
  const remaining = getSessionTimeoutMs() - elapsed;
  return Math.max(0, remaining);
}

/**
 * Get configured session timeout in hours
 */
export function getSessionTimeoutHours() {
  if (!browser) return DEFAULT_SESSION_TIMEOUT_HOURS;
  return parseInt(localStorage.getItem(SESSION_TIMEOUT_KEY) || String(DEFAULT_SESSION_TIMEOUT_HOURS), 10);
}

/**
 * Set session timeout in hours
 */
export function setSessionTimeoutHours(hours) {
  if (!browser) return;
  localStorage.setItem(SESSION_TIMEOUT_KEY, String(hours));
}

// Store for remaining session time (updated periodically)
export const sessionRemainingMs = writable(browser ? getSessionTimeRemaining() : 0);

function createAuthStore() {
  // Only access localStorage in browser (not during SSR)
  let initialValue = '';

  if (browser) {
    const storedKey = localStorage.getItem(API_KEY_STORAGE_KEY);
    if (storedKey) {
      // Check if session is still valid
      if (isSessionValid()) {
        initialValue = storedKey;
      } else {
        // Session expired - clear key and notify user
        localStorage.removeItem(API_KEY_STORAGE_KEY);
        localStorage.removeItem(API_KEY_TIMESTAMP_KEY);
        // Delay toast to ensure store is initialized
        setTimeout(() => {
          toast.warning('Session expired. Please re-enter your API key.', 5000);
        }, 100);
      }
    }
  }

  const apiKey = writable(initialValue);

  return {
    subscribe: apiKey.subscribe,
    setKey: (key) => {
      if (browser) {
        localStorage.setItem(API_KEY_STORAGE_KEY, key);
        localStorage.setItem(API_KEY_TIMESTAMP_KEY, String(Date.now()));
        sessionRemainingMs.set(getSessionTimeRemaining());
      }
      apiKey.set(key);
    },
    clearKey: () => {
      if (browser) {
        localStorage.removeItem(API_KEY_STORAGE_KEY);
        localStorage.removeItem(API_KEY_TIMESTAMP_KEY);
        sessionRemainingMs.set(0);
      }
      apiKey.set('');
    },
    /**
     * Reset session timestamp without changing the key
     * Extends the session for another timeout period
     */
    resetSessionTimestamp: () => {
      if (browser && localStorage.getItem(API_KEY_STORAGE_KEY)) {
        localStorage.setItem(API_KEY_TIMESTAMP_KEY, String(Date.now()));
        sessionRemainingMs.set(getSessionTimeRemaining());
      }
    },
    /**
     * Check if session is valid (not expired)
     */
    isSessionValid,
    /**
     * Get remaining session time in milliseconds
     */
    getSessionTimeRemaining
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

// Derived canEdit: authenticated and online
// Note: We don't check apiAvailable here - if API is down, operations will fail
// with appropriate error messages, which is more user-friendly than blocking the UI
export const canEdit = derived(
  [isAuthenticated, isOnline],
  ([$isAuthenticated, $isOnline]) => $isAuthenticated && $isOnline
);

/**
 * Get reason why editing is disabled
 * @returns {string|null} Reason string, or null if editing is allowed
 */
export function getCannotEditReason() {
  if (!get(isAuthenticated)) return 'Not authenticated';
  if (!get(isOnline)) return 'Offline';
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
    stopSessionChecks();
  } else {
    startHealthChecks();
    startSessionChecks();
    // Immediately check session when page becomes visible
    performSessionCheck();
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

// =============================================================================
// Session Timeout Management (browser-only)
// =============================================================================

let sessionCheckInterval = null;

function performSessionCheck() {
  // Only check if there's a key stored
  if (!localStorage.getItem(API_KEY_STORAGE_KEY)) return;

  // Update remaining time store
  sessionRemainingMs.set(getSessionTimeRemaining());

  // Check if session has expired
  if (!isSessionValid()) {
    authStore.clearKey();
    toast.warning('Session expired. Please re-enter your API key.', 5000);
  }
}

function startSessionChecks() {
  if (sessionCheckInterval) return;

  // Update remaining time immediately
  sessionRemainingMs.set(getSessionTimeRemaining());

  // Periodic checks
  sessionCheckInterval = setInterval(performSessionCheck, SESSION_CHECK_INTERVAL_MS);
}

function stopSessionChecks() {
  if (sessionCheckInterval) {
    clearInterval(sessionCheckInterval);
    sessionCheckInterval = null;
  }
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
    startSessionChecks();
  }
}
