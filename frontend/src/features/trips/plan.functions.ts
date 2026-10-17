import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { getSessionToken } from '#/features/auth/session.server'
import { apiClient, call } from '#/lib/api/client.server'
import type { Result } from '#/lib/api/problem'

export interface SavedPlan {
  version: number
  documentJson: string
  media: Record<string, string>
}
const signedOut = {
  ok: false as const,
  problem: { status: 401, code: 'auth.missing_token' },
}
const tripId = z.object({ tripId: z.uuid() })

export const getPlan = createServerFn({ method: 'GET' })
  .validator(tripId)
  .handler(async ({ data }): Promise<Result<SavedPlan>> => {
    const token = getSessionToken()
    if (!token) return signedOut
    return call(
      () =>
        apiClient(token).GET('/v1/trips/{tripId}/plan', {
          params: { path: { tripId: data.tripId } },
        }),
      (body) => ({
        version: body.version,
        documentJson: JSON.stringify(body.document),
        media: body.media,
      }),
    )
  })

export const savePlan = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      version: z.number().int().nonnegative(),
      documentJson: z.string().max(5 * 1024 * 1024),
      media: z.record(z.string(), z.string()),
    }),
  )
  .handler(async ({ data }): Promise<Result<SavedPlan>> => {
    const token = getSessionToken()
    if (!token) return signedOut
    let document: Record<string, unknown>
    try {
      document = JSON.parse(data.documentJson) as Record<string, unknown>
    } catch {
      return { ok: false, problem: { status: 422, code: 'plan.invalid_json' } }
    }
    return call(
      () =>
        apiClient(token).PUT('/v1/trips/{tripId}/plan', {
          params: {
            path: { tripId: data.tripId },
            header: { 'If-Match': `"${data.version}"` },
          },
          body: { document, media: data.media },
        }),
      (body) => ({
        version: body.version,
        documentJson: JSON.stringify(body.document),
        media: body.media,
      }),
    )
  })

export const exportPlan = createServerFn({ method: 'GET' })
  .validator(tripId)
  .handler(async ({ data }): Promise<Result<{ base64: string }>> => {
    const token = getSessionToken()
    if (!token) return signedOut
    return call(
      () =>
        apiClient(token).GET('/v1/trips/{tripId}/export', {
          params: { path: { tripId: data.tripId } },
          parseAs: 'arrayBuffer',
        }),
      (body) => ({ base64: Buffer.from(body).toString('base64') }),
    )
  })
