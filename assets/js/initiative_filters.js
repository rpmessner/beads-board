const key = "board:initiative-filters:v1"

export const rememberedFilters = () => {
  try {
    const value = JSON.parse(localStorage.getItem(key))
    return value && typeof value === "object" && !Array.isArray(value) ? value : {}
  } catch {
    return {}
  }
}

export const InitiativeFilters = {
  mounted() { this.remember() },
  updated() { this.remember() },
  remember() {
    try { localStorage.setItem(key, this.el.dataset.filters) } catch { /* Storage may be disabled. */ }
  },
}
