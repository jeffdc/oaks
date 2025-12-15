<script>
  import Search from './Search.svelte';

  export let onGoHome;
</script>

<header class="sticky top-0 z-40" style="background: linear-gradient(135deg, var(--color-forest-800) 0%, var(--color-forest-700) 100%); box-shadow: var(--shadow-lg);">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-5">
    <div class="flex flex-wrap items-center justify-between gap-4">
      <button
        on:click={onGoHome}
        class="flex items-center gap-3 hover:opacity-90 transition-opacity"
      >
        <img src="/oak-leaf-outline.svg" alt="Oak Leaf" class="w-8 h-12 brightness-0 invert opacity-90" />
        <div class="text-left">
          <h1 class="text-2xl font-bold text-white" style="font-family: var(--font-serif); letter-spacing: 0.01em;">Quercus Compendium</h1>
          <p class="text-sm text-white/70 mt-0.5">A comprehensive guide to oak species</p>
        </div>
      </button>
      <div class="w-full sm:w-auto sm:flex-1 sm:max-w-lg ml-auto">
        <Search />
      </div>
    </div>
  </div>
</header>
