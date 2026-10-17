import type { TravelMode } from '../planner/schedule'

export function publicTransportSearch(input: {
  mode: TravelMode
  origin: string
  destination: string
  date: string
  adults: number
  currency?: string
}): string {
  if (input.mode === 'flight') {
    const url = new URL('https://www.google.com/travel/flights')
    url.searchParams.set(
      'q',
      `Flights from ${input.origin.trim()} to ${input.destination.trim()} on ${input.date} one-way for ${input.adults} adults`,
    )
    url.searchParams.set('hl', 'en')
    if (input.currency && /^[A-Z]{3}$/.test(input.currency))
      url.searchParams.set('curr', input.currency)
    return url.toString()
  }
  const slug = (value: string) =>
    encodeURIComponent(
      value
        .trim()
        .normalize('NFKD')
        .toLowerCase()
        .replace(/[^\p{L}\p{N}]+/gu, '-')
        .replace(/^-|-$/g, ''),
    )
  const url = new URL(
    `https://12go.asia/en/travel/${slug(input.origin)}/${slug(input.destination)}`,
  )
  url.searchParams.set('date', input.date)
  url.searchParams.set('people', String(input.adults))
  return url.toString()
}
