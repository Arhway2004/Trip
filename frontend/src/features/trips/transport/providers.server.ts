import { z } from 'zod'
import { isoDurationMinutes, zonedTimestamp } from './model'
import type { TransportOffer } from './model'

const place = z.object({ time_zone: z.string(), iata_code: z.string() })
const segment = z.object({
  departing_at: z.string(),
  arriving_at: z.string(),
  origin: place,
  destination: place,
  operating_carrier: z.object({ name: z.string() }),
  operating_carrier_flight_number: z.string().optional(),
})
const flight = z.object({
  id: z.string(),
  live_mode: z.literal(true),
  total_amount: z.string(),
  total_currency: z.string().regex(/^[A-Z]{3}$/),
  expires_at: z.iso.datetime(),
  slices: z
    .array(
      z.object({ duration: z.string(), segments: z.array(segment).min(1) }),
    )
    .length(1),
})
export function parseFlightOffers(
  raw: unknown,
  travelers: number,
  now = new Date(),
): Array<TransportOffer> {
  const data = z
    .object({
      data: z.object({
        live_mode: z.literal(true),
        offers: z.array(z.unknown()),
      }),
    })
    .parse(raw).data
  return data.offers
    .flatMap((value) => {
      const parsed = flight.safeParse(value)
      if (!parsed.success) return []
      const offer = parsed.data,
        slice = offer.slices[0],
        first = slice.segments[0],
        last = slice.segments.at(-1)!,
        amount = Number(offer.total_amount)
      if (
        !Number.isFinite(amount) ||
        amount < 0 ||
        Date.parse(offer.expires_at) <= now.getTime()
      )
        return []
      const departure = zonedTimestamp(
          first.departing_at.slice(0, 10),
          first.departing_at.slice(11, 16),
          first.origin.time_zone,
        ),
        arrival = zonedTimestamp(
          last.arriving_at.slice(0, 10),
          last.arriving_at.slice(11, 16),
          last.destination.time_zone,
        )
      if (Date.parse(arrival) <= Date.parse(departure)) return []
      return [
        {
          id: offer.id,
          mode: 'flight' as const,
          source: 'Duffel' as const,
          fetchedAt: now.toISOString(),
          departure,
          arrival,
          durationMinutes: isoDurationMinutes(slice.duration),
          amount,
          currency: offer.total_currency,
          priceScope: 'party' as const,
          travelers,
          expiresAt: offer.expires_at,
          operator: [
            ...new Set(
              slice.segments.map((part) => part.operating_carrier.name),
            ),
          ].join(' / '),
          service: slice.segments
            .map((part) => part.operating_carrier_flight_number || '')
            .filter(Boolean)
            .join(' / '),
          details: slice.segments.map(
            (part) =>
              `${part.origin.iata_code} → ${part.destination.iata_code} · ${part.operating_carrier.name} ${part.operating_carrier_flight_number || ''}`,
          ),
          attributions: ['Flight offers supplied by Duffel'],
        },
      ]
    })
    .slice(0, 12)
}
const transitPoint = z.object({
  time: z.string().datetime({ offset: true }),
  place: z.object({ name: z.string().optional() }).optional(),
})
const transitSection = z.object({
  departure: transitPoint,
  arrival: transitPoint,
  transport: z
    .object({
      mode: z.string(),
      name: z.string().optional(),
      shortName: z.string().optional(),
    })
    .optional(),
  agency: z.object({ name: z.string().optional() }).optional(),
  attributions: z.array(z.object({ text: z.string().optional() })).optional(),
})
export function parseTransitOffers(
  raw: unknown,
  mode: 'train' | 'bus',
  now = new Date(),
): Array<TransportOffer> {
  const data = z
    .object({
      routes: z.array(
        z.object({ id: z.string(), sections: z.array(transitSection).min(1) }),
      ),
    })
    .parse(raw)
  const rail = new Set([
    'highSpeedTrain',
    'intercityTrain',
    'interRegionalTrain',
    'regionalTrain',
    'cityTrain',
    'subway',
    'lightRail',
    'monorail',
  ])
  return data.routes
    .flatMap((route) => {
      const sections = route.sections,
        hasMode = sections.some((section) =>
          mode === 'train'
            ? rail.has(section.transport?.mode || '')
            : ['bus', 'privateBus', 'busRapid'].includes(
                section.transport?.mode || '',
              ),
        )
      if (!hasMode) return []
      const departure = sections[0].departure.time,
        arrival = sections.at(-1)!.arrival.time,
        durationMinutes = Math.ceil(
          (Date.parse(arrival) - Date.parse(departure)) / 60000,
        )
      if (durationMinutes <= 0) return []
      return [
        {
          id: route.id,
          mode,
          source: 'HERE' as const,
          fetchedAt: now.toISOString(),
          departure,
          arrival,
          durationMinutes,
          operator:
            [
              ...new Set(
                sections.map((section) => section.agency?.name).filter(Boolean),
              ),
            ].join(' / ') || 'HERE Transit',
          service: sections
            .map(
              (section) =>
                section.transport?.shortName || section.transport?.name,
            )
            .filter(Boolean)
            .join(' / '),
          details: sections.map((section) =>
            [section.departure.place?.name, section.arrival.place?.name]
              .filter(Boolean)
              .join(' → '),
          ),
          attributions: [
            ...new Set([
              'Transit schedules supplied by HERE',
              ...sections
                .flatMap((section) =>
                  (section.attributions ?? []).map((row) => row.text || ''),
                )
                .filter(Boolean),
            ]),
          ],
        },
      ]
    })
    .slice(0, 6)
}
async function jsonFetch(url: string, options: RequestInit) {
  const response = await fetch(url, {
    ...options,
    signal: AbortSignal.timeout(25000),
  })
  if (!response.ok) throw new Error('transport provider unavailable')
  return response.json() as Promise<unknown>
}
export async function searchFlights(
  token: string,
  input: { origin: string; destination: string; date: string; adults: number },
): Promise<Array<TransportOffer>> {
  if (!token.startsWith('duffel_live_'))
    throw new Error('live flight token required')
  const response = await jsonFetch(
    'https://api.duffel.com/air/offer_requests?return_offers=true&supplier_timeout=15000',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Duffel-Version': 'v2',
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        data: {
          slices: [
            {
              origin: input.origin,
              destination: input.destination,
              departure_date: input.date,
            },
          ],
          passengers: Array.from({ length: input.adults }, () => ({
            type: 'adult',
          })),
          cabin_class: 'economy',
          max_connections: 1,
        },
      }),
    },
  )
  return parseFlightOffers(response, input.adults)
}
export async function searchTransit(
  key: string,
  input: {
    from: { lat: number; lng: number }
    to: { lat: number; lng: number }
    departure: string
    mode: 'train' | 'bus'
  },
): Promise<Array<TransportOffer>> {
  const url = new URL('https://transit.router.hereapi.com/v8/routes')
  url.searchParams.set('apiKey', key)
  url.searchParams.set('origin', `${input.from.lat},${input.from.lng}`)
  url.searchParams.set('destination', `${input.to.lat},${input.to.lng}`)
  url.searchParams.set('departureTime', input.departure)
  url.searchParams.set('alternatives', '3')
  url.searchParams.set(
    'modes',
    input.mode === 'train'
      ? 'highSpeedTrain,intercityTrain,interRegionalTrain,regionalTrain,cityTrain,subway,lightRail,monorail'
      : 'bus,privateBus,busRapid',
  )
  return parseTransitOffers(
    await jsonFetch(url.toString(), {
      headers: { Accept: 'application/json' },
    }),
    input.mode,
  )
}
