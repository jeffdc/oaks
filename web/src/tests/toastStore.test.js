import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { get } from 'svelte/store';

describe('toastStore', () => {
  let toast;

  beforeEach(async () => {
    // Reset modules to get fresh store state
    vi.resetModules();
    vi.useFakeTimers();
    const module = await import('../lib/stores/toastStore.js');
    toast = module.toast;
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('toast.success', () => {
    it('adds a success toast with correct type', () => {
      toast.success('Test success message');
      const toasts = get(toast);
      expect(toasts).toHaveLength(1);
      expect(toasts[0].type).toBe('success');
      expect(toasts[0].message).toBe('Test success message');
    });

    it('uses default duration of 3000ms', () => {
      toast.success('Test message');
      const toasts = get(toast);
      expect(toasts[0].duration).toBe(3000);
    });

    it('accepts custom duration', () => {
      toast.success('Test message', 5000);
      const toasts = get(toast);
      expect(toasts[0].duration).toBe(5000);
    });

    it('returns toast id', () => {
      const id = toast.success('Test message');
      expect(typeof id).toBe('number');
    });

    it('auto-dismisses after duration', () => {
      toast.success('Test message', 3000);
      expect(get(toast)).toHaveLength(1);

      vi.advanceTimersByTime(3000);
      expect(get(toast)).toHaveLength(0);
    });
  });

  describe('toast.error', () => {
    it('adds an error toast with correct type', () => {
      toast.error('Test error message');
      const toasts = get(toast);
      expect(toasts).toHaveLength(1);
      expect(toasts[0].type).toBe('error');
      expect(toasts[0].message).toBe('Test error message');
    });

    it('uses default duration of 5000ms (longer for errors)', () => {
      toast.error('Test error');
      const toasts = get(toast);
      expect(toasts[0].duration).toBe(5000);
    });
  });

  describe('toast.warning', () => {
    it('adds a warning toast with correct type', () => {
      toast.warning('Test warning message');
      const toasts = get(toast);
      expect(toasts).toHaveLength(1);
      expect(toasts[0].type).toBe('warning');
      expect(toasts[0].message).toBe('Test warning message');
    });

    it('uses default duration of 4000ms', () => {
      toast.warning('Test warning');
      const toasts = get(toast);
      expect(toasts[0].duration).toBe(4000);
    });
  });

  describe('toast.info', () => {
    it('adds an info toast with correct type', () => {
      toast.info('Test info message');
      const toasts = get(toast);
      expect(toasts).toHaveLength(1);
      expect(toasts[0].type).toBe('info');
      expect(toasts[0].message).toBe('Test info message');
    });

    it('uses default duration of 3000ms', () => {
      toast.info('Test info');
      const toasts = get(toast);
      expect(toasts[0].duration).toBe(3000);
    });
  });

  describe('toast.dismiss', () => {
    it('removes a specific toast by id', () => {
      const id1 = toast.success('Message 1');
      const id2 = toast.error('Message 2');
      toast.info('Message 3');

      expect(get(toast)).toHaveLength(3);

      toast.dismiss(id2);
      const toasts = get(toast);
      expect(toasts).toHaveLength(2);
      expect(toasts.find(t => t.id === id2)).toBeUndefined();
    });

    it('does nothing for non-existent id', () => {
      toast.success('Message');
      expect(get(toast)).toHaveLength(1);

      toast.dismiss(99999);
      expect(get(toast)).toHaveLength(1);
    });
  });

  describe('toast.dismissAll', () => {
    it('removes all toasts', () => {
      toast.success('Message 1');
      toast.error('Message 2');
      toast.warning('Message 3');
      toast.info('Message 4');

      expect(get(toast)).toHaveLength(4);

      toast.dismissAll();
      expect(get(toast)).toHaveLength(0);
    });

    it('works when no toasts exist', () => {
      expect(get(toast)).toHaveLength(0);
      toast.dismissAll();
      expect(get(toast)).toHaveLength(0);
    });
  });

  describe('multiple toasts', () => {
    it('maintains order of toasts', () => {
      toast.success('First');
      toast.error('Second');
      toast.warning('Third');

      const toasts = get(toast);
      expect(toasts[0].message).toBe('First');
      expect(toasts[1].message).toBe('Second');
      expect(toasts[2].message).toBe('Third');
    });

    it('assigns unique ids to each toast', () => {
      const id1 = toast.success('Message 1');
      const id2 = toast.success('Message 2');
      const id3 = toast.success('Message 3');

      expect(id1).not.toBe(id2);
      expect(id2).not.toBe(id3);
      expect(id1).not.toBe(id3);
    });

    it('auto-dismisses toasts independently', () => {
      toast.success('Quick', 1000);
      toast.error('Slow', 5000);

      expect(get(toast)).toHaveLength(2);

      vi.advanceTimersByTime(1000);
      expect(get(toast)).toHaveLength(1);
      expect(get(toast)[0].message).toBe('Slow');

      vi.advanceTimersByTime(4000);
      expect(get(toast)).toHaveLength(0);
    });
  });

  describe('no auto-dismiss', () => {
    it('does not auto-dismiss when duration is 0', () => {
      toast.info('Persistent', 0);

      expect(get(toast)).toHaveLength(1);

      vi.advanceTimersByTime(10000);
      expect(get(toast)).toHaveLength(1);
    });
  });
});
