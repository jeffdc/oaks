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
import {hooks as colocatedHooks} from "phoenix-colocated/oak_compendium"
import topbar from "../vendor/topbar"

const Hooks = {
  ...colocatedHooks,
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
  },
  ApiKeySettings: {
    _defaultTimeout: 24,
    _timer: null,

    mounted() {
      this._setupHandlers()
      this._initSession()
    },

    updated() {
      this._startTimer()
    },

    destroyed() {
      this._clearTimer()
    },

    _getTimeoutHours() {
      return parseInt(localStorage.getItem("oak:session_timeout_hours") || this._defaultTimeout, 10)
    },

    _getTimeoutMs() {
      return this._getTimeoutHours() * 60 * 60 * 1000
    },

    _getRemainingMs() {
      const timestamp = localStorage.getItem("oak:session_timestamp")
      if (!timestamp) return 0
      const elapsed = Date.now() - parseInt(timestamp, 10)
      return Math.max(0, this._getTimeoutMs() - elapsed)
    },

    _formatTime(ms) {
      if (ms <= 0) return "Expired"
      const hours = Math.floor(ms / (1000 * 60 * 60))
      const minutes = Math.floor((ms % (1000 * 60 * 60)) / (1000 * 60))
      if (hours > 0) return `${hours}h ${minutes}m`
      return `${minutes}m`
    },

    _clearTimer() {
      if (this._timer) {
        clearInterval(this._timer)
        this._timer = null
      }
    },

    _startTimer() {
      this._clearTimer()
      this._updateTimeDisplay()
      this._timer = setInterval(() => this._updateTimeDisplay(), 60000)
    },

    _updateTimeDisplay() {
      const el = this.el.querySelector("#session-time-remaining")
      if (!el) return
      const remaining = this._getRemainingMs()
      el.textContent = this._formatTime(remaining)
      if (remaining <= 0 && localStorage.getItem("oak:api_key")) {
        localStorage.removeItem("oak:api_key")
        localStorage.removeItem("oak:session_timestamp")
        this._clearTimer()
        this.pushEvent("save_result", {status: "cleared"})
      }
    },

    _initSession() {
      // Set timeout select to stored value
      const timeoutSelect = this.el.querySelector("#session-timeout-select")
      if (timeoutSelect) {
        timeoutSelect.value = this._getTimeoutHours().toString()
      }

      // Check existing key and session validity
      const stored = localStorage.getItem("oak:api_key")
      if (stored) {
        const remaining = this._getRemainingMs()
        if (remaining > 0) {
          const input = this.el.querySelector("#api-key-input")
          if (input) input.value = stored
          this.pushEvent("auth_status", {authenticated: true})
        } else {
          // Session expired
          localStorage.removeItem("oak:api_key")
          localStorage.removeItem("oak:session_timestamp")
        }
      }

      this._startTimer()
    },

    _setupHandlers() {
      const input = this.el.querySelector("#api-key-input")
      const saveBtn = this.el.querySelector("#save-api-key")
      const clearBtn = this.el.querySelector("#clear-api-key")

      saveBtn.addEventListener("click", async () => {
        const key = input.value.trim()
        if (!key) {
          this.pushEvent("verify_result", {status: "invalid"})
          return
        }
        try {
          const resp = await fetch("/api/v1/auth/verify", {
            headers: {"Authorization": `Bearer ${key}`}
          })
          if (resp.ok) {
            localStorage.setItem("oak:api_key", key)
            localStorage.setItem("oak:session_timestamp", Date.now().toString())
            this.pushEvent("save_result", {status: "saved"})
          } else {
            this.pushEvent("verify_result", {status: "invalid"})
          }
        } catch (_e) {
          this.pushEvent("verify_result", {status: "error"})
        }
      })

      clearBtn.addEventListener("click", () => {
        localStorage.removeItem("oak:api_key")
        localStorage.removeItem("oak:session_timestamp")
        input.value = ""
        this.pushEvent("save_result", {status: "cleared"})
      })

      // Reset session button (delegated since it may not exist yet)
      this.el.addEventListener("click", (e) => {
        if (e.target.id === "reset-session-btn" || e.target.closest("#reset-session-btn")) {
          localStorage.setItem("oak:session_timestamp", Date.now().toString())
          this._updateTimeDisplay()
        }
      })

      // Timeout select (delegated since it may not exist yet)
      this.el.addEventListener("change", (e) => {
        if (e.target.id === "session-timeout-select") {
          const hours = parseInt(e.target.value, 10)
          if (hours > 0 && hours <= 168) {
            localStorage.setItem("oak:session_timeout_hours", hours.toString())
            this._updateTimeDisplay()
          }
        }
      })
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken, api_key: localStorage.getItem("oak:api_key") || ""},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

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

