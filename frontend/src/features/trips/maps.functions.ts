import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { getSessionToken } from '#/features/auth/session.server'
import { apiClient, call } from '#/lib/api/client.server'
import type { Result } from '#/lib/api/problem'
import { resolveMapLink } from './maps-link.server'

const point = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
})
const roadModes = z.enum(['walking', 'cycling', 'driving'])
export interface RoadRoute {
  geometry: Array<[number, number]>
  durationMinutes: number
  distanceKm: number
  source: string
  fetchedAt: string
}
export interface SearchPlace {
  name: string
  lat: number
  lng: number
  address: string
  source: string
  sourceUrl?: string
}
// Shared provider queues enforce the public services' one-request/second policy.
const queues: Record<string, Promise<unknown>> = {}
const last: Record<string, number> = {}
const cache = new Map<string, { expires: number; value: unknown }>()
async function external(
  key: string,
  url: string,
  provider: string,
): Promise<unknown> {
  const existing = cache.get(key)
  if (existing && existing.expires > Date.now()) return existing.value
  const task = (queues[provider] ?? Promise.resolve())
    .catch(() => undefined)
    .then(async () => {
      const delay = Math.max(0, 1100 - (Date.now() - (last[provider] ?? 0)))
      if (delay) await new Promise((resolve) => setTimeout(resolve, delay))
      last[provider] = Date.now()
      const response = await fetch(url, {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'WanderPlan/1.0 (personal travel planner; Web)',
        },
        signal: AbortSignal.timeout(15000),
      })
      if (!response.ok) throw new Error('provider unavailable')
      const value: unknown = await response.json()
      if (cache.size >= 128) cache.delete(cache.keys().next().value!)
      cache.set(key, { value, expires: Date.now() + 30 * 60_000 })
      return value
    })
  queues[provider] = task
  return task
}
async function authorized(tripId: string) {
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
export const roadRoute = createServerFn({ method: 'GET' })
  .validator(
    z.object({ tripId: z.uuid(), mode: roadModes, from: point, to: point }),
  )
  .handler(async ({ data }): Promise<Result<RoadRoute>> => {
    const access = await authorized(data.tripId)
    if (!access.ok) return access
    const profile = {
      walking: 'routed-foot',
      cycling: 'routed-bike',
      driving: 'routed-car',
    }[data.mode]
    const coords = [data.from, data.to]
      .map((p) => `${p.lng.toFixed(6)},${p.lat.toFixed(6)}`)
      .join(';')
    try {
      const raw = await external(
        `${profile}:${coords}`,
        `https://routing.openstreetmap.de/${profile}/route/v1/driving/${coords}?overview=simplified&geometries=geojson&steps=false`,
        'routing',
      )
      const parsed = z
        .object({
          code: z.literal('Ok'),
          routes: z
            .array(
              z.object({
                duration: z.number().nonnegative(),
                distance: z.number().nonnegative(),
                geometry: z.object({
                  coordinates: z
                    .array(
                      z.tuple([
                        z.number().min(-180).max(180),
                        z.number().min(-90).max(90),
                      ]),
                    )
                    .min(2),
                }),
              }),
            )
            .min(1),
        })
        .parse(raw)
      const route = parsed.routes[0],
        coordinates = route.geometry.coordinates
      const stride = Math.max(1, Math.ceil((coordinates.length - 1) / 2999))
      const geometry = coordinates
        .filter(
          (_, index) =>
            index % stride === 0 || index === coordinates.length - 1,
        )
        .map(([lng, lat]): [number, number] => [lat, lng])
      return {
        ok: true,
        data: {
          geometry,
          durationMinutes: Math.ceil(route.duration / 60),
          distanceKm: route.distance / 1000,
          source: 'OSRM · FOSSGIS · OpenStreetMap',
          fetchedAt: new Date().toISOString(),
        },
      }
    } catch {
      return {
        ok: false,
        problem: { status: 503, code: 'routing.unavailable' },
      }
    }
  })
export const searchPlaces = createServerFn({ method: 'GET' })
  .validator(
    z.object({ tripId: z.uuid(), query: z.string().trim().min(2).max(200) }),
  )
  .handler(async ({ data }): Promise<Result<Array<SearchPlace>>> => {
    const access = await authorized(data.tripId)
    if (!access.ok) return access
    try {
      const raw = await external(
        data.query.toLowerCase(),
        `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=${encodeURIComponent(data.query)}`,
        'search',
      )
      const places = z
        .array(
          z.object({
            display_name: z.string(),
            lat: z.string(),
            lon: z.string(),
          }),
        )
        .parse(raw)
      const result = places
        .map((row) => ({
          name: row.display_name.split(',')[0],
          address: row.display_name,
          lat: Number(row.lat),
          lng: Number(row.lon),
          source: 'search:openstreetmap-nominatim',
        }))
        .filter(
          (row) =>
            Number.isFinite(row.lat) &&
            Number.isFinite(row.lng) &&
            Math.abs(row.lat) <= 90 &&
            Math.abs(row.lng) <= 180,
        )
      return { ok: true, data: result }
    } catch {
      return { ok: false, problem: { status: 503, code: 'search.unavailable' } }
    }
  })

export const importMapLink = createServerFn({ method: 'POST' })
  .validator(
    z.object({ tripId: z.uuid(), url: z.string().trim().min(8).max(4096) }),
  )
  .handler(
    async ({
      data,
    }): Promise<Result<{ pin?: SearchPlace; query?: string }>> => {
      const access = await authorized(data.tripId)
      if (!access.ok) return access
      try {
        const parsed = await resolveMapLink(data.url)
        return {
          ok: true,
          data:
            parsed.kind === 'pin'
              ? {
                  pin: {
                    name: parsed.name,
                    lat: parsed.lat,
                    lng: parsed.lng,
                    address: `${parsed.lat}, ${parsed.lng}`,
                    source: 'google-maps-shared-pin',
                    sourceUrl: parsed.url,
                  },
                }
              : { query: parsed.query },
        }
      } catch {
        return {
          ok: false,
          problem: { status: 422, code: 'maps.invalid_link' },
        }
      }
    },
  )

export interface RoadMatrix {
  minutes: Array<Array<number | null>>
  source: string
  fetchedAt: string
}
export const roadMatrix = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      mode: roadModes,
      stops: z.array(point).min(2).max(8),
    }),
  )
  .handler(async ({ data }): Promise<Result<RoadMatrix>> => {
    const access = await authorized(data.tripId)
    if (!access.ok) return access
    const profile = {
      walking: 'routed-foot',
      cycling: 'routed-bike',
      driving: 'routed-car',
    }[data.mode]
    const coordinates = data.stops
      .map((p) => `${p.lng.toFixed(6)},${p.lat.toFixed(6)}`)
      .join(';')
    try {
      const raw = await external(
        `table:${profile}:${coordinates}`,
        `https://routing.openstreetmap.de/${profile}/table/v1/driving/${coordinates}?annotations=duration`,
        'routing',
      )
      const parsed = z
        .object({
          code: z.literal('Ok'),
          durations: z.array(
            z.array(z.number().nonnegative().finite().nullable()),
          ),
        })
        .parse(raw)
      if (
        parsed.durations.length !== data.stops.length ||
        parsed.durations.some((row) => row.length !== data.stops.length)
      )
        throw new Error('invalid matrix')
      return {
        ok: true,
        data: {
          minutes: parsed.durations.map((row) =>
            row.map((seconds) =>
              seconds === null ? null : Math.ceil(seconds / 60),
            ),
          ),
          source: 'OSRM · FOSSGIS · OpenStreetMap',
          fetchedAt: new Date().toISOString(),
        },
      }
    } catch {
      return {
        ok: false,
        problem: { status: 503, code: 'routing.unavailable' },
      }
    }
  })

export const fetchExchangeRate = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      from: z.string().regex(/^[A-Z]{3}$/),
      to: z.string().regex(/^[A-Z]{3}$/),
    }),
  )
  .handler(
    async ({
      data,
    }): Promise<Result<{ rate: number; date: string; source: string }>> => {
      const access = await authorized(data.tripId)
      if (!access.ok) return access
      try {
        const raw = await external(
          `fx:${data.from}:${data.to}`,
          `https://api.frankfurter.dev/v1/latest?base=${data.from}&symbols=${data.to}`,
          'exchange',
        )
        const parsed = z
          .object({
            date: z.string(),
            rates: z.record(z.string(), z.number().positive()),
          })
          .parse(raw)
        const rate = parsed.rates[data.to]
        if (!rate) throw new Error('unsupported currency')
        return {
          ok: true,
          data: {
            rate,
            date: parsed.date,
            source: 'Frankfurter · central-bank reference',
          },
        }
      } catch {
        return {
          ok: false,
          problem: { status: 503, code: 'exchange.unavailable' },
        }
      }
    },
  )

export const nearbyPlaces = createServerFn({ method: 'POST' })
  .validator(
    z.object({
      tripId: z.uuid(),
      center: point,
      category: z.enum([
        'attraction',
        'restaurant',
        'hotel',
        'airport',
        'railwayStation',
      ]),
      radius: z.number().min(100).max(3000),
    }),
  )
  .handler(async ({ data }): Promise<Result<Array<SearchPlace>>> => {
    const access = await authorized(data.tripId)
    if (!access.ok) return access
    const tags = {
      attraction: '["tourism"~"attraction|museum|viewpoint"]',
      restaurant: '["amenity"="restaurant"]',
      hotel: '["tourism"="hotel"]',
      airport: '["aeroway"="aerodrome"]',
      railwayStation: '["railway"="station"]',
    }[data.category]
    const query = `[out:json][timeout:12];nwr${tags}(around:${data.radius},${data.center.lat},${data.center.lng});out center 30;`
    try {
      const raw = await external(
        `nearby:${query}`,
        `https://overpass-api.de/api/interpreter?data=${encodeURIComponent(query)}`,
        'search',
      )
      const parsed = z
        .object({
          elements: z.array(
            z.object({
              lat: z.number().optional(),
              lon: z.number().optional(),
              center: z.object({ lat: z.number(), lon: z.number() }).optional(),
              tags: z.record(z.string(), z.string()).optional(),
            }),
          ),
        })
        .parse(raw)
      return {
        ok: true,
        data: parsed.elements.flatMap((row) => {
          const lat = row.lat ?? row.center?.lat,
            lng = row.lon ?? row.center?.lon
          return lat != null && lng != null && row.tags?.name
            ? [
                {
                  name: row.tags.name,
                  lat,
                  lng,
                  address: row.tags['addr:full'] || '',
                  source: 'OpenStreetMap · Overpass',
                },
              ]
            : []
        }),
      }
    } catch {
      return { ok: false, problem: { status: 503, code: 'search.unavailable' } }
    }
  })
