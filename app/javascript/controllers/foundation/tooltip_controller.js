import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["anchor", "bubble"]

  connect() {
    this.show = () => { this.bubbleTarget.hidden = false }
    this.hide = () => { this.bubbleTarget.hidden = true }
    this.anchorTarget.addEventListener("focus", this.show)
    this.anchorTarget.addEventListener("blur", this.hide)
    this.anchorTarget.addEventListener("pointerenter", this.show)
    this.anchorTarget.addEventListener("pointerleave", this.hide)
  }

  disconnect() {
    this.anchorTarget.removeEventListener("focus", this.show)
    this.anchorTarget.removeEventListener("blur", this.hide)
    this.anchorTarget.removeEventListener("pointerenter", this.show)
    this.anchorTarget.removeEventListener("pointerleave", this.hide)
  }
}
