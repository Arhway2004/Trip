import { expect, it } from 'vitest'
import { publicTransportSearch } from './public-search'

it('opens dated public flight searches with the selected party and currency', () => {
  const url = new URL(
    publicTransportSearch({
      mode: 'flight',
      origin: 'BKK',
      destination: 'KMG',
      date: '2026-12-03',
      adults: 2,
      currency: 'THB',
    }),
  )
  expect(url.hostname).toBe('www.google.com')
  expect(url.searchParams.get('q')).toBe(
    'Flights from BKK to KMG on 2026-12-03 one-way for 2 adults',
  )
  expect(url.searchParams.get('curr')).toBe('THB')
})
it('keeps route, date and people when opening public train/bus results', () => {
  const url = new URL(
    publicTransportSearch({
      mode: 'bus',
      origin: 'Bangkok',
      destination: 'Chiang Mai',
      date: '2026-12-03',
      adults: 2,
    }),
  )
  expect(url.pathname).toBe('/en/travel/bangkok/chiang-mai')
  expect(url.searchParams.get('date')).toBe('2026-12-03')
  expect(url.searchParams.get('people')).toBe('2')
})
