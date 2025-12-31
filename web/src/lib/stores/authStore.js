// authStore.js - API key management with localStorage persistence
import { writable, derived } from 'svelte/store';

const API_KEY_STORAGE_KEY = 'oak_api_key';

function createAuthStore() {
  const apiKey = writable(localStorage.getItem(API_KEY_STORAGE_KEY) || '');

  return {
    subscribe: apiKey.subscribe,
    setKey: (key) => {
      localStorage.setItem(API_KEY_STORAGE_KEY, key);
      apiKey.set(key);
    },
    clearKey: () => {
      localStorage.removeItem(API_KEY_STORAGE_KEY);
      apiKey.set('');
    }
  };
}

export const authStore = createAuthStore();
export const isAuthenticated = derived(authStore, $key => !!$key);
