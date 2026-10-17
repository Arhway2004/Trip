import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { apiClient, call, versionFromETag } from '#/lib/api/client.server'
import type { Result } from '#/lib/api/problem'
import type { Member, Trip, TripInput } from '#/lib/api/types'
import { getSessionToken } from '#/features/auth/session.server'
import { tripInputSchema } from './trip-schema'

const signedOut = {
  ok: false as const,
  problem: { status: 401, code: 'auth.missing_token' },
}

function client() {
  const token = getSessionToken()
  return token ? apiClient(token) : null
}

const tripId = z.object({ tripId: z.uuid() })

export const listTrips = createServerFn({ method: 'GET' })
  .validator(z.object({ includeArchived: z.boolean().default(false) }))
  .handler(async ({ data }): Promise<Result<Array<Trip>>> => {
    const api = client()
    if (!api) return signedOut
    return call(
      () =>
        api.GET('/v1/trips', {
          params: { query: { includeArchived: data.includeArchived } },
        }),
      (body) => body.items,
    )
  })

export const getTrip = createServerFn({ method: 'GET' })
  .validator(tripId)
  .handler(async ({ data }): Promise<Result<Trip>> => {
    const api = client()
    if (!api) return signedOut
    return call(() =>
      api.GET('/v1/trips/{tripId}', {
        params: { path: { tripId: data.tripId } },
      }),
    )
  })

export const listMembers = createServerFn({ method: 'GET' })
  .validator(tripId)
  .handler(async ({ data }): Promise<Result<Array<Member>>> => {
    const api = client()
    if (!api) return signedOut
    return call(
      () =>
        api.GET('/v1/trips/{tripId}/members', {
          params: { path: { tripId: data.tripId } },
        }),
      (body) => body.items,
    )
  })

export const createTrip = createServerFn({ method: 'POST' })
  .validator(tripInputSchema)
  .handler(async ({ data }): Promise<Result<Trip>> => {
    const api = client()
    if (!api) return signedOut
    // A client-generated id makes retries safe: the API returns the same trip.
    const body: TripInput = { ...data, id: data.id ?? crypto.randomUUID() }
    return call(() => api.POST('/v1/trips', { body }))
  })

export const updateTrip = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      version: z.number().int().positive(),
      input: tripInputSchema,
    }),
  )
  .handler(async ({ data }): Promise<Result<Trip>> => {
    const api = client()
    if (!api) return signedOut
    return call(
      () =>
        api.PUT('/v1/trips/{tripId}', {
          params: {
            path: { tripId: data.tripId },
            header: { 'If-Match': `"${data.version}"` },
          },
          body: data.input,
        }),
      (trip, response) => ({
        ...trip,
        version: versionFromETag(response) ?? trip.version,
      }),
    )
  })

export const deleteTrip = createServerFn({ method: 'POST' })
  .validator(
    z.object({ tripId: z.uuid(), version: z.number().int().positive() }),
  )
  .handler(async ({ data }): Promise<Result<null>> => {
    const api = client()
    if (!api) return signedOut
    return call(
      () =>
        api.DELETE('/v1/trips/{tripId}', {
          params: {
            path: { tripId: data.tripId },
            header: { 'If-Match': `"${data.version}"` },
          },
        }),
      () => null,
    )
  })
