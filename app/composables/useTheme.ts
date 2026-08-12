import { ref, computed } from 'vue'

export type ThemeMode = 'system' | 'light' | 'dark'

/**
 * Theme selection. `system` follows `prefers-color-scheme`; the two other modes
 * stamp `data-theme` on <html> and win over the media query (see main.css).
 *
 * Persisted in localStorage, NOT in the `settings` table, for two reasons: it
 * must be readable synchronously before the database opens — otherwise the
 * splash paints in the wrong theme and snaps — and it is a per-device choice
 * that has no business travelling inside a backup restored onto another phone.
 */
const STORAGE_KEY = 'statoo:theme'

const GROUND = { dark: '#0B120F', light: '#F2F5F3' } as const

const mode = ref<ThemeMode>('system')
const systemPrefersLight = ref(false)
let initialised = false

function isMode(value: unknown): value is ThemeMode {
  return value === 'system' || value === 'light' || value === 'dark'
}

/**
 * Rewrites the theme-color metas rather than relying on their media queries:
 * when a mode is forced, the media-matched tag would otherwise keep winning and
 * the iOS status bar would disagree with the app.
 */
function applyStatusBarColor(resolved: 'light' | 'dark') {
  const metas = document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')
  metas.forEach((meta, index) => {
    if (index === 0) {
      meta.removeAttribute('media')
      meta.content = GROUND[resolved]
    } else {
      meta.media = 'not all' // disabled, kept so the static HTML stays intact
    }
  })
}

export function useTheme() {
  const resolved = computed<'light' | 'dark'>(() => {
    if (mode.value === 'system') return systemPrefersLight.value ? 'light' : 'dark'
    return mode.value
  })

  function apply() {
    const root = document.documentElement
    if (mode.value === 'system') delete root.dataset.theme
    else root.dataset.theme = mode.value
    applyStatusBarColor(resolved.value)
  }

  function setMode(next: ThemeMode) {
    mode.value = next
    try {
      if (next === 'system') localStorage.removeItem(STORAGE_KEY)
      else localStorage.setItem(STORAGE_KEY, next)
    } catch {
      // Private mode or a locked-down WebView: the choice just will not persist
    }
    apply()
  }

  /** Called once from the client plugin. */
  function initTheme() {
    if (initialised) return
    initialised = true

    let stored: string | null = null
    try {
      stored = localStorage.getItem(STORAGE_KEY)
    } catch {
      stored = null
    }
    if (isMode(stored)) mode.value = stored

    const query = window.matchMedia('(prefers-color-scheme: light)')
    systemPrefersLight.value = query.matches
    query.addEventListener('change', (event) => {
      systemPrefersLight.value = event.matches
      if (mode.value === 'system') apply()
    })

    apply()
  }

  return { mode, resolved, setMode, initTheme }
}
