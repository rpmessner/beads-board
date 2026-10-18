const key = "foreman:initiative-filters:v1"

export const rememberedFilters = () => {
  try {
    const value = JSON.parse(localStorage.getItem(key))
    return value && typeof value === "object" && !Array.isArray(value) ? value : {}
  } catch {
    return {}
  }
}

const disclosureKey = "foreman:initiative-filters-open:v1"

export const rememberedFiltersOpen = () => {
  try { return localStorage.getItem(disclosureKey) === "true" } catch { return false }
}

export const InitiativeFilters = {
  mounted() { this.remember() },
  updated() { this.remember() },
  remember() {
    try {
      localStorage.setItem(key, this.el.dataset.filters)
      localStorage.setItem(disclosureKey, this.el.dataset.filtersOpen)
    } catch { /* Storage may be disabled. */ }
  },
}
