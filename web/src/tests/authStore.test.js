import { describe, it, expect, beforeEach, vi } from 'vitest';
import { get } from 'svelte/store';

// Mock SvelteKit environment - must be before authStore import
vi.mock('$app/environment', () => ({
  browser: true
}));

// Mock apiClient before importing authStore
vi.mock('../lib/apiClient.js', () => ({
  checkApiHealth: vi.fn().mockResolvedValue(true)
}));

// Mock toastStore to prevent side effects in tests
vi.mock('../lib/stores/toastStore.js', () => ({
  toast: {
    warning: vi.fn(),
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn()
  }
}));

// Mock localStorage before importing the store
let mockStore = {};
const localStorageMock = {
  getItem: vi.fn((key) => mockStore[key] ?? null),
  setItem: vi.fn((key, value) => { mockStore[key] = value; }),
  removeItem: vi.fn((key) => { delete mockStore[key]; }),
  clear: vi.fn(() => { mockStore = {}; }),
  // Helper to set multiple values for session tests
  setStore: (newStore) => { mockStore = { ...newStore }; }
};

/**
 * Helper to set up a valid session with API key and timestamp
 * @param {string} apiKey - The API key to store
 */
function setupValidSession(apiKey) {
  const now = Date.now();
  mockStore = {
    'oak_api_key': apiKey,
    'oak_api_key_timestamp': String(now)
  };
}

Object.defineProperty(global, 'localStorage', {
  value: localStorageMock,
  writable: true
});

// Mock navigator.onLine for connectivity tests
Object.defineProperty(global.navigator, 'onLine', {
  value: true,
  writable: true,
  configurable: true
});

// Mock document.hidden for visibility tests
Object.defineProperty(document, 'hidden', {
  value: false,
  writable: true,
  configurable: true
});

describe('authStore', () => {
  beforeEach(async () => {
    // Clear mocks and localStorage between tests
    vi.clearAllMocks();
    mockStore = {};

    // Re-import the module to get fresh store state
    vi.resetModules();
  });

  it('initializes with empty string when localStorage is empty', async () => {
    // mockStore is already empty from beforeEach
    const { authStore } = await import('../lib/stores/authStore.js');
    expect(get(authStore)).toBe('');
  });

  it('initializes with stored key from localStorage when session is valid', async () => {
    setupValidSession('stored-api-key');
    const { authStore } = await import('../lib/stores/authStore.js');
    expect(get(authStore)).toBe('stored-api-key');
  });

  it('clears expired session on initialization', async () => {
    // Set up an expired session (timestamp from 25 hours ago)
    const expiredTimestamp = Date.now() - (25 * 60 * 60 * 1000);
    localStorageMock.setStore({
      'oak_api_key': 'expired-key',
      'oak_api_key_timestamp': String(expiredTimestamp)
    });
    const { authStore } = await import('../lib/stores/authStore.js');
    expect(get(authStore)).toBe('');
  });

  it('setKey updates store and persists to localStorage', async () => {
    // mockStore is already empty from beforeEach
    const { authStore } = await import('../lib/stores/authStore.js');

    authStore.setKey('new-api-key');

    expect(get(authStore)).toBe('new-api-key');
    expect(localStorageMock.setItem).toHaveBeenCalledWith('oak_api_key', 'new-api-key');
  });

  it('clearKey clears store and removes from localStorage', async () => {
    setupValidSession('existing-key');
    const { authStore } = await import('../lib/stores/authStore.js');

    authStore.clearKey();

    expect(get(authStore)).toBe('');
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('oak_api_key');
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('oak_api_key_timestamp');
  });

  describe('isAuthenticated derived store', () => {
    it('returns false when no key is set', async () => {
      // mockStore is already empty from beforeEach
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(false);
    });

    it('returns false when key is empty string', async () => {
      mockStore = { 'oak_api_key': '' };
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(false);
    });

    it('returns true when key is set with valid session', async () => {
      setupValidSession('valid-api-key');
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(true);
    });

    it('updates reactively when key is set', async () => {
      // mockStore is already empty from beforeEach
      const { authStore, isAuthenticated } = await import('../lib/stores/authStore.js');

      expect(get(isAuthenticated)).toBe(false);

      authStore.setKey('new-key');
      expect(get(isAuthenticated)).toBe(true);
    });

    it('updates reactively when key is cleared', async () => {
      setupValidSession('existing-key');
      const { authStore, isAuthenticated } = await import('../lib/stores/authStore.js');

      expect(get(isAuthenticated)).toBe(true);

      authStore.clearKey();
      expect(get(isAuthenticated)).toBe(false);
    });
  });

  describe('connectivity stores', () => {
    it('isOnline initializes from navigator.onLine', async () => {
      const { isOnline } = await import('../lib/stores/authStore.js');
      expect(get(isOnline)).toBe(true);
    });

    it('apiAvailable defaults to true (optimistic)', async () => {
      const { apiAvailable } = await import('../lib/stores/authStore.js');
      expect(get(apiAvailable)).toBe(true);
    });

    describe('canEdit derived store', () => {
      it('returns true when authenticated, online, and API available', async () => {
        setupValidSession('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(true);
      });

      it('returns false when not authenticated', async () => {
        localStorageMock.setStore({});
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(false);
      });

      it('returns false when offline', async () => {
        setupValidSession('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(false);
      });

      it('returns true when API unavailable (API errors handled at request time)', async () => {
        // Note: canEdit intentionally doesn't check apiAvailable
        // API failures are handled with error messages, not by blocking the UI
        setupValidSession('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(get(canEdit)).toBe(true);
      });
    });

    describe('getCannotEditReason', () => {
      it('returns null when can edit', async () => {
        setupValidSession('valid-api-key');
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(getCannotEditReason()).toBe(null);
      });

      it('returns "Not authenticated" when no API key', async () => {
        localStorageMock.setStore({});
        const { getCannotEditReason } = await import('../lib/stores/authStore.js');

        expect(getCannotEditReason()).toBe('Not authenticated');
      });

      it('returns "Offline" when offline', async () => {
        setupValidSession('valid-api-key');
        const { getCannotEditReason, isOnline } = await import('../lib/stores/authStore.js');

        isOnline.set(false);

        expect(getCannotEditReason()).toBe('Offline');
      });

      it('returns null when API is down (errors handled at request time)', async () => {
        // Note: getCannotEditReason intentionally doesn't check apiAvailable
        // API failures are handled with error messages when requests fail
        setupValidSession('valid-api-key');
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(getCannotEditReason()).toBe(null);
      });

      it('returns first failing condition (priority order)', async () => {
        localStorageMock.setStore({});
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(false);

        // Should return "Not authenticated" first, not "Offline"
        expect(getCannotEditReason()).toBe('Not authenticated');
      });
    });
  });

  describe('session timeout', () => {
    it('isSessionValid returns true for fresh key', async () => {
      setupValidSession('fresh-api-key');
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.isSessionValid()).toBe(true);
    });

    it('isSessionValid returns false when no timestamp exists', async () => {
      mockStore = { 'oak_api_key': 'key-without-timestamp' };
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.isSessionValid()).toBe(false);
    });

    it('isSessionValid returns false after timeout', async () => {
      // Set up an expired session (timestamp from 25 hours ago, default timeout is 24 hours)
      const expiredTimestamp = Date.now() - (25 * 60 * 60 * 1000);
      localStorageMock.setStore({
        'oak_api_key': 'expired-key',
        'oak_api_key_timestamp': String(expiredTimestamp)
      });
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.isSessionValid()).toBe(false);
    });

    it('isSessionValid respects custom timeout setting', async () => {
      // Set up a session from 5 hours ago with 6 hour timeout
      const fiveHoursAgo = Date.now() - (5 * 60 * 60 * 1000);
      localStorageMock.setStore({
        'oak_api_key': 'valid-key',
        'oak_api_key_timestamp': String(fiveHoursAgo),
        'oak_session_timeout_hours': '6'
      });
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.isSessionValid()).toBe(true);
    });

    it('isSessionValid returns false when custom timeout exceeded', async () => {
      // Set up a session from 5 hours ago with 4 hour timeout
      const fiveHoursAgo = Date.now() - (5 * 60 * 60 * 1000);
      localStorageMock.setStore({
        'oak_api_key': 'expired-key',
        'oak_api_key_timestamp': String(fiveHoursAgo),
        'oak_session_timeout_hours': '4'
      });
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.isSessionValid()).toBe(false);
    });

    it('getSessionTimeRemaining returns positive value for valid session', async () => {
      setupValidSession('fresh-api-key');
      const { authStore } = await import('../lib/stores/authStore.js');

      const remaining = authStore.getSessionTimeRemaining();
      expect(remaining).toBeGreaterThan(0);
      // Should be close to 24 hours (default timeout)
      const twentyFourHours = 24 * 60 * 60 * 1000;
      expect(remaining).toBeLessThanOrEqual(twentyFourHours);
    });

    it('getSessionTimeRemaining returns 0 for expired session', async () => {
      const expiredTimestamp = Date.now() - (25 * 60 * 60 * 1000);
      localStorageMock.setStore({
        'oak_api_key': 'expired-key',
        'oak_api_key_timestamp': String(expiredTimestamp)
      });
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.getSessionTimeRemaining()).toBe(0);
    });

    it('getSessionTimeRemaining returns 0 when no timestamp exists', async () => {
      mockStore = { 'oak_api_key': 'key-without-timestamp' };
      const { authStore } = await import('../lib/stores/authStore.js');

      expect(authStore.getSessionTimeRemaining()).toBe(0);
    });

    it('resetSessionTimestamp extends the session', async () => {
      // Set up a session from 23 hours ago (almost expired)
      const twentyThreeHoursAgo = Date.now() - (23 * 60 * 60 * 1000);
      localStorageMock.setStore({
        'oak_api_key': 'valid-key',
        'oak_api_key_timestamp': String(twentyThreeHoursAgo)
      });
      const { authStore } = await import('../lib/stores/authStore.js');

      // Should have less than 1 hour remaining
      const remainingBefore = authStore.getSessionTimeRemaining();
      expect(remainingBefore).toBeLessThan(60 * 60 * 1000);

      // Reset the timestamp
      authStore.resetSessionTimestamp();

      // Now should have close to 24 hours remaining
      const remainingAfter = authStore.getSessionTimeRemaining();
      expect(remainingAfter).toBeGreaterThan(23 * 60 * 60 * 1000);
    });
  });

  describe('session timeout configuration', () => {
    it('getSessionTimeoutHours returns default value', async () => {
      const { getSessionTimeoutHours } = await import('../lib/stores/authStore.js');
      expect(getSessionTimeoutHours()).toBe(24);
    });

    it('getSessionTimeoutHours returns configured value', async () => {
      mockStore = { 'oak_session_timeout_hours': '12' };
      const { getSessionTimeoutHours } = await import('../lib/stores/authStore.js');
      expect(getSessionTimeoutHours()).toBe(12);
    });

    it('setSessionTimeoutHours persists to localStorage', async () => {
      const { setSessionTimeoutHours } = await import('../lib/stores/authStore.js');
      setSessionTimeoutHours(8);
      expect(localStorageMock.setItem).toHaveBeenCalledWith('oak_session_timeout_hours', '8');
    });
  });
});
