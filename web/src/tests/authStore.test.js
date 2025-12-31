import { describe, it, expect, beforeEach, vi } from 'vitest';
import { get } from 'svelte/store';

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
});
