import { Controller } from "@hotwired/stimulus"

const THEMES = ["system", "light", "dark"]
const STORAGE_KEY = "foundation.color-theme"
const ICONS = { dark: "\uE51C", light: "\uE518" }

export default class extends Controller {
  static targets = ["button", "icon"]

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemChange = () => { if (this.currentTheme === "system") this.apply("system") }
    this.media.addEventListener("change", this.systemChange)
    this.apply(this.savedTheme())
  }

  disconnect() {
    this.media.removeEventListener("change", this.systemChange)
  }

  cycle() {
    const current = this.currentTheme || this.savedTheme()
    const next = THEMES[(THEMES.indexOf(current) + 1) % THEMES.length]
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch (_error) {
      // The visual override still applies when storage is unavailable.
    }
    this.apply(next)
  }

  savedTheme() {
    try {
      const value = localStorage.getItem(STORAGE_KEY)
      return THEMES.includes(value) ? value : "system"
    } catch (_error) {
      return "system"
    }
  }

  apply(theme) {
    this.currentTheme = theme
    if (theme === "system") this.element.removeAttribute("data-theme")
    else this.element.dataset.theme = theme

    const resolved = theme === "system" && this.media.matches ? "dark" : theme
    const icon = resolved === "dark" ? ICONS.dark : ICONS.light
    this.iconTargets.forEach((target) => { target.textContent = icon })
    this.buttonTargets.forEach((target) => {
      target.setAttribute("aria-label", `Color theme: ${theme}. Activate to change.`)
    })
  }
}
