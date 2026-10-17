import { describe, expect, it } from 'vitest'
import {
  bannerGradient,
  countdown,
  daysBetween,
  durationDays,
  matchesFilter,
  tripStatus,
} from './domain'

const trip = (over: Partial<Parameters<typeof tripStatus>[0]> = {}) => ({
  startDate: '2026-12-03',
  endDate: '2026-12-13',
  departureTime: null,
  timeZone: 'Asia/Bangkok',
  archived: false,
  datesConfirmed: true,
  stage: 'planning' as const,
  ...over,
})

describe('countdown', () => {
  it('counts calendar days in the trip time zone', () => {
    // 2026-10-16 03:00 UTC = 10:00 in Bangkok
    expect(countdown(trip(), new Date('2026-10-16T03:00:00Z'))).toEqual({
      kind: 'before',
      days: 48,
    })
  })

  it('uses the trip zone, not UTC, to decide the day', () => {
    const now = new Date('2026-05-09T23:30:00Z') // already 10 May in Shanghai, still 9 May in New York
    const t = {
      startDate: '2026-05-10',
      endDate: '2026-05-12',
      departureTime: null,
    }
    expect(countdown({ ...t, timeZone: 'Asia/Shanghai' }, now)).toEqual({
      kind: 'during',
      day: 1,
      total: 3,
    })
    expect(countdown({ ...t, timeZone: 'America/New_York' }, now)).toEqual({
      kind: 'before',
      days: 1,
    })
  })

  it('says "departing today" before the departure time, then day 1', () => {
    const t = trip({ startDate: '2026-12-03', departureTime: '14:30' })
    expect(countdown(t, new Date('2026-12-03T05:00:00Z'))).toEqual({
      kind: 'before',
      days: 0,
    }) // 12:00 BKK
    expect(countdown(t, new Date('2026-12-03T08:00:00Z'))).toEqual({
      kind: 'during',
      day: 1,
      total: 11,
    }) // 15:00 BKK
  })

  it('handles undecided dates, completion and bad zones', () => {
    expect(
      countdown(trip({ startDate: null, endDate: null }), new Date()),
    ).toEqual({ kind: 'none' })
    expect(countdown(trip(), new Date('2026-12-14T03:00:00Z'))).toEqual({
      kind: 'completed',
    })
    expect(() =>
      countdown(trip({ timeZone: 'Mars/Base' }), new Date()),
    ).not.toThrow()
  })
})

describe('status', () => {
  const before = new Date('2026-10-16T03:00:00Z')
  it('follows the same rules as the app', () => {
    expect(tripStatus(trip(), before)).toBe('upcoming')
    expect(tripStatus(trip({ datesConfirmed: false }), before)).toBe('planning')
    expect(
      tripStatus(trip({ datesConfirmed: false, stage: 'dreaming' }), before),
    ).toBe('dreaming')
    expect(tripStatus(trip(), new Date('2026-12-05T03:00:00Z'))).toBe(
      'traveling',
    )
    expect(tripStatus(trip(), new Date('2026-12-20T03:00:00Z'))).toBe(
      'completed',
    )
    expect(
      tripStatus(trip({ archived: true }), new Date('2026-12-05T03:00:00Z')),
    ).toBe('archived')
  })

  it('"all" hides archived trips', () => {
    expect(matchesFilter('archived', 'all')).toBe(false)
    expect(matchesFilter('planning', 'all')).toBe(true)
    expect(matchesFilter('archived', 'archived')).toBe(true)
  })
})

describe('helpers', () => {
  it('computes inclusive durations', () => {
    expect(
      durationDays({ startDate: '2026-12-03', endDate: '2026-12-13' }),
    ).toBe(11)
    expect(durationDays({ startDate: '2026-12-03', endDate: null })).toBe(1)
    expect(durationDays({ startDate: null, endDate: null })).toBeNull()
    expect(daysBetween('2026-02-27', '2026-03-01')).toBe(2)
  })

  it('picks the same default banner as the mobile app', () => {
    // mobile: sum of UTF-16 code units % 8 → "abc" = 294 % 8 = 6
    expect(bannerGradient('abc')).toEqual(['#3D5144', '#5A6D57'])
  })
})
