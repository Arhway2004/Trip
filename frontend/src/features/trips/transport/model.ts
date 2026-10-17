export interface TransportOffer {
  id: string
  mode: 'train' | 'bus' | 'flight'
  source: 'HERE' | 'Duffel'
  fetchedAt: string
  departure: string
  arrival: string
  durationMinutes: number
  operator: string
  service: string
  amount?: number
  currency?: string
  priceScope?: 'party'
  travelers?: number
  expiresAt?: string
  details: Array<string>
  attributions: Array<string>
}
export interface TransportStatus {
  flights: boolean
  transit: boolean
}

/** Convert a wall time in the trip zone, never in the browser/server's zone. */
export function zonedTimestamp(date: string, clock: string, zone: string) {
  const desired = Date.parse(`${date}T${clock}:00Z`)
  if (!Number.isFinite(desired)) throw new Error('invalid time')
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  })
  let instant = desired
  for (let i = 0; i < 4; i++) {
    const parts = formatter.formatToParts(instant)
    const get = (key: string) => parts.find((part) => part.type === key)?.value
    const observed = Date.parse(
      `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}:${get('second')}Z`,
    )
    const change = desired - observed
    if (!change) return new Date(instant).toISOString()
    instant += change
  }
  throw new Error('invalid local time')
}
export function isoDurationMinutes(value: string): number {
  const match =
    /^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/.exec(
      value,
    )
  if (!match) throw new Error('invalid duration')
  return Math.ceil(
    Number(match[1] || 0) * 1440 +
      Number(match[2] || 0) * 60 +
      Number(match[3] || 0) +
      Number(match[4] || 0) / 60,
  )
}
export function localDateTime(timestamp: unknown, timeZone: string) {
  if (typeof timestamp !== 'string' || !Number.isFinite(Date.parse(timestamp)))
    return ''
  const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(timestamp)),
    get = (key: string) => parts.find((part) => part.type === key)?.value
  return `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}`
}
