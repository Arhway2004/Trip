import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { apiClient, call } from '#/lib/api/client.server'
import { serverEnv } from '#/lib/server/env.server'
import type { Problem, Result } from '#/lib/api/problem'
import type { User } from '#/lib/api/types'
import {
  clearSession,
  getSessionToken,
  mintDevToken,
  setSessionToken,
} from './session.server'

export interface Session {
  user: User | null
  authMode: 'dev' | 'oidc'
  /** Set when the API could not be reached (the page shows a banner). */
  problem?: Problem
}

/** Current user from the session cookie, or null when signed out. */
export const getSession = createServerFn({ method: 'GET' }).handler(
  async (): Promise<Session> => {
    const authMode = serverEnv().AUTH_MODE
    const token = getSessionToken()
    if (!token) return { user: null, authMode }
    const result = await call(() => apiClient(token).GET('/v1/me'))
    if (result.ok) return { user: result.data, authMode }
    if (result.problem.status === 401) {
      clearSession() // expired or revoked
      return { user: null, authMode }
    }
    return { user: null, authMode, problem: result.problem }
  },
)

const devSignInInput = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.email(),
})

export const signInDev = createServerFn({ method: 'POST' })
  .validator(devSignInInput)
  .handler(async ({ data }): Promise<Result<User>> => {
    if (serverEnv().AUTH_MODE !== 'dev') {
      return { ok: false, problem: { status: 400, code: 'auth.dev_disabled' } }
    }
    const token = await mintDevToken(data)
    // Calling /v1/me creates the user on first sign-in and proves the token works.
    const result = await call(() => apiClient(token).GET('/v1/me'))
    if (result.ok) setSessionToken(token)
    return result
  })

export const signOut = createServerFn({ method: 'POST' }).handler(async () => {
  clearSession()
  return { ok: true as const }
})
