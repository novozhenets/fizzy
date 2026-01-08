import { BridgeComponent } from "@hotwired/hotwire-native-bridge"
import { viewport } from "bridge/helpers/viewport"
import { nextFrame } from "helpers/timing_helpers"

export default class extends BridgeComponent {
  static component = "page"
  static targets = [ "header" ]
  static values = { title: String }

  async connect() {
    super.connect()
    this.notifyBridgeOfPageChange()
    await nextFrame()
    this.startObserver()
    window.addEventListener("resize", this.windowResized)
  }

  disconnect() {
    super.disconnect()
    this.stopObserver()
    window.removeEventListener("resize", this.windowResized)
  }

  receive(message) {
    switch (message.event) {
    case "set-text-size":
      this.setTextSize(message.data)
      break
    }
  }

  setTextSize(data) {
    document.documentElement.dataset.textSize = data.textSize
  }

  // Bridge

  notifyBridgeOfPageChange() {
    const data = {
      title: this.title,
      url: window.location.href
    }

    if (this.hasHeaderTarget) {
      // Assume header visible by default until we get IntersectionObserver update
      data.elementVisible = true
    }

    this.send("change", data, message => this.receive(message))
  }

  notifyBridgeOfVisibilityChange(visible) {
    this.send("visibility", { title: this.title, elementVisible: visible })
  }

  // Intersection Observer

  startObserver() {
    if (!this.hasHeaderTarget) return

    this.observer = new IntersectionObserver(([ entry ]) =>
      this.notifyBridgeOfVisibilityChange(entry.isIntersecting),
      { rootMargin: `-${this.topOffset}px 0px 0px 0px` }
    )

    this.observer.observe(this.headerTarget)
    this.previousTopOffset = this.topOffset
  }

  stopObserver() {
    this.observer?.disconnect()
  }

  updateObserverIfNeeded() {
    if (this.topOffset === this.previousTopOffset) return

    this.stopObserver()
    this.startObserver()
  }

  windowResized = () => {
    this.updateObserverIfNeeded()
  }

  get title() {
    return this.titleValue ? this.titleValue : document.title
  }

  get topOffset() {
    return viewport.top
  }
}
