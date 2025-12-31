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

// Mock localStorage before importing the store
const localStorageMock = (() => {
  let store = {};
  return {
    getItem: vi.fn((key) => store[key] ?? null),
    setItem: vi.fn((key, value) => { store[key] = value; }),
    removeItem: vi.fn((key) => { delete store[key]; }),
    clear: vi.fn(() => { store = {}; })
  };
})();

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
    localStorageMock.clear();

    // Re-import the module to get fresh store state
    vi.resetModules();
  });

  it('initializes with empty string when localStorage is empty', async () => {
    localStorageMock.getItem.mockReturnValue(null);
    const { authStore } = await import('../lib/stores/authStore.js');
    expect(get(authStore)).toBe('');
  });

  it('initializes with stored key from localStorage', async () => {
    localStorageMock.getItem.mockReturnValue('stored-api-key');
    const { authStore } = await import('../lib/stores/authStore.js');
    expect(get(authStore)).toBe('stored-api-key');
  });

  it('setKey updates store and persists to localStorage', async () => {
    localStorageMock.getItem.mockReturnValue(null);
    const { authStore } = await import('../lib/stores/authStore.js');

    authStore.setKey('new-api-key');

    expect(get(authStore)).toBe('new-api-key');
    expect(localStorageMock.setItem).toHaveBeenCalledWith('oak_api_key', 'new-api-key');
  });

  it('clearKey clears store and removes from localStorage', async () => {
    localStorageMock.getItem.mockReturnValue('existing-key');
    const { authStore } = await import('../lib/stores/authStore.js');

    authStore.clearKey();

    expect(get(authStore)).toBe('');
    expect(localStorageMock.removeItem).toHaveBeenCalledWith('oak_api_key');
  });

  describe('isAuthenticated derived store', () => {
    it('returns false when no key is set', async () => {
      localStorageMock.getItem.mockReturnValue(null);
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(false);
    });

    it('returns false when key is empty string', async () => {
      localStorageMock.getItem.mockReturnValue('');
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(false);
    });

    it('returns true when key is set', async () => {
      localStorageMock.getItem.mockReturnValue('valid-api-key');
      const { isAuthenticated } = await import('../lib/stores/authStore.js');
      expect(get(isAuthenticated)).toBe(true);
    });

    it('updates reactively when key is set', async () => {
      localStorageMock.getItem.mockReturnValue(null);
      const { authStore, isAuthenticated } = await import('../lib/stores/authStore.js');

      expect(get(isAuthenticated)).toBe(false);

      authStore.setKey('new-key');
      expect(get(isAuthenticated)).toBe(true);
    });

    it('updates reactively when key is cleared', async () => {
      localStorageMock.getItem.mockReturnValue('existing-key');
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
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(true);
      });

      it('returns false when not authenticated', async () => {
        localStorageMock.getItem.mockReturnValue(null);
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(false);
      });

      it('returns false when offline', async () => {
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(true);

        expect(get(canEdit)).toBe(false);
      });

      it('returns false when API unavailable', async () => {
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { canEdit, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(get(canEdit)).toBe(false);
      });
    });

    describe('getCannotEditReason', () => {
      it('returns null when can edit', async () => {
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(true);

        expect(getCannotEditReason()).toBe(null);
      });

      it('returns "Not authenticated" when no API key', async () => {
        localStorageMock.getItem.mockReturnValue(null);
        const { getCannotEditReason } = await import('../lib/stores/authStore.js');

        expect(getCannotEditReason()).toBe('Not authenticated');
      });

      it('returns "Offline" when offline', async () => {
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { getCannotEditReason, isOnline } = await import('../lib/stores/authStore.js');

        isOnline.set(false);

        expect(getCannotEditReason()).toBe('Offline');
      });

      it('returns "API unavailable" when API is down', async () => {
        localStorageMock.getItem.mockReturnValue('valid-api-key');
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(true);
        apiAvailable.set(false);

        expect(getCannotEditReason()).toBe('API unavailable');
      });

      it('returns first failing condition (priority order)', async () => {
        localStorageMock.getItem.mockReturnValue(null);
        const { getCannotEditReason, isOnline, apiAvailable } = await import('../lib/stores/authStore.js');

        isOnline.set(false);
        apiAvailable.set(false);

        // Should return "Not authenticated" first, not "Offline"
        expect(getCannotEditReason()).toBe('Not authenticated');
      });
    });
  });
});
