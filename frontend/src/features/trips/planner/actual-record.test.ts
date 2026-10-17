import { describe, expect, it, vi } from 'vitest'
import { mergeActualEvidence } from './actual-record'
import { budgetTotals, parseDocument } from './model'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

it('saves actual evidence once, preserves unrelated costs/photos and leaves planned times unchanged', () => {
  const original = parseDocument(
    JSON.stringify({
      trip: { currency: 'THB' },
      activities: [
        {
          ref: 'visit',
          title: 'Museum',
          date: '2026-12-03',
          start: '09:00',
          end: '10:00',
        },
      ],
      expenses: [{ title: 'Taxi', amount: 50, currency: 'THB' }],
      photos: [{ file: 'media/original.png' }],
    }),
  )
  const actual = {
      ref: 'actual-1',
      activityRef: 'visit',
      date: '2026-12-03',
      start: '09:15',
      end: '10:30',
    },
    evidence = {
      expense: { amount: 100, currency: 'THB' },
      photos: [{ file: 'media/visit.png', caption: 'A real visit' }],
    }
  const first = mergeActualEvidence(original, actual, evidence),
    second = mergeActualEvidence(first, actual, {
      ...evidence,
      expense: { amount: 120, currency: 'THB' },
    })
  expect(second.activities).toEqual(original.activities)
  expect(second.expenses).toHaveLength(2)
  expect(second.photos).toHaveLength(2)
  expect(budgetTotals(second, 'THB').spent).toBe(170)
  expect(second.photos[1]).toMatchObject({
    file: 'media/visit.png',
    activityRef: 'visit',
    actualRef: 'actual-1',
  })
  expect(
    mergeActualEvidence(second, actual, { expense: null, photos: [] }).expenses,
  ).toEqual(original.expenses)
})
describe('actual evidence metadata', () => {
  it('preserves paid/shared flags and expense metadata on re-edit', () => {
    const doc = parseDocument(
      JSON.stringify({ activities: [{ ref: 'a', title: 'Visit' }] }),
    )
    const result = mergeActualEvidence(
      doc,
      { ref: 'log', activityRef: 'a', date: '2026-12-03' },
      {
        expense: {
          title: 'Tickets',
          amount: 20,
          currency: 'USD',
          isPaid: false,
          isShared: false,
          receipt: 'keep',
        },
        photos: [],
      },
    )
    expect(result.expenses[0]).toMatchObject({
      title: 'Tickets',
      receipt: 'keep',
      isPaid: false,
      isShared: false,
    })
  })
})
