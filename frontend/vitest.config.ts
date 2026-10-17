import { defineConfig } from 'vitest/config'
import viteReact from '@vitejs/plugin-react'

// Tests don't need the Start/Nitro/devtools plugins from vite.config.ts.
export default defineConfig({
  resolve: { tsconfigPaths: true },
  plugins: [viteReact()],
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{ts,tsx}'],
    setupFiles: ['src/test/setup.ts'],
  },
})
