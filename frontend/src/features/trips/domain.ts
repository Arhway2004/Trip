// Trip rules shared with the mobile app (mobile/lib/contexts/trip/domain):
// status and countdown are computed in the trip's own time zone.
import type { Trip } from '#/lib/api/types'

export type TripStatus =
  'dreaming' | 'planning' | 'upcoming' | 'traveling' | 'completed' | 'archived'
export type TripFilter =
  'all' | 'upcoming' | 'traveling' | 'completed' | 'archived'
export const tripFilters: ReadonlyArray<TripFilter> = [
  'all',
  'upcoming',
  'traveling',
  'completed',
  'archived',
]

export type Countdown =
  | { kind: 'none' }
  | { kind: 'before'; days: number }
  | { kind: 'during'; day: number; total: number }
  | { kind: 'completed' }

type DatedTrip = Pick<
  Trip,
  'startDate' | 'endDate' | 'departureTime' | 'timeZone'
>

function zonedParts(timeZone: string, now: Date) {
  let zone = timeZone
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: zone })
  } catch {
    zone = 'UTC' // unknown zones never crash the UI
  }
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now)
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '00'
  return {
    date: `${get('year')}-${get('month')}-${get('day')}`,
    minutes: Number(get('hour')) * 60 + Number(get('minute')),
  }
}

/** Calendar date ("YYYY-MM-DD") right now in `timeZone`. */
export function todayIn(timeZone: string, now: Date): string {
  return zonedParts(timeZone, now).date
}

/** Whole days from date a to date b (both "YYYY-MM-DD"). */
export function daysBetween(a: string, b: string): number {
  const ms = Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)
  return Math.round(ms / 86_400_000)
}

export function durationDays(
  trip: Pick<Trip, 'startDate' | 'endDate'>,
): number | null {
  if (!trip.startDate) return null
  const end = trip.endDate ?? trip.startDate
  return Math.max(1, daysBetween(trip.startDate, end) + 1)
}

export function countdown(trip: DatedTrip, now: Date): Countdown {
  if (!trip.startDate) return { kind: 'none' }
  const start = trip.startDate
  const last = trip.endDate && trip.endDate >= start ? trip.endDate : start
  const { date: today, minutes } = zonedParts(trip.timeZone ?? 'UTC', now)
  if (today > last) return { kind: 'completed' }
  if (today < start) return { kind: 'before', days: daysBetween(today, start) }
  if (today === start && trip.departureTime) {
    const [h, m] = trip.departureTime.split(':').map(Number)
    if (minutes < h * 60 + m) return { kind: 'before', days: 0 }
  }
  return {
    kind: 'during',
    day: daysBetween(start, today) + 1,
    total: daysBetween(start, last) + 1,
  }
}

/** Archived wins; dates decide traveling/completed; confirmed future dates are upcoming. */
export function tripStatus(
  trip: DatedTrip & Pick<Trip, 'archived' | 'datesConfirmed' | 'stage'>,
  now: Date,
): TripStatus {
  if (trip.archived) return 'archived'
  const c = countdown(trip, now)
  if (c.kind === 'during') return 'traveling'
  if (c.kind === 'completed') return 'completed'
  if (c.kind === 'before' && trip.datesConfirmed) return 'upcoming'
  return trip.stage === 'dreaming' ? 'dreaming' : 'planning'
}

export function matchesFilter(status: TripStatus, filter: TripFilter): boolean {
  return filter === 'all' ? status !== 'archived' : status === filter
}

/** Same palette and deterministic choice as the mobile app's default banner. */
const gradients: ReadonlyArray<readonly [string, string]> = [
  ['#254F3E', '#35624C'],
  ['#6B4C3B', '#89644A'],
  ['#4D5E48', '#6A7856'],
  ['#355354', '#486B67'],
  ['#76543A', '#937149'],
  ['#594942', '#7A5D50'],
  ['#3D5144', '#5A6D57'],
  ['#4D5350', '#68716A'],
]

export function bannerGradient(tripId: string): readonly [string, string] {
  let sum = 0
  for (let i = 0; i < tripId.length; i++) sum += tripId.charCodeAt(i)
  return gradients[sum % gradients.length]
}
