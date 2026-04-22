export const RichTextEditor = {
  mounted() {
    this.editor = this.el.querySelector("[data-rt-editor]")
    this.hiddenInput = this.el.querySelector("[data-rt-input]")

    if (!this.editor || !this.hiddenInput) return

    if (this.hiddenInput.value) {
      this.editor.innerHTML = this.hiddenInput.value
    }

    this.onInput = () => {
      this.hiddenInput.value = this.editor.innerHTML
    }
    this.editor.addEventListener("input", this.onInput)

    this.onToolbarClick = (e) => {
      const btn = e.target.closest("[data-rt-command]")
      if (!btn) return
      e.preventDefault()
      const cmd = btn.dataset.rtCommand
      document.execCommand(cmd, false, null)
      this.editor.focus()
      this.onInput()
    }
    this.el.addEventListener("click", this.onToolbarClick)
  },

  updated() {
    if (!this.editor || !this.hiddenInput) return
    if (this.hiddenInput.value !== this.editor.innerHTML) {
      this.editor.innerHTML = this.hiddenInput.value
    }
  },

  destroyed() {
    if (this.editor && this.onInput) {
      this.editor.removeEventListener("input", this.onInput)
    }
    if (this.onToolbarClick) {
      this.el.removeEventListener("click", this.onToolbarClick)
    }
  }
}
