// PhotoViewer hook (OaksWeb.PhotoViewer.photo_viewer/1): a shared
// component, built to move back to gallformers, so it knows nothing of the
// page around it. Design: design/prototype/photo-viewer.js, with the
// full-size view, swipe and details dialog of gallformers' photo_viewer.js.
//
// The server renders every photo's slide, full-size figure and details;
// this shows the current one. Moves wrap: thumbnails, the full-size view's
// arrows, Left/Right keys (while focus is in the viewer, its dialogs
// included) and a horizontal swipe on a photo. The rail's step buttons page
// the thumbnails by as many as are in view; a move keeps the current one in
// view. With data-event, each move pushes that event with {index}. The
// full-size view loads a photo (data-src) when it is first shown. Escape
// closes an open dialog wherever focus is (some browsers leave focus
// outside a modal after a click on its photo, and their own Escape then
// does nothing); a click on a dialog's backdrop closes it too, and closing
// returns focus to what opened it.

const SWIPE = 40 // px

const PhotoViewer = {
  mounted() {
    this.index = 0
    this.count = parseInt(this.el.dataset.count || "0", 10)
    this.strip = this.el.querySelector("[data-thumbs]")
    this.rail = this.strip?.parentElement
    this.opener = null

    this.onClick = (e) => {
      const dialog = e.target.closest("dialog")
      if (dialog && e.target === dialog) return dialog.close() // its backdrop
      const target = e.target.closest("[data-page], [data-prev], [data-next], [data-go], [data-open], [data-open-details], [data-close]")
      if (!target || !this.el.contains(target)) return
      if (target.matches("[data-page]")) {
        this.lastStep = target
        this.page(parseInt(target.dataset.page, 10))
      }
      else if (target.matches("[data-prev]")) this.go(this.index - 1)
      else if (target.matches("[data-next]")) this.go(this.index + 1)
      else if (target.matches("[data-go]")) this.go(parseInt(target.dataset.go, 10))
      else if (target.matches("[data-open]")) this.open("[data-lightbox]", target)
      else if (target.matches("[data-open-details]")) this.open("[data-details]", target)
      else if (target.matches("[data-close]")) target.closest("dialog")?.close()
    }

    this.onKey = (e) => {
      if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return
      if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) return
      e.preventDefault()
      this.go(this.index + (e.key === "ArrowRight" ? 1 : -1))
    }

    this.onPointerDown = (e) => {
      if (!e.isPrimary || !e.target.closest("[data-stage]")) return
      this.swipeFrom = {x: e.clientX, y: e.clientY}
    }

    this.onPointerUp = (e) => {
      if (!this.swipeFrom) return
      const dx = e.clientX - this.swipeFrom.x
      const dy = e.clientY - this.swipeFrom.y
      this.swipeFrom = null
      if (Math.abs(dx) >= SWIPE && Math.abs(dx) > Math.abs(dy)) {
        this.swiped = true
        setTimeout(() => { this.swiped = false }, 0) // a swipe ends in at most one click
        this.go(dx < 0 ? this.index + 1 : this.index - 1)
      }
    }

    this.onPointerCancel = () => { this.swipeFrom = null }

    // A swipe ends with a click on the photo; it must not also open it.
    this.onClickCapture = (e) => {
      if (this.swiped) {
        this.swiped = false
        e.stopPropagation()
        e.preventDefault()
      }
    }

    this.onEscape = (e) => {
      if (e.key !== "Escape") return
      const open = this.el.querySelector("dialog[open]")
      if (open) {
        e.preventDefault()
        open.close()
      }
    }

    // The stage photo that opened a dialog may be hidden by now: return
    // to the one shown.
    this.onClose = () => {
      let opener = this.opener
      if (opener?.closest("[data-slide]")) opener = this.el.querySelector(`[data-slide="${this.index}"] [data-open]`)
      if (opener && document.contains(opener)) opener.focus({preventScroll: true})
      this.opener = null
    }

    this.steps = () => {
      if (!this.strip) return
      const s = this.strip
      const prev = this.rail.querySelector("[data-page='-1']")
      const next = this.rail.querySelector("[data-page='1']")
      this.rail.toggleAttribute("data-fits", s.scrollWidth <= s.clientWidth + 2)
      prev.disabled = s.scrollLeft <= 2
      next.disabled = s.scrollLeft + s.clientWidth >= s.scrollWidth - 2
      // A step that pages to the end is disabled under the focus: hand it
      // to the other one rather than lose it.
      const lost = (step) => document.activeElement === step ||
        (document.activeElement === document.body && this.lastStep === step)
      if (prev.disabled && !next.disabled && lost(prev)) next.focus({preventScroll: true})
      if (next.disabled && !prev.disabled && lost(next)) prev.focus({preventScroll: true})
    }

    this.el.addEventListener("click", this.onClickCapture, true)
    this.el.addEventListener("click", this.onClick)
    this.el.addEventListener("keydown", this.onKey)
    this.el.addEventListener("pointerdown", this.onPointerDown)
    this.el.addEventListener("pointerup", this.onPointerUp)
    this.el.addEventListener("pointercancel", this.onPointerCancel)
    window.addEventListener("keydown", this.onEscape)
    this.el.querySelectorAll("dialog").forEach(d => d.addEventListener("close", this.onClose))
    if (this.strip) {
      this.strip.addEventListener("scroll", this.steps, {passive: true})
      this.observer = new ResizeObserver(this.steps)
      this.observer.observe(this.strip)
      this.steps()
    }
  },

  destroyed() {
    window.removeEventListener("keydown", this.onEscape)
    this.observer?.disconnect()
  },

  go(index) {
    if (this.count < 2) return
    const wasOn = document.activeElement?.closest("[data-slide], [data-full], [data-info], [data-go]")
    this.index = (index + this.count) % this.count
    const i = String(this.index)

    for (const attr of ["data-slide", "data-full", "data-info"]) {
      this.el.querySelectorAll(`[${attr}]`).forEach(e => { e.hidden = e.getAttribute(attr) !== i })
    }

    this.el.querySelectorAll("[data-go]").forEach(b => b.setAttribute("aria-current", String(b.dataset.go === i)))
    this.el.querySelectorAll("[data-counter]").forEach(c => { c.textContent = `${this.index + 1} / ${this.count}` })
    this.keepInView(this.el.querySelector(`[data-go="${i}"]`)?.parentElement)

    // Focus follows the move from a thumbnail or the stage photo, and
    // leaves a photo that is now hidden (a link in its caption or details)
    // for its dialog's Close.
    if (wasOn?.matches("[data-go]")) this.el.querySelector(`[data-go="${i}"]`)?.focus({preventScroll: true})
    else if (wasOn?.matches("[data-slide]")) this.el.querySelector(`[data-slide="${i}"] [data-open]`)?.focus({preventScroll: true})
    else if (wasOn?.hidden) wasOn.closest("dialog")?.querySelector("[data-close]")?.focus()

    if (this.el.querySelector("[data-lightbox]")?.open) this.loadFull()
    if (this.el.dataset.event) this.pushEvent(this.el.dataset.event, {index: this.index})
  },

  // Scroll the strip, not the page, so the thumbnail is in view.
  keepInView(li) {
    if (!li || !this.strip) return
    const s = this.strip, l = li.offsetLeft, r = l + li.offsetWidth // the strip is positioned
    if (l < s.scrollLeft) s.scrollLeft = l - 2
    else if (r > s.scrollLeft + s.clientWidth) s.scrollLeft = r - s.clientWidth + 2
  },

  page(dir) {
    this.strip?.scrollBy({left: dir * this.strip.clientWidth, behavior: "smooth"})
  },

  // The full-size photo is loaded only when it is shown.
  loadFull() {
    const img = this.el.querySelector(`[data-full="${this.index}"] img[data-src]`)
    if (img && !img.getAttribute("src")) img.setAttribute("src", img.dataset.src)
  },

  open(selector, opener) {
    const dialog = this.el.querySelector(selector)
    if (!dialog || dialog.open) return
    this.opener = opener
    dialog.showModal()
    if (selector === "[data-lightbox]") this.loadFull()
  }
}

export default PhotoViewer
