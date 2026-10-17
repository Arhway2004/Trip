import { describe, expect, it } from 'vitest'
import { isoDurationMinutes, zonedTimestamp } from './model'
import { parseFlightOffers, parseTransitOffers } from './providers.server'

const now = new Date('2026-10-17T00:00:00Z')
describe('provider data integrity', () => {
  it('converts trip-local times independently of the machine time zone and rejects DST gaps', () => {
    expect(zonedTimestamp('2026-12-03', '09:00', 'Asia/Bangkok')).toBe(
      '2026-12-03T02:00:00.000Z',
    )
    expect(zonedTimestamp('2026-12-03', '09:00', 'Asia/Shanghai')).toBe(
      '2026-12-03T01:00:00.000Z',
    )
    expect(() =>
      zonedTimestamp('2026-03-08', '02:30', 'America/New_York'),
    ).toThrow()
    expect(isoDurationMinutes('P1DT2H10M')).toBe(1570)
  })
  it('keeps operating airlines, total party fares and time zones; excludes test, expired and invalid-price flight offers', () => {
    const offer = {
      id: 'off_real',
      live_mode: true,
      total_amount: '450.50',
      total_currency: 'USD',
      expires_at: '2026-10-17T01:00:00Z',
      slices: [
        {
          duration: 'PT2H10M',
          segments: [
            {
              departing_at: '2026-12-03T09:00:00',
              arriving_at: '2026-12-03T12:10:00',
              origin: { time_zone: 'Asia/Bangkok', iata_code: 'BKK' },
              destination: { time_zone: 'Asia/Shanghai', iata_code: 'KMG' },
              operating_carrier: { name: 'Actual operating airline' },
              operating_carrier_flight_number: '321',
            },
          ],
        },
      ],
    }
    const results = parseFlightOffers(
      {
        data: {
          live_mode: true,
          offers: [
            offer,
            { ...offer, id: 'test', live_mode: false },
            { ...offer, id: 'expired', expires_at: '2026-10-16T00:00:00Z' },
            { ...offer, id: 'badprice', total_amount: 'unknown' },
          ],
        },
      },
      2,
      now,
    )
    expect(results).toHaveLength(1)
    expect(results[0]).toMatchObject({
      amount: 450.5,
      currency: 'USD',
      travelers: 2,
      priceScope: 'party',
      departure: '2026-12-03T02:00:00.000Z',
      arrival: '2026-12-03T04:10:00.000Z',
      operator: 'Actual operating airline',
      durationMinutes: 130,
    })
    expect(() =>
      parseFlightOffers(
        { data: { live_mode: false, offers: [offer] } },
        1,
        now,
      ),
    ).toThrow()
  })
  it('requires a matching transit service and leaves missing fare data unknown', () => {
    const section = {
      departure: {
        time: '2026-12-03T09:00:00+07:00',
        place: { name: 'Stop A' },
      },
      arrival: { time: '2026-12-03T10:00:00+07:00', place: { name: 'Stop B' } },
      transport: { mode: 'bus', name: 'Bus 1' },
      agency: { name: 'City transit' },
    }
    const data = { routes: [{ id: 'r1', sections: [section] }] }
    expect(parseTransitOffers(data, 'bus', now)[0]).toMatchObject({
      mode: 'bus',
      durationMinutes: 60,
      operator: 'City transit',
      source: 'HERE',
    })
    expect(parseTransitOffers(data, 'bus', now)[0].amount).toBeUndefined()
    expect(parseTransitOffers(data, 'train', now)).toEqual([])
  })
})
