// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/oaks"
import topbar from "../vendor/topbar"

// The API key login is gone (item 0249): drop what it left in this browser.
for (const key of ["oak:api_key", "oak:session_timestamp", "oak:session_timeout_hours", "oak:settings_notice"]) {
  localStorage.removeItem(key)
}

const Hooks = {
  ...colocatedHooks,
  // Photo list (DesignComponents.photo_list): drag a row by its handle,
  // or press Up or Down on the handle, to move it; the new order (each
  // row's data-photo-id) goes to the component the list is in when it
  // changed. Ported from gallformers' sortable_images.js, as a list.
  SortablePhotos: {
    mounted() {
      this.el.addEventListener("dragstart", e => this.start(e))
      this.el.addEventListener("dragover", e => this.over(e))
      this.el.addEventListener("drop", e => e.preventDefault())
      this.el.addEventListener("dragend", () => this.end())
      this.el.addEventListener("keydown", e => this.key(e))
    },
    rows() { return [...this.el.querySelectorAll(":scope > [data-photo-id]")] },
    order() { return this.rows().map(row => row.dataset.photoId) },
    start(e) {
      const row = e.target.closest("[data-grip]")?.closest("[data-photo-id]")
      if (!row) return
      this.dragging = row
      this.before = this.order().join()
      row.dataset.dragging = ""
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("text/plain", row.dataset.photoId)
      e.dataTransfer.setDragImage(row, 24, 24)
    },
    over(e) {
      if (!this.dragging) return
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      const row = e.target.closest("[data-photo-id]")
      if (!row || row === this.dragging || row.parentElement !== this.el) return
      const box = row.getBoundingClientRect()
      this.el.insertBefore(this.dragging, e.clientY < box.top + box.height / 2 ? row : row.nextSibling)
    },
    end() {
      if (!this.dragging) return
      delete this.dragging.dataset.dragging
      this.dragging = null
      this.push()
    },
    key(e) {
      const grip = e.target.closest("[data-grip]")
      if (!grip || (e.key !== "ArrowUp" && e.key !== "ArrowDown")) return
      e.preventDefault()
      const row = grip.closest("[data-photo-id]")
      this.before = this.order().join()
      if (e.key === "ArrowUp" && row.previousElementSibling) this.el.insertBefore(row, row.previousElementSibling)
      if (e.key === "ArrowDown" && row.nextElementSibling) this.el.insertBefore(row.nextElementSibling, row)
      grip.focus()
      this.push()
    },
    push() {
      if (this.order().join() !== this.before) this.pushEventTo(this.el, this.el.dataset.event, {order: this.order()})
    }
  },
  // Taxonomy band (DesignComponents.taxonomy_band): the path is one line.
  // When it is too long for the band, mark it (data-overflow) and keep the
  // current taxon, at its end, in view; while anything is scrolled off to
  // the left, mark that too (data-scrolled, which fades the left edge).
  // Measured again when the band or the path's last step changes size, as
  // when the band's fonts arrive.
  PinCurrentTaxon: {
    mounted() {
      this.observer = new ResizeObserver(() => this.pin())
      this.observer.observe(this.el)
      this.el.addEventListener("scroll", () => this.mark(), {passive: true})
      this.pin()
    },
    updated() { this.pin() },
    destroyed() { this.observer?.disconnect() },
    pin() {
      const ol = this.el
      const last = ol.lastElementChild
      if (last !== this.last) {
        if (this.last) this.observer.unobserve(this.last)
        if (last) this.observer.observe(last)
        this.last = last
      }
      ol.toggleAttribute("data-overflow", ol.scrollWidth > ol.clientWidth)
      ol.scrollLeft = ol.scrollWidth
      this.mark()
    },
    mark() { this.el.toggleAttribute("data-scrolled", this.el.scrollLeft > 0) }
  },
  TagInput: {
    mounted() {
      this.el.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === ",") {
          e.preventDefault()
          const value = this.el.value.trim().replace(/,+$/, "")
          if (value) {
            this.pushEvent(this.el.dataset.addEvent, {value: value})
            this.el.value = ""
          }
        }
      })
    }
  },
  SearchSync: {
    mounted() {
      this._headerInput = document.getElementById("header-search")
      this._headerForm = this._headerInput?.closest("form")
      if (!this._headerInput) return

      // Fill header with current query
      const query = this.el.dataset.query || ""
      this._headerInput.value = query

      // Debounced input handler → push LiveView event
      this._debounceTimer = null
      this._inputHandler = (e) => {
        clearTimeout(this._debounceTimer)
        this._debounceTimer = setTimeout(() => {
          this.pushEvent("search", {q: e.target.value})
        }, 300)
      }
      this._headerInput.addEventListener("input", this._inputHandler)

      // Prevent form submit; use LiveView navigation instead
      this._submitHandler = (e) => {
        e.preventDefault()
        clearTimeout(this._debounceTimer)
        this.pushEvent("search", {q: this._headerInput.value})
      }
      this._headerForm?.addEventListener("submit", this._submitHandler)
    },

    updated() {
      if (this._headerInput && this._headerInput !== document.activeElement) {
        this._headerInput.value = this.el.dataset.query || ""
      }
    },

    destroyed() {
      clearTimeout(this._debounceTimer)
      if (this._headerInput && this._inputHandler) {
        this._headerInput.removeEventListener("input", this._inputHandler)
      }
      if (this._headerForm && this._submitHandler) {
        this._headerForm.removeEventListener("submit", this._submitHandler)
      }
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Connect params carried over from the static render: an element with
// data-connect-key and data-connect-value hands its value to the live
// mount (get_connect_params/1), so a choice the server made on the first
// render, such as the home page's oak at random, survives the connection.
const connectParams = () => {
  const params = {_csrf_token: csrfToken}
  document.querySelectorAll("[data-connect-key]").forEach(el => {
    params[el.dataset.connectKey] = el.dataset.connectValue
  })
  return params
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: connectParams,
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Click to copy: a [data-copy] element copies its value to the clipboard and
// says so in its [data-copy-status] child (the new agent token page). A
// document listener rather than a hook, since that page isn't a LiveView. If
// the clipboard is unavailable, the text is selected for a manual copy.
document.addEventListener("click", async e => {
  const el = e.target.closest("[data-copy]")
  if (!el) return
  const status = el.querySelector("[data-copy-status]")

  try {
    await navigator.clipboard.writeText(el.dataset.copy)
    el.dataset.copied = "true"
    if (status) status.textContent = "Copied"
  } catch (_err) {
    const range = document.createRange()
    range.selectNodeContents(el.querySelector(".settings-copy-text") || el)
    window.getSelection().removeAllRanges()
    window.getSelection().addRange(range)
    if (status) status.textContent = "Press Ctrl+C or Cmd+C to copy"
  }
})

// The masthead search (OaksWeb.Layouts.site_header): "/" focuses it from
// anywhere except a field the reader is typing in.
document.addEventListener("keydown", e => {
  if (e.key !== "/" || e.ctrlKey || e.metaKey || e.altKey || e.defaultPrevented) return
  if (e.target.closest?.("input, textarea, select, [contenteditable]")) return
  const search = document.getElementById("header-search")
  if (!search) return
  e.preventDefault()
  search.focus()
  search.select()
})

// Menus built on <details data-menu> (the masthead's Editor menu, a
// page's Edit menu) close on Escape, on a click outside them and when one
// of their items is chosen. Document listeners rather than phx-click-away,
// so the menu also closes on the controller pages.
document.addEventListener("click", e => {
  for (const menu of document.querySelectorAll("details[data-menu][open]")) {
    const chose = menu.contains(e.target) && e.target.closest("li a, li button")
    if (!menu.contains(e.target) || chose) menu.open = false
  }
})
document.addEventListener("keydown", e => {
  if (e.key !== "Escape") return
  for (const menu of document.querySelectorAll("details[data-menu][open]")) {
    const hadFocus = menu.contains(document.activeElement)
    menu.open = false
    if (hadFocus) menu.querySelector("summary")?.focus()
  }
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

