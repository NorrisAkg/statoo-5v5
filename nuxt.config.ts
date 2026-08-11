// nuxt.config.ts
export default defineNuxtConfig({
  future: {
    compatibilityVersion: 4,
  },
  ssr: false,

  modules: [
    '@nuxt/ui',
    '@nuxt/fonts',
    '@vite-pwa/nuxt',
  ],

  css: ['~/assets/css/main.css'],

  app: {
    head: {
      htmlAttrs: { lang: 'fr' },
      title: 'Statoo',
      // viewport-fit=cover so env(safe-area-inset-*) resolves on notched iPhones
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, viewport-fit=cover' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-title', content: 'Statoo' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
        // One per scheme, or the iOS status bar keeps a single colour and
        // clashes with the theme the app actually renders.
        { name: 'theme-color', content: '#0B120F', media: '(prefers-color-scheme: dark)' },
        { name: 'theme-color', content: '#F2F5F3', media: '(prefers-color-scheme: light)' },
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: '/favicon-32.png' },
        // iOS ignores the manifest icons for the home screen
        { rel: 'apple-touch-icon', href: '/apple-touch-icon.png' },
        // Declared statically: the module only injects this link at runtime,
        // and Safari's "Add to Home Screen" should not depend on hydration.
        { rel: 'manifest', href: '/manifest.webmanifest' },
      ],
    },
  },

  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'Statoo',
      short_name: 'Statoo',
      description: 'Journal personnel · hors ligne',
      lang: 'fr',
      start_url: '/',
      scope: '/',
      display: 'standalone',
      orientation: 'portrait',
      background_color: '#0B120F',
      theme_color: '#0B120F',
      icons: [
        { src: '/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: '/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: '/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
      ],
    },
    workbox: {
      // .wasm is not in the default glob, and without it the SQLite driver
      // cannot boot offline — the app would be a blank screen on a plane.
      globPatterns: ['**/*.{js,css,html,png,svg,ico,woff2,wasm}'],
      maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
      // SPA: any deep link resolves to the shell
      navigateFallback: '/',
    },
    devOptions: { enabled: false },
  },

  fonts: {
    families: [
      { name: 'Archivo Expanded', provider: 'google', weights: [600, 700] },
      { name: 'Instrument Sans', provider: 'google', weights: [400, 500, 600] },
    ],
  },

  vue: {
    compilerOptions: {
      isCustomElement: (tag) => tag.startsWith('jeep-'),
    },
  },

  nitro: {
    serveStatic: true,
  },

  vite: {
    assetsInclude: ['**/*.wasm'],
    server: {
      fs: {
        strict: false,
      },
    },
    plugins: [
      {
        name: 'patch-jeep-sqlite-localforage',
        transform(code, id) {
          if (id.includes('jeep-sqlite.entry') || id.includes('chunk-') || id.includes('jeep-sqlite')) {
            if (code.includes('const localForage = localforage.exports;')) {
              return {
                code: code.replace(
                  'const localForage = localforage.exports;',
                  'const localForage = (typeof window !== "undefined" && window.localforage) ? window.localforage : (localforage.exports || localforage.default || localforage);'
                ),
                map: null
              }
            }
          }
        }
      }
    ]
  },

  compatibilityDate: '2026-08-10',
})
