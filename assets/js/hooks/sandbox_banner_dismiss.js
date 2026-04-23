export const SandboxBannerDismiss = {
  mounted() {
    if (sessionStorage.getItem("sandbox-banner-dismissed") === "1") {
      this.el.style.display = "none"
      return
    }
    const btn = this.el.querySelector("#sandbox-banner-dismiss")
    if (!btn) return
    btn.addEventListener("click", () => {
      this.el.style.display = "none"
      sessionStorage.setItem("sandbox-banner-dismissed", "1")
    })
  }
}
