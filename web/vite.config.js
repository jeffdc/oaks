import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import { VitePWA } from 'vite-plugin-pwa'
import { copyFileSync } from 'fs'
import { resolve } from 'path'

// Copy quercus_data.json from parent directory to public folder before build
const copyDataFile = () => ({
  name: 'copy-data-file',
  buildStart() {
    const source = resolve(__dirname, '../quercus_data.json')
    const dest = resolve(__dirname, 'public/quercus_data.json')
    try {
      copyFileSync(source, dest)
      console.log('✓ Copied quercus_data.json to public folder')
    } catch (err) {
      console.error('Error copying quercus_data.json:', err.message)
    }
  }
})

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    svelte(),
    copyDataFile(),
    VitePWA({
      registerType: 'prompt',
      includeAssets: ['quercus_data.json'],
      manifest: {
        name: 'Oaks of the World',
        short_name: 'Oak Browser',
        description: 'Browse and explore Quercus (oak) species data',
        theme_color: '#2c5f2d',
        background_color: '#ffffff',
        display: 'standalone',
        icons: [
          {
            src: '/icon-192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: '/icon-512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,json,svg,png,ico}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/fonts\.googleapis\.com\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'google-fonts-cache',
              expiration: {
                maxEntries: 10,
                maxAgeSeconds: 60 * 60 * 24 * 365 // 1 year
              },
              cacheableResponse: {
                statuses: [0, 200]
              }
            }
          }
        ]
      }
    })
  ],
})
