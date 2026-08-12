import { useTheme } from '~/composables/useTheme'

/**
 * Reads the stored theme and wires the `prefers-color-scheme` listener before
 * the app renders. The inline script in nuxt.config has already stamped
 * `data-theme` to avoid a flash; this takes over the reactive side.
 */
export default defineNuxtPlugin(() => {
  useTheme().initTheme()
})
