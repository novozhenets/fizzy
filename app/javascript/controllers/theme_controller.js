import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    this.applyStoredTheme()
    this.updateIcon()
  }

  toggle() {
    const currentTheme = document.documentElement.getAttribute("data-theme")
    // If no theme is set, check system preference or default to light
    let newTheme
    if (!currentTheme) {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
      newTheme = prefersDark ? "light" : "dark"
    } else {
      newTheme = currentTheme === "dark" ? "light" : "dark"
    }
    this.setTheme(newTheme)
    this.updateIcon()
  }

  setTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme)
    localStorage.setItem("theme", theme)
  }

  applyStoredTheme() {
    const storedTheme = localStorage.getItem("theme")
    if (storedTheme) {
      document.documentElement.setAttribute("data-theme", storedTheme)
    }
  }

  updateIcon() {
    const currentTheme = document.documentElement.getAttribute("data-theme")
    const isDark = currentTheme === "dark" ||
                   (!currentTheme && window.matchMedia("(prefers-color-scheme: dark)").matches)

    // Show moon icon in light mode, sun icon in dark mode
    if (this.hasSunIconTarget && this.hasMoonIconTarget) {
      this.sunIconTarget.style.display = isDark ? "block" : "none"
      this.moonIconTarget.style.display = isDark ? "none" : "block"
    }
  }
}
