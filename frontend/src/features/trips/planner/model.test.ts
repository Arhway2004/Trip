import { describe, expect, it, vi } from 'vitest'
import { budgetTotals, imageSource, parseDocument, setField } from './model'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

describe('editable mobile documents', () => {
  it('preserves unknown imported fields and nested metadata when a known field changes', () => {
    const raw = {
      future: { value: 42 },
      activities: [
        {
          title: 'Old',
          location: { name: 'Old', lat: 13, lng: 100, providerId: 'keep' },
          source: { opaque: true },
        },
      ],
    }
    const doc = parseDocument(JSON.stringify(raw)),
      edited = setField(doc.activities[0], 'location.name', 'New')
    expect(doc.future).toEqual({ value: 42 })
    expect(edited.location).toEqual({
      name: 'New',
      lat: 13,
      lng: 100,
      providerId: 'keep',
    })
    expect(edited.source).toEqual({ opaque: true })
    expect(raw.activities[0].location.name).toBe('Old')
    expect(parseDocument(JSON.stringify(doc)).activities[0].ref).toBe(
      doc.activities[0].ref,
    )
  })
  it('separates actual costs from estimates and flags missing currency conversions', () => {
    const doc = parseDocument(
      JSON.stringify({
        activities: [
          { cost: 100, currency: 'CNY' },
          { cost: 999, currency: 'THB', bookingStatus: 'cancelled' },
        ],
        exchangeRates: [{ currency: 'CNY', rate: 5 }],
        expenses: [
          { amount: 50, currency: 'CNY', kind: 'planned' },
          {
            amount: 90,
            currency: 'CNY',
            kind: 'actual',
            activityRef: 'flight',
            isPaid: true,
          },
          { amount: 20, currency: 'THB', kind: 'actual', isPaid: false },
          { amount: 20, currency: 'EUR' },
        ],
      }),
    )
    expect(budgetTotals(doc, 'THB')).toEqual({
      planned: 750,
      spent: 470,
      paid: 450,
      perPerson: 470,
      missing: ['EUR'],
    })
  })
  it('only previews supported raster data, preserving other imported media as data', () => {
    expect(imageSource('PHN2ZyBvbmxvYWQ9')).toBeUndefined()
    expect(imageSource('iVBORw0KGgoAAA')).toContain('data:image/png;base64,')
  })
})
