// nuxt.config.ts
export default defineNuxtConfig({
  future: {
    compatibilityVersion: 4,
  },
  ssr: false,

  modules: [
    '@nuxt/ui',
    '@nuxt/fonts',
  ],

  css: ['~/assets/css/main.css'],

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
