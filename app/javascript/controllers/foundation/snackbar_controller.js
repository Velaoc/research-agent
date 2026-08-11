import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.timer = window.setTimeout(() => this.dismiss(), this.timeoutValue)
    }
  }

  disconnect() {
    window.clearTimeout(this.timer)
  }

  dismiss() {
    this.element.remove()
  }
}
