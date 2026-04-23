import {computePosition, autoUpdate, offset, flip, shift} from "../../vendor/floating-ui.dom"

const OPEN_DELAY_MS = 80
const CLOSE_DELAY_MS = 120

export const Popover = {
  mounted() {
    this.trigger = this.el
    const id = this.el.dataset.popoverTarget
    this.panel = id ? document.getElementById(id) : null
    if (!this.panel) return

    this.panel.setAttribute("role", "tooltip")
    this.panel.classList.remove("hidden")
    this.panel.style.display = "none"
    this.panel.style.position = "fixed"
    this.panel.style.top = "0"
    this.panel.style.left = "0"
    this.panel.style.zIndex = "1000"

    this.openTimer = null
    this.closeTimer = null
    this.cleanupAutoUpdate = null

    this.open = () => {
      clearTimeout(this.closeTimer)
      if (this.panel.style.display !== "none") return
      this.openTimer = setTimeout(() => {
        this.panel.style.display = "block"
        this.cleanupAutoUpdate = autoUpdate(this.trigger, this.panel, () => {
          computePosition(this.trigger, this.panel, {
            strategy: "fixed",
            placement: "bottom",
            middleware: [offset(6), flip({padding: 8}), shift({padding: 8})],
          }).then(({x, y}) => {
            Object.assign(this.panel.style, {left: `${x}px`, top: `${y}px`})
          })
        })
      }, OPEN_DELAY_MS)
    }

    this.close = () => {
      clearTimeout(this.openTimer)
      this.closeTimer = setTimeout(() => {
        this.panel.style.display = "none"
        if (this.cleanupAutoUpdate) {
          this.cleanupAutoUpdate()
          this.cleanupAutoUpdate = null
        }
      }, CLOSE_DELAY_MS)
    }

    this.trigger.addEventListener("mouseenter", this.open)
    this.trigger.addEventListener("mouseleave", this.close)
    this.trigger.addEventListener("focusin", this.open)
    this.trigger.addEventListener("focusout", this.close)
    this.panel.addEventListener("mouseenter", this.open)
    this.panel.addEventListener("mouseleave", this.close)
  },

  destroyed() {
    clearTimeout(this.openTimer)
    clearTimeout(this.closeTimer)
    if (this.cleanupAutoUpdate) this.cleanupAutoUpdate()
    if (!this.panel) return
    this.trigger.removeEventListener("mouseenter", this.open)
    this.trigger.removeEventListener("mouseleave", this.close)
    this.trigger.removeEventListener("focusin", this.open)
    this.trigger.removeEventListener("focusout", this.close)
    this.panel.removeEventListener("mouseenter", this.open)
    this.panel.removeEventListener("mouseleave", this.close)
  },
}
