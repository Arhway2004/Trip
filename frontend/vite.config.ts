import { defineConfig, loadEnv } from 'vite'
import { devtools } from '@tanstack/devtools-vite'
import { paraglideVitePlugin } from '@inlang/paraglide-js'

import { tanstackStart } from '@tanstack/react-start/plugin/vite'

import viteReact from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { nitro } from 'nitro/vite'

const config = defineConfig(({ mode }) => {
  // Make .env values (API_BASE_URL, DEV_JWT_SECRET…) visible to server code via process.env.
  for (const [k, v] of Object.entries(loadEnv(mode, process.cwd(), '')))
    process.env[k] ??= v
  return {
    resolve: { tsconfigPaths: true },
    plugins: [
      devtools(),
      paraglideVitePlugin({
        project: './project.inlang',
        outdir: './src/paraglide',
        // Locale from a cookie, then the browser language; URLs stay locale-free.
        strategy: ['cookie', 'preferredLanguage', 'baseLocale'],
      }),
      nitro(),
      tailwindcss(),
      tanstackStart(),
      viteReact(),
    ],
  }
})

export default config
