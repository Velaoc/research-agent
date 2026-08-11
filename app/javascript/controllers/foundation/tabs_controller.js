import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab"]

  navigate(event) {
    if (!["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const current = this.tabTargets.indexOf(document.activeElement)
    let index = event.key === "Home" ? 0 : event.key === "End" ? this.tabTargets.length - 1 : current
    index = event.key === "ArrowRight" ? (index + 1) % this.tabTargets.length : index
    index = event.key === "ArrowLeft" ? (index - 1 + this.tabTargets.length) % this.tabTargets.length : index
    this.tabTargets[index]?.focus()
  }
}
