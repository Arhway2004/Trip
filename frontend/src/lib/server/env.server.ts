import { z } from 'zod'

/**
 * Server-only configuration, validated on first use. Never import this from
 * client code: it can contain secrets.
 */
const schema = z
  .object({
    NODE_ENV: z.string().default('development'),
    /** Base URL of the Go API (see ../backend). */
    API_BASE_URL: z.url().default('http://localhost:8080'),
    /** Must match the backend's AUTH_MODE. */
    AUTH_MODE: z.enum(['dev', 'oidc']).default('dev'),
    /** Must match the backend's DEV_JWT_SECRET when AUTH_MODE=dev. */
    DEV_JWT_SECRET: z.string().min(32).optional(),
    HERE_TRANSIT_API_KEY: z.string().min(1).optional(),
    DUFFEL_ACCESS_TOKEN: z.string().min(1).optional(),
  })
  .superRefine((v, ctx) => {
    if (v.AUTH_MODE === 'dev' && !v.DEV_JWT_SECRET) {
      ctx.addIssue({
        code: 'custom',
        path: ['DEV_JWT_SECRET'],
        message: 'required when AUTH_MODE=dev',
      })
    }
    if (v.AUTH_MODE === 'dev' && v.NODE_ENV === 'production') {
      ctx.addIssue({
        code: 'custom',
        path: ['AUTH_MODE'],
        message: 'dev sign-in is not allowed in production',
      })
    }
  })

export type ServerEnv = z.infer<typeof schema>

let cached: ServerEnv | undefined

export function serverEnv(): ServerEnv {
  cached ??= schema.parse(process.env)
  return cached
}
