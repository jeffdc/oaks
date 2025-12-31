// authStore.js - API key management with localStorage persistence
import { writable, derived } from 'svelte/store';
import { browser } from '$app/environment';

const API_KEY_STORAGE_KEY = 'oak_api_key';

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
