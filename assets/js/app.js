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
  // Taxonomy band (DesignComponents.taxonomy_band): on phones the path is
  // one scrolling line; keep the current taxon, at its end, in view.
  PinCurrentTaxon: {
    mounted() { this.pin() },
    updated() { this.pin() },
    pin() { this.el.scrollLeft = this.el.scrollWidth }
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
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
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

