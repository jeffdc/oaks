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

// -- API key session (stored in localStorage, sent as a LiveSocket connect param) --

const API_KEY = "oak:api_key"
const SESSION_TS = "oak:session_timestamp"
const TIMEOUT_HOURS = "oak:session_timeout_hours"
const SETTINGS_NOTICE = "oak:settings_notice"
const DEFAULT_TIMEOUT_HOURS = 24

function sessionTimeoutHours() {
  return parseInt(localStorage.getItem(TIMEOUT_HOURS) || DEFAULT_TIMEOUT_HOURS, 10)
}

function sessionRemainingMs() {
  const timestamp = localStorage.getItem(SESSION_TS)
  if (!timestamp) return 0
  const elapsed = Date.now() - parseInt(timestamp, 10)
  return Math.max(0, sessionTimeoutHours() * 60 * 60 * 1000 - elapsed)
}

function clearStoredKey() {
  localStorage.removeItem(API_KEY)
  localStorage.removeItem(SESSION_TS)
}

// Returns the stored API key, clearing it first if its session has expired.
function currentApiKey() {
  const key = localStorage.getItem(API_KEY)
  if (!key) return ""
  if (sessionRemainingMs() <= 0) {
    clearStoredKey()
    return ""
  }
  return key
}

// Applies a key change and reloads so every LiveView remounts with it,
// leaving a one-shot notice for the Settings page to show afterwards.
function reloadWithNotice(notice, change) {
  change()
  sessionStorage.setItem(SETTINGS_NOTICE, notice)
  window.location.reload()
}

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

    _getRemainingMs() {
      return sessionRemainingMs()
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
      if (remaining <= 0 && localStorage.getItem(API_KEY)) {
        this._clearTimer()
        reloadWithNotice("cleared", clearStoredKey)
      }
    },

    _initSession() {
      // Set timeout select to stored value
      const timeoutSelect = this.el.querySelector("#session-timeout-select")
      if (timeoutSelect) {
        timeoutSelect.value = sessionTimeoutHours().toString()
      }

      const stored = currentApiKey()
      const input = this.el.querySelector("#api-key-input")
      if (stored && input) input.value = stored

      // Show the result of a save/clear that triggered the last reload
      const notice = sessionStorage.getItem(SETTINGS_NOTICE)
      if (notice) {
        sessionStorage.removeItem(SETTINGS_NOTICE)
        this.pushEvent("save_result", {status: notice})
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
            // Reload so the LiveSocket reconnects and the server checks the new key
            reloadWithNotice("saved", () => {
              localStorage.setItem(API_KEY, key)
              localStorage.setItem(SESSION_TS, Date.now().toString())
            })
          } else {
            this.pushEvent("verify_result", {status: "invalid"})
          }
        } catch (_e) {
          this.pushEvent("verify_result", {status: "error"})
        }
      })

      clearBtn.addEventListener("click", () => {
        input.value = ""
        reloadWithNotice("cleared", clearStoredKey)
      })

      // Reset session button (delegated since it may not exist yet)
      this.el.addEventListener("click", (e) => {
        if (e.target.id === "reset-session-btn" || e.target.closest("#reset-session-btn")) {
          localStorage.setItem(SESSION_TS, Date.now().toString())
          this._updateTimeDisplay()
        }
      })

      // Timeout select (delegated since it may not exist yet)
      this.el.addEventListener("change", (e) => {
        if (e.target.id === "session-timeout-select") {
          const hours = parseInt(e.target.value, 10)
          if (hours > 0 && hours <= 168) {
            localStorage.setItem(TIMEOUT_HOURS, hours.toString())
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
  // A function so the key (and its expiry) is re-checked on every (re)connect
  params: () => ({_csrf_token: csrfToken, api_key: currentApiKey()}),
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

