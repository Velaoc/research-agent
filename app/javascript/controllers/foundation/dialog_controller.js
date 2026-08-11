import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    this.trigger = event?.currentTarget
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.trigger?.focus()
  }

  cancel() {
    window.requestAnimationFrame(() => this.trigger?.focus())
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
