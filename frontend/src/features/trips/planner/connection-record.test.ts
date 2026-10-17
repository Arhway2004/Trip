import { expect, it, vi } from 'vitest'
import { mergeConnection } from './connection-record'
import { budgetTotals, parseDocument } from './model'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

it('updates a connection fare once while preserving actual spending and unrelated plan costs', () => {
  const from = { ref: 'a', title: 'Museum', date: '2026-12-03' },
    to = { ref: 'b', title: 'Hotel' },
    doc = parseDocument(
      JSON.stringify({
        expenses: [
          { title: 'Lunch', amount: 20, currency: 'THB', kind: 'actual' },
          {
            title: 'Paid transfer',
            amount: 50,
            currency: 'THB',
            kind: 'actual',
            connectionRef: 'a::b',
          },
        ],
      }),
    )
  const first = mergeConnection(doc, from, to, {
    key: 'a::b',
    mode: 'bus',
    amount: 100,
    currency: 'THB',
  })
  const second = mergeConnection(first, from, to, {
    key: 'a::b',
    mode: 'bus',
    amount: 120,
    currency: 'THB',
  })
  expect(second.expenses).toHaveLength(3)
  expect(budgetTotals(second, 'THB')).toMatchObject({ planned: 120, spent: 70 })
  expect(
    mergeConnection(second, from, to, { key: 'a::b', mode: 'walking' })
      .expenses,
  ).toEqual(doc.expenses)
})
