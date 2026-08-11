import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "surface"]

  connect() {
    this.outside = (event) => { if (!this.element.contains(event.target)) this.close() }
    document.addEventListener("pointerdown", this.outside)
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.outside)
  }

  toggle() {
    this.surfaceTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.surfaceTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.items[0]?.focus()
  }

  close() {
    this.surfaceTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  navigate(event) {
    if (event.key === "Escape") {
      this.close()
      this.triggerTarget.focus()
      return
    }
    if (!["ArrowDown", "ArrowUp", "Home", "End"].includes(event.key)) return
    event.preventDefault()
    const current = this.items.indexOf(document.activeElement)
    let index = event.key === "Home" ? 0 : event.key === "End" ? this.items.length - 1 : current
    index = event.key === "ArrowDown" ? (index + 1) % this.items.length : index
    index = event.key === "ArrowUp" ? (index - 1 + this.items.length) % this.items.length : index
    this.items[index]?.focus()
  }

  get items() {
    return Array.from(this.surfaceTarget.querySelectorAll("[role=menuitem]:not([aria-disabled=true])"))
  }
}
