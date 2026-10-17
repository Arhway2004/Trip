import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { getSessionToken } from '#/features/auth/session.server'
import { apiClient, call } from '#/lib/api/client.server'
import type { Result } from '#/lib/api/problem'
import { serverEnv } from '#/lib/server/env.server'
import { searchFlights, searchTransit } from './transport/providers.server'
import { zonedTimestamp } from './transport/model'
import type { TransportOffer, TransportStatus } from './transport/model'

const point = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
})
const searches = new Map<string, { count: number; until: number }>()
async function access(tripId: string) {
  const token = getSessionToken()
  if (!token)
    return {
      ok: false as const,
      problem: { status: 401, code: 'auth.missing_token' },
    }
  return call(() =>
    apiClient(token).GET('/v1/trips/{tripId}', {
      params: { path: { tripId } },
    }),
  )
}
export const transportStatus = createServerFn({ method: 'GET' })
  .validator(z.object({ tripId: z.uuid() }))
  .handler(async ({ data }): Promise<Result<TransportStatus>> => {
    const authorized = await access(data.tripId)
    if (!authorized.ok) return authorized
    const config = serverEnv()
    return {
      ok: true,
      data: {
        flights: !!config.DUFFEL_ACCESS_TOKEN?.startsWith('duffel_live_'),
        transit: !!config.HERE_TRANSIT_API_KEY,
      },
    }
  })
export const liveTransport = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      mode: z.enum(['train', 'bus', 'flight']),
      date: z.iso.date(),
      clock: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
      from: point.optional(),
      to: point.optional(),
      origin: z
        .string()
        .regex(/^[A-Z]{3}$/)
        .optional(),
      destination: z
        .string()
        .regex(/^[A-Z]{3}$/)
        .optional(),
      adults: z.number().int().min(1).max(9),
    }),
  )
  .handler(async ({ data }): Promise<Result<Array<TransportOffer>>> => {
    const authorized = await access(data.tripId)
    if (!authorized.ok) return authorized
    const config = serverEnv()
    if (
      data.mode === 'flight'
        ? !config.DUFFEL_ACCESS_TOKEN?.startsWith('duffel_live_')
        : !config.HERE_TRANSIT_API_KEY
    )
      return {
        ok: false,
        problem: { status: 503, code: 'transport.not_configured' },
      }
    const limit = searches.get(data.tripId),
      now = Date.now()
    if (limit && limit.until > now && limit.count >= 6)
      return {
        ok: false,
        problem: { status: 429, code: 'transport.rate_limit' },
      }
    if (searches.size >= 128) searches.delete(searches.keys().next().value!)
    searches.set(data.tripId, {
      count: limit && limit.until > now ? limit.count + 1 : 1,
      until: limit && limit.until > now ? limit.until : now + 60000,
    })
    try {
      if (data.mode === 'flight') {
        if (!data.origin || !data.destination)
          return {
            ok: false,
            problem: { status: 422, code: 'transport.airports_required' },
          }
        return {
          ok: true,
          data: await searchFlights(config.DUFFEL_ACCESS_TOKEN!, {
            origin: data.origin,
            destination: data.destination,
            date: data.date,
            adults: data.adults,
          }),
        }
      }
      if (!data.from || !data.to)
        return {
          ok: false,
          problem: { status: 422, code: 'transport.coordinates_required' },
        }
      const departure = zonedTimestamp(
        data.date,
        data.clock,
        authorized.data.timeZone || 'UTC',
      )
      return {
        ok: true,
        data: await searchTransit(config.HERE_TRANSIT_API_KEY!, {
          from: data.from,
          to: data.to,
          departure,
          mode: data.mode,
        }),
      }
    } catch {
      return {
        ok: false,
        problem: { status: 503, code: 'transport.unavailable' },
      }
    }
  })
