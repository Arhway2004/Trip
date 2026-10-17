import { describe, expect, it, vi } from 'vitest'
import {
  applyOrder,
  canCompareStops,
  protectedStop,
  suggestOrders,
} from './route-order'
import { parseDocument } from './model'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

const day = '2026-12-03',
  location = { lat: 13.74, lng: 100.53 }
const stops = [
  {
    ref: 'a',
    title: 'Start',
    date: day,
    start: '09:00',
    end: '10:00',
    location,
  },
  {
    ref: 'b',
    title: 'East',
    date: day,
    start: '10:30',
    end: '11:30',
    location,
  },
  { ref: 'c', title: 'West', date: day, location },
  {
    ref: 'd',
    title: 'Booked lunch',
    date: day,
    start: '13:00',
    end: '14:00',
    bookingStatus: 'confirmed',
    location,
  },
]
const matrix = {
  minutes: [
    [0, 70, 5, 60],
    [70, 0, 70, 5],
    [5, 5, 0, 70],
    [60, 5, 70, 0],
  ],
  source: 'OSRM',
  fetchedAt: '2026-10-17T00:00:00Z',
}
const settings = {
  start: 540,
  end: 1320,
  visit: 60,
  buffer: 5,
  movable: ['b', 'c', 'd'],
}

describe('local stop order choices', () => {
  it('offers a feasible road-based alternative while preserving a confirmed appointment', () => {
    const options = suggestOrders(stops, matrix, settings)
    expect(options[0].feasible).toBe(false)
    const alternative = options.find(
      (row) => row.order.join(',') === '0,2,1,3',
    )!
    expect(alternative).toMatchObject({
      feasible: true,
      travel: 15,
      finish: 840,
    })
    expect(alternative.visits.at(-1)).toMatchObject({ start: 780, end: 840 })
    expect(options.every((row) => row.order[0] === 0)).toBe(true)
  })
  it('keeps booked, locked and unselected stops fixed and never guesses a missing road', () => {
    expect(protectedStop({ bookingStatus: 'booked' })).toBe(true)
    expect(protectedStop({ locked: true })).toBe(true)
    expect(
      suggestOrders(stops, matrix, { ...settings, movable: [] }),
    ).toHaveLength(1)
    const unreachable = {
      ...matrix,
      minutes: matrix.minutes.map((row) => row.map(() => null)),
    }
    expect(
      suggestOrders(stops, unreachable, settings).every((row) => !row.feasible),
    ).toBe(true)
  })
  it('applies displayed times and estimates while preserving evidence, paid costs and unknown metadata', () => {
    const doc = parseDocument(
      JSON.stringify({
        activities: stops,
        custom: { retained: true },
        actuals: [{ activityRef: 'b', notes: 'Visited' }],
        photos: [{ caption: 'Evidence' }],
        connections: [{ key: 'a::b', fromRef: 'a', toRef: 'b' }],
        expenses: [
          { kind: 'planned', amount: 20, connectionRef: 'a::b' },
          { kind: 'planned', isPaid: true, amount: 40, connectionRef: 'a::b' },
          { kind: 'actual', amount: 25, connectionRef: 'a::b' },
        ],
      }),
    )
    const option = suggestOrders(stops, matrix, settings).find(
      (row) => row.order.join(',') === '0,2,1,3',
    )!
    const next = applyOrder(doc, stops, option, matrix, settings, 'walking')
    expect(next.activities.find((row) => row.ref === 'd')).toEqual(stops[3])
    expect(next.activities.find((row) => row.ref === 'c')).toMatchObject({
      start: '10:10',
      end: '11:10',
    })
    expect(next.connections).toHaveLength(3)
    expect(next.expenses.map((row) => row.amount)).toEqual([40, 25])
    expect(next.actuals).toEqual(doc.actuals)
    expect(next.photos).toEqual(doc.photos)
    expect(next.custom).toEqual(doc.custom)
    expect(doc.activities[2].start).toBeUndefined()
  })
  it('does not attempt to reorder intercity transport, overnight visits or stops without pins', () => {
    expect(canCompareStops(stops, day)).toBe(true)
    for (const replacement of [
      { kind: 'train' },
      { endDate: '2026-12-04' },
      { location: undefined },
    ])
      expect(
        canCompareStops([stops[0], { ...stops[1], ...replacement }], day),
      ).toBe(false)
  })
})
