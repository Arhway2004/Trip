import { createEnv } from '@t3-oss/env-core'
import { z } from 'zod'

/** Client-visible settings (must start with VITE_). Server settings live in lib/server/env.server.ts. */
export const env = createEnv({
  clientPrefix: 'VITE_',
  client: {
    VITE_APP_TITLE: z.string().min(1).default('WanderPlan'),
  },
  runtimeEnv: import.meta.env,
  emptyStringAsUndefined: true,
})
