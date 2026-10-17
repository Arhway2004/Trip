import { describe, expect, it, vi } from 'vitest'
import { parseDocument } from './model'
import {
  assessDay,
  connectionKey,
  connectionSignature,
  connectionMargin,
  point,
  span,
  dayStops,
  timelineBlocks,
} from './schedule'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

const day = '2026-12-03'
const activity = (ref: string, start: string, end: string, extra = {}) => ({
  ref,
  title: ref,
  date: day,
  start,
  end,
  ...extra,
})
const document = (activities: Array<ReturnType<typeof activity>>, extra = {}) =>
  parseDocument(JSON.stringify({ activities, ...extra }))
describe('day feasibility', () => {
  it('compares service choices using boarding buffers and exact departures in the trip zone', () => {
    const choice = {
      mode: 'train',
      durationMinutes: 60,
      localDeparture: '2026-12-03T09:50',
      localArrival: '2026-12-03T10:50',
      departureBufferMinutes: 10,
    }
    expect(connectionMargin(choice, day, 'Asia/Bangkok', 600, 660)).toBe(-20)
    expect(
      connectionMargin(
        { mode: 'train', durationMinutes: 40 },
        day,
        'Asia/Bangkok',
        600,
        660,
      ),
    ).toBe(-10)
    expect(
      connectionMargin(
        { mode: 'cycling', durationMinutes: 5 },
        day,
        'Asia/Bangkok',
        600,
        645,
      ),
    ).toBe(40)
    expect(
      connectionMargin(
        { ...choice, localDeparture: 'invalid' },
        day,
        'Asia/Bangkok',
        600,
        660,
      ),
    ).toBeUndefined()
  })
  it('keeps untimed stops and overnight hotels on the day map', () => {
    const doc = parseDocument(
      JSON.stringify({
        activities: [
          {
            ref: 'a',
            title: 'Untimed',
            date: day,
            location: { lat: 13, lng: 100 },
          },
          {
            ref: 'hotel',
            title: 'Stay',
            kind: 'hotel',
            date: '2026-12-02',
            endDate: '2026-12-04',
          },
          {
            ref: 'cancelled',
            title: 'Cancelled',
            date: day,
            bookingStatus: 'cancelled',
          },
        ],
      }),
    )
    expect(dayStops(doc, day).map((item) => item.row.ref)).toEqual([
      'a',
      'hotel',
    ])
  })
  it('places travel and arrival buffers in the actual time they consume', () => {
    const from = activity('visit', '09:00', '10:00'),
      to = activity('train', '11:00', '12:00', { kind: 'train' })
    const doc = document([from, to], {
      connections: [
        {
          key: connectionKey(from, to),
          mode: 'walking',
          signature: connectionSignature(from, to, 'walking'),
          durationMinutes: 20,
          bufferMinutes: 30,
        },
      ],
    })
    expect(
      timelineBlocks(doc, day)
        .filter((block) => block.kind !== 'activity')
        .map((block) => [block.kind, block.start, block.end]),
    ).toEqual([
      ['travel', 610, 630],
      ['buffer', 630, 660],
    ])
  })
  it('checks a live departure against the previous stop and invalidates it after dates change', () => {
    const from = activity('a', '09:00', '10:00'),
      to = activity('b', '12:00', '13:00'),
      doc = document([from, to], {
        trip: { timeZone: 'Asia/Bangkok' },
        connections: [
          {
            key: connectionKey(from, to),
            mode: 'train',
            signature: connectionSignature(from, to, 'train', true),
            departure: '2026-12-03T09:50:00+07:00',
            arrival: '2026-12-03T11:00:00+07:00',
            durationMinutes: 70,
            bufferMinutes: 0,
          },
        ],
      })
    expect(assessDay(doc, day).transfers[0].remaining).toBe(-10)
    expect(
      timelineBlocks(doc, day).find((block) => block.kind === 'travel')?.start,
    ).toBe(590)
    doc.activities[0].end = '09:30'
    expect(assessDay(doc, day).transfers[0].duration).toBeUndefined()
  })
  it('can overlay actual times without modifying planned appointments', () => {
    const doc = document([activity('visit', '09:00', '10:00')], {
      actuals: [
        {
          ref: 'log',
          activityRef: 'visit',
          date: day,
          start: '09:15',
          end: '10:30',
        },
      ],
    })
    expect(
      timelineBlocks(doc, day, true).map((block) => [
        block.kind,
        block.start,
        block.end,
      ]),
    ).toEqual([
      ['activity', 540, 600],
      ['actual', 555, 630],
    ])
    expect(doc.activities[0].start).toBe('09:00')
  })
  it('maps delayed actual visits on the day they happened, including a cancelled plan', () => {
    const doc = document(
      [activity('visit', '09:00', '10:00', { bookingStatus: 'cancelled' })],
      {
        actuals: [
          {
            activityRef: 'visit',
            date: '2026-12-04',
            start: '10:00',
            end: '11:00',
          },
        ],
      },
    )
    expect(dayStops(doc, '2026-12-04')).toEqual([])
    expect(
      dayStops(doc, '2026-12-04', true).map((item) => item.row.ref),
    ).toEqual(['visit'])
  })
  it('detects non-adjacent overlaps and gives adjacent events separate visual space', () => {
    const result = assessDay(
      document([
        activity('long', '09:00', '12:00'),
        activity('short', '09:30', '10:00'),
        activity('later', '11:00', '13:00'),
      ]),
      day,
    )
    expect(
      result.overlaps.map((pair) => pair.map((item) => item.row.ref)),
    ).toEqual([
      ['long', 'short'],
      ['long', 'later'],
    ])
    expect(result.items.map((item) => item.lane)).toEqual([0, 1, 1])
  })
  it('splits overnight travel at midnight and excludes hotel stays and cancellations', () => {
    expect(
      span(activity('night', '23:00', '02:00', { endDate: '2026-12-04' }), day),
    ).toEqual([1380, 1440])
    expect(
      span(
        activity('night', '23:00', '02:00', { endDate: '2026-12-04' }),
        '2026-12-04',
      ),
    ).toEqual([0, 120])
    const result = assessDay(
      document([
        activity('hotel', '15:00', '11:00', {
          kind: 'hotel',
          endDate: '2026-12-04',
        }),
        activity('cancelled', '09:00', '10:00', { bookingStatus: 'cancelled' }),
      ]),
      day,
    )
    expect(result.items).toEqual([])
    expect(result.overlaps).toEqual([])
  })
  it('keeps missing times and coordinates explicit instead of guessing', () => {
    const doc = parseDocument(
      JSON.stringify({ activities: [{ title: 'Untimed', date: day }] }),
    )
    expect(assessDay(doc, day).untimed).toHaveLength(1)
    expect(point({ name: 'Chengdu' })).toBeUndefined()
    expect(point({ lat: 91, lng: 10 })).toBeUndefined()
    expect(span(activity('bad', '10:00', '09:00'), day)).toBeUndefined()
  })
  it('accounts for route duration and arrival buffer; invalidates routes when a stop moves', () => {
    const from = activity('museum', '09:00', '10:00', {
        location: { lat: 13.75, lng: 100.5 },
      }),
      to = activity('train', '11:00', '12:00', {
        kind: 'train',
        location: { lat: 13.7, lng: 100.55 },
      })
    const connection = {
      key: connectionKey(from, to),
      mode: 'driving',
      signature: connectionSignature(from, to, 'driving'),
      durationMinutes: 40,
      bufferMinutes: 30,
    }
    const doc = document([from, to], { connections: [connection] })
    expect(assessDay(doc, day).transfers[0].remaining).toBe(-10)
    doc.activities[1].location = { lat: 30, lng: 104 }
    const result = assessDay(doc, day).transfers[0]
    expect(result.duration).toBeUndefined()
    expect(result.buffer).toBe(30)
  })
})
