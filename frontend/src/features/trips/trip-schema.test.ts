import { describe, expect, it } from 'vitest'
import {
  emptyTripForm,
  toTripInput,
  tripFormSchema,
  tripInputSchema,
} from './trip-schema'

const issues = (v: unknown) =>
  Object.fromEntries(
    (tripFormSchema.safeParse(v).error?.issues ?? []).map((i) => [
      i.path.join('.'),
      i.message,
    ]),
  )

describe('trip form validation (mirrors the Go domain)', () => {
  it('requires a title and reports i18n message keys', () => {
    expect(issues(emptyTripForm('UTC'))).toEqual({
      title: 'error_title_required',
    })
  })

  it('checks dates, time, zone, currency and budget together', () => {
    const v = {
      ...emptyTripForm('Mars/Base'),
      title: 'x',
      startDate: '2026-12-10',
      endDate: '2026-12-03',
      departureTime: '25:00',
      currency: '',
      totalBudget: '100',
      travelerCount: 0,
    }
    expect(issues(v)).toEqual({
      endDate: 'error_end_before_start',
      departureTime: 'error_time',
      timeZone: 'error_time_zone',
      currency: 'error_budget_currency',
      travelerCount: 'error_travelers',
    })
  })

  it('converts form strings into the API payload', () => {
    const input = toTripInput({
      ...emptyTripForm('Asia/Shanghai'),
      title: '  China Winter  ',
      startDate: '2026-12-03',
      endDate: '2026-12-13',
      departureTime: '08:30',
      datesConfirmed: true,
      currency: 'thb',
      totalBudget: '50000',
      travelerCount: 2,
      travelStyle: 'balanced',
    })
    expect(input).toMatchObject({
      title: 'China Winter',
      currency: 'THB',
      totalBudget: 50000,
      departureTime: '08:30',
      datesConfirmed: true,
      description: null,
    })
    expect(tripInputSchema.safeParse(input).success).toBe(true)
  })

  it('drops departure time and confirmation when there are no dates', () => {
    const input = toTripInput({
      ...emptyTripForm('UTC'),
      title: 'x',
      departureTime: '08:00',
      datesConfirmed: true,
    })
    expect(input.departureTime).toBeNull()
    expect(input.datesConfirmed).toBe(false)
  })

  it('server-side schema rejects a budget without currency', () => {
    const r = tripInputSchema.safeParse({
      title: 'x',
      timeZone: 'UTC',
      travelerCount: 1,
      stage: 'planning',
      totalBudget: 5,
    })
    expect(r.success).toBe(false)
  })
})
