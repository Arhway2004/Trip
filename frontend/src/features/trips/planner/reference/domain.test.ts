import { describe, expect, it, vi } from 'vitest'
import { parseDocument } from '../model'
import {
  addPlaceVisit,
  bookingCost,
  cloneDay,
  libraryCosts,
  scenarioSnapshot,
  shiftPlanDates,
  switchScenario,
  journeyDetails,
} from './domain'
import { budgetReport } from './budget'
import { csv, scrub } from './reports'

vi.mock('../../plan.functions', () => ({ getPlan: vi.fn() }))
const document = (extra = {}) =>
  parseDocument(JSON.stringify({ trip: { currency: 'THB' }, ...extra }))
describe('reference features share the current trip', () => {
  it('deduplicates shared tickets and suppresses transfer allowances covered by a booking', () => {
    const doc = document({
      attractions: [
        {
          ref: 'a',
          name: 'Park A',
          selected: true,
          ticketPrice: 100,
          ticketCurrency: 'THB',
          sharedTicketKey: 'park',
          transportCost: 50,
          transportCurrency: 'THB',
        },
        {
          ref: 'b',
          name: 'Park B',
          selected: true,
          ticketPrice: 120,
          ticketCurrency: 'THB',
          sharedTicketKey: 'park',
        },
      ],
      activities: [{ ref: 'bus', kind: 'bus', placeRef: 'a' }],
    })
    const next = libraryCosts(doc, 2)
    expect(next.expenses).toHaveLength(1)
    expect(next.expenses[0].amount).toBe(240)
    const placed = addPlaceVisit(
      next,
      {
        ref: 'b',
        name: 'Park B',
        ticketPrice: 120,
        ticketCurrency: 'THB',
        sharedTicketKey: 'park',
      },
      '2026-12-03',
      2,
    )
    expect(placed.activities.at(-1)).toMatchObject({
      date: '2026-12-03',
      location: { name: 'Park B' },
      cost: 0,
    })
    expect(placed.activities.at(-1)?.start).toBeUndefined()
  })
  it('replaces linked planned costs with actuals and consumes category allowances once', () => {
    const doc = document({
      activities: [
        { ref: 'flight', kind: 'flight', cost: 1000, currency: 'THB' },
      ],
      expenses: [
        {
          kind: 'actual',
          title: 'Paid flight',
          amount: 900,
          currency: 'THB',
          activityRef: 'flight',
          isPaid: true,
        },
        {
          kind: 'planned',
          amount: 500,
          currency: 'THB',
          category: 'food',
          isAllowance: true,
          date: '2026-12-03',
        },
        {
          kind: 'actual',
          amount: 200,
          currency: 'THB',
          category: 'food',
          date: '2026-12-03',
        },
      ],
    })
    expect(budgetReport(doc, 'THB', 2000)).toMatchObject({
      planned: 1500,
      actual: 1100,
      forecast: 1400,
      paid: 1100,
      remaining: 600,
    })
  })
  it('calculates room/night pricing, party fares and flight connection time across zones', () => {
    expect(
      bookingCost(
        {
          kind: 'hotel',
          date: '2026-12-03',
          endDate: '2026-12-06',
          rooms: 2,
          pricePerNight: 500,
        },
        2,
      ),
    ).toBe(3000)
    expect(
      bookingCost(
        {
          kind: 'flight',
          unitPrice: 1000,
          priceMode: 'perPerson',
          passengers: 2,
          baggageFee: 100,
          seatFee: 50,
        },
        2,
      ),
    ).toBe(2150)
    const doc = document({
      activities: [
        {
          ref: 'a',
          kind: 'flight',
          journeyRef: 'j',
          date: '2026-12-03',
          departureDate: '2026-12-03',
          departureTime: '08:00',
          arrivalDate: '2026-12-03',
          arrivalTime: '11:00',
          departureTimeZone: 'Asia/Bangkok',
          arrivalTimeZone: 'Asia/Shanghai',
          departureAirport: 'BKK',
          arrivalAirport: 'KMG',
          legOrder: 1,
        },
        {
          ref: 'b',
          kind: 'flight',
          journeyRef: 'j',
          departureDate: '2026-12-03',
          departureTime: '12:30',
          arrivalDate: '2026-12-03',
          arrivalTime: '14:00',
          departureTimeZone: 'Asia/Shanghai',
          arrivalTimeZone: 'Asia/Shanghai',
          departureAirport: 'KMG',
          arrivalAirport: 'CTU',
          legOrder: 2,
        },
      ],
    })
    expect(journeyDetails(doc, 'j', 'Asia/Shanghai')).toMatchObject({
      duration: 300,
      connections: [{ minutes: 90, airportChange: false }],
    })
  })
  it('switches planning scenarios without rolling back actual spending or library metadata', () => {
    const doc = document({
      activities: [{ ref: 'a', date: '2026-12-03' }],
      attractions: [{ ref: 'park', name: 'Updated name', selected: true }],
      expenses: [
        { ref: 'actual', kind: 'actual', amount: 10, currency: 'THB' },
      ],
      photos: [{ file: 'media/a.png' }],
      activeScenarioRef: 'one',
    })
    doc.scenarios = [
      { ref: 'one', name: 'One' },
      {
        ref: 'two',
        name: 'Two',
        snapshot: {
          ...scenarioSnapshot(doc),
          activities: [],
          expenses: [],
          selectedPlaceRefs: [],
        },
      },
    ]
    const next = switchScenario(doc, 'two')
    expect(next.activities).toEqual([])
    expect(next.expenses).toEqual(doc.expenses)
    expect(next.photos).toEqual(doc.photos)
    expect(next.attractions).toMatchObject([
      { name: 'Updated name', selected: false },
    ])
    expect(switchScenario(next, 'one').activities).toEqual(doc.activities)
  })
  it('duplicates and shifts flexible plans while keeping protected dates and real records', () => {
    const doc = document({
      activities: [
        { ref: 'a', date: '2026-12-03', start: '09:00', end: '10:00' },
        {
          ref: 'b',
          date: '2026-12-03',
          bookingStatus: 'confirmed',
          bookingReference: 'private',
        },
      ],
      actuals: [{ activityRef: 'a', date: '2026-12-03' }],
    })
    expect(shiftPlanDates(doc, 2, false).activities.map((a) => a.date)).toEqual(
      ['2026-12-05', '2026-12-03'],
    )
    expect(shiftPlanDates(doc, 2, true).activities.map((a) => a.date)).toEqual([
      '2026-12-05',
      '2026-12-05',
    ])
    const copy = cloneDay(doc, '2026-12-03', '2026-12-04')
    expect(copy.activities[3]).toMatchObject({
      date: '2026-12-04',
      bookingStatus: 'notBooked',
    })
    expect(copy.activities[3].bookingReference).toBeUndefined()
    expect(copy.actuals).toEqual(doc.actuals)
  })
  it('scrubs nested private fields and neutralizes spreadsheet formulas in CSV text', () => {
    expect(
      scrub(
        {
          bookingReference: 'private',
          notes: 'secret',
          scenarios: [
            {
              snapshot: {
                activities: [
                  {
                    bookingReference: 'nested',
                    notes: 'hidden',
                    title: 'Visible',
                  },
                ],
              },
            },
          ],
        },
        { excludeRefs: true, excludeNotes: true },
      ),
    ).toEqual({
      scenarios: [{ snapshot: { activities: [{ title: 'Visible' }] } }],
    })
    expect(csv([['=WEBSERVICE("example")', -20, '+cmd']])).toContain(
      "'=WEBSERVICE",
    )
    expect(csv([[-20]])).toContain('"-20"')
  })
})
