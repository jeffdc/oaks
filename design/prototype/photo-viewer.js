/* Photo viewer: a shared component (Oak Compendium, later Gallformers).

   Markup contract, no page code needed beyond PhotoViewer.mount(root):

   <div class="pv" data-photo-viewer>
     <figure class="pv-stage">
       <div class="pv-frame" data-pv-frame></div>
       <figcaption><p class="pv-cap" data-pv-cap></p><p class="pv-credit" data-pv-credit></p></figcaption>
     </figure>
     <div class="pv-rail">
       <button class="pv-step" data-pv-prev aria-label="Earlier photos"></button>
       <ol class="pv-thumbs" data-pv-thumbs>
         <li><button class="pv-thumb" data-pv-photo
               data-src="…medium url…" data-thumb="…small url…" data-alt="…"
               data-caption="…" data-credit-html="…">…</button></li>
       </ol>
       <button class="pv-step" data-pv-next aria-label="Later photos"></button>
     </div>
     <p class="pv-count" data-pv-count></p>
   </div>

   Choosing a thumbnail shows it on the stage. The step buttons page the strip by
   the number of thumbnails in view; Left/Right keys move photo by photo and keep
   the current one in view. With one photo the rail and count are left out. */
(function (global) {
  function mount(root) {
    if (!root || root.__pv) return;
    const frame = root.querySelector("[data-pv-frame]");
    const cap = root.querySelector("[data-pv-cap]");
    const credit = root.querySelector("[data-pv-credit]");
    const count = root.querySelector("[data-pv-count]");
    const strip = root.querySelector("[data-pv-thumbs]");
    const rail = strip && strip.closest(".pv-rail");
    const prev = root.querySelector("[data-pv-prev]");
    const next = root.querySelector("[data-pv-next]");
    const photos = Array.from(root.querySelectorAll("[data-pv-photo]"));
    let current = 0;

    function show(i, { focus = false } = {}) {
      current = Math.max(0, Math.min(photos.length - 1, i));
      const p = photos[current];
      photos.forEach((b, j) => b.setAttribute("aria-current", String(j === current)));
      if (p.dataset.src) frame.innerHTML = `<img src="${p.dataset.src}" alt="${p.dataset.alt || ""}">`;
      else frame.textContent = p.dataset.alt || `Photo ${current + 1}`;
      cap.textContent = p.dataset.caption || "";
      credit.innerHTML = p.dataset.creditHtml || "";
      if (count) count.textContent = photos.length > 1 ? `${current + 1} / ${photos.length}` : "";
      keepInView(p.parentElement);
      if (focus) p.focus({ preventScroll: true });
    }

    function keepInView(li) {
      if (!strip) return;
      const l = li.offsetLeft, r = l + li.offsetWidth;
      if (l < strip.scrollLeft) strip.scrollLeft = l - 2;
      else if (r > strip.scrollLeft + strip.clientWidth) strip.scrollLeft = r - strip.clientWidth + 2;
    }

    function page(dir) { strip.scrollBy({ left: dir * strip.clientWidth, behavior: "smooth" }); }

    function updateSteps() {
      if (!strip || !rail) return;
      const fits = strip.scrollWidth <= strip.clientWidth + 2;
      rail.toggleAttribute("data-fits", fits);
      prev.disabled = strip.scrollLeft <= 2;
      next.disabled = strip.scrollLeft + strip.clientWidth >= strip.scrollWidth - 2;
    }

    if (photos.length < 2) { if (rail) rail.hidden = true; if (count) count.hidden = true; }
    photos.forEach((b, i) => b.addEventListener("click", () => show(i)));
    prev && prev.addEventListener("click", () => page(-1));
    next && next.addEventListener("click", () => page(1));
    strip && strip.addEventListener("scroll", updateSteps, { passive: true });
    root.addEventListener("keydown", e => {
      if (e.key === "ArrowRight") { show(current + 1, { focus: true }); e.preventDefault(); }
      if (e.key === "ArrowLeft") { show(current - 1, { focus: true }); e.preventDefault(); }
    });
    if ("ResizeObserver" in global && strip) new ResizeObserver(updateSteps).observe(strip);
    root.__pv = true;
    if (photos.length) show(0);
    updateSteps();
  }

  global.PhotoViewer = { mount, mountAll: (scope = document) => scope.querySelectorAll("[data-photo-viewer]").forEach(mount) };
})(window);
