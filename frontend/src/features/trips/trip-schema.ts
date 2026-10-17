// Validation shared by the form (browser) and server functions. Rules mirror
// the Go domain (backend/internal/trip/domain/trip.go) so users see problems
// before the request is sent; the API still validates authoritatively.
import { z } from 'zod'
import type { Stage, TravelStyle, Trip, TripInput } from '#/lib/api/types'

export const travelStyles = [
  'relaxed',
  'balanced',
  'packed',
  'budget',
  'comfort',
  'luxury',
  'adventure',
  'family',
] as const satisfies ReadonlyArray<TravelStyle>
export const stages = [
  'dreaming',
  'planning',
] as const satisfies ReadonlyArray<Stage>

const isoDate = z.iso.date()
const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/)

export function isKnownTimeZone(tz: string): boolean {
  if (tz === 'UTC') return true
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz })
    return true
  } catch {
    return false
  }
}

/** API payload (what server functions accept and send to the Go API). */
export const tripInputSchema = z
  .object({
    id: z.uuid().optional(),
    title: z.string().trim().min(1).max(200),
    description: z.string().trim().max(5000).nullable().optional(),
    startDate: isoDate.nullable().optional(),
    endDate: isoDate.nullable().optional(),
    departureTime: hhmm.nullable().optional(),
    datesConfirmed: z.boolean().optional(),
    timeZone: z.string().refine(isKnownTimeZone),
    travelerCount: z.number().int().min(1).max(999),
    currency: z
      .string()
      .regex(/^[A-Z]{3}$/)
      .nullable()
      .optional(),
    totalBudget: z.number().min(0).nullable().optional(),
    travelStyle: z.enum(travelStyles).nullable().optional(),
    stage: z.enum(stages),
    archived: z.boolean().optional(),
  })
  .superRefine((v, ctx) => {
    if (v.endDate && !v.startDate)
      ctx.addIssue({
        code: 'custom',
        path: ['endDate'],
        message: 'requires startDate',
      })
    if (v.startDate && v.endDate && v.endDate < v.startDate) {
      ctx.addIssue({
        code: 'custom',
        path: ['endDate'],
        message: 'must not be before startDate',
      })
    }
    if (v.totalBudget != null && !v.currency) {
      ctx.addIssue({
        code: 'custom',
        path: ['currency'],
        message: 'is required when totalBudget is set',
      })
    }
  })

/** What the form edits: plain strings, like the inputs. */
export interface TripFormValues {
  title: string
  description: string
  startDate: string
  endDate: string
  departureTime: string
  datesConfirmed: boolean
  timeZone: string
  travelerCount: number
  currency: string
  totalBudget: string
  travelStyle: '' | TravelStyle
  stage: Stage
  archived: boolean
}

/** Form validation. Messages are i18n message keys (see messages/*.json). */
export const tripFormSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(1, 'error_title_required')
      .max(200, 'error_title_long'),
    description: z.string(),
    startDate: z.string(),
    endDate: z.string(),
    departureTime: z
      .string()
      .refine((s) => s === '' || hhmm.safeParse(s).success, 'error_time'),
    datesConfirmed: z.boolean(),
    timeZone: z.string().refine(isKnownTimeZone, 'error_time_zone'),
    travelerCount: z
      .number()
      .int('error_travelers')
      .min(1, 'error_travelers')
      .max(999, 'error_travelers'),
    currency: z
      .string()
      .refine(
        (s) => s.trim() === '' || /^[A-Za-z]{3}$/.test(s.trim()),
        'error_currency',
      ),
    totalBudget: z
      .string()
      .refine(
        (s) => s.trim() === '' || Number(s) >= 0,
        'error_budget_negative',
      ),
    travelStyle: z.union([z.literal(''), z.enum(travelStyles)]),
    stage: z.enum(stages),
    archived: z.boolean(),
  })
  .superRefine((v, ctx) => {
    if (v.endDate && !v.startDate)
      ctx.addIssue({
        code: 'custom',
        path: ['endDate'],
        message: 'error_end_needs_start',
      })
    if (v.startDate && v.endDate && v.endDate < v.startDate) {
      ctx.addIssue({
        code: 'custom',
        path: ['endDate'],
        message: 'error_end_before_start',
      })
    }
    if (v.totalBudget.trim() !== '' && v.currency.trim() === '') {
      ctx.addIssue({
        code: 'custom',
        path: ['currency'],
        message: 'error_budget_currency',
      })
    }
  })

const blank = (s: string) => (s.trim() === '' ? null : s.trim())

export function toTripInput(
  v: TripFormValues,
): TripInput & { stage: Stage; travelerCount: number; timeZone: string } {
  const hasDates = v.startDate !== ''
  return {
    title: v.title.trim(),
    description: blank(v.description),
    startDate: blank(v.startDate),
    endDate: blank(v.endDate),
    departureTime: hasDates ? blank(v.departureTime) : null,
    datesConfirmed: hasDates && v.datesConfirmed,
    timeZone: v.timeZone,
    travelerCount: v.travelerCount,
    currency: blank(v.currency)?.toUpperCase() ?? null,
    totalBudget: v.totalBudget.trim() === '' ? null : Number(v.totalBudget),
    travelStyle: v.travelStyle === '' ? null : v.travelStyle,
    stage: v.stage,
    archived: v.archived,
  }
}

export function emptyTripForm(timeZone: string): TripFormValues {
  return {
    title: '',
    description: '',
    startDate: '',
    endDate: '',
    departureTime: '',
    datesConfirmed: false,
    timeZone,
    travelerCount: 1,
    currency: '',
    totalBudget: '',
    travelStyle: '',
    stage: 'planning',
    archived: false,
  }
}

export function tripToForm(t: Trip): TripFormValues {
  return {
    title: t.title,
    description: t.description ?? '',
    startDate: t.startDate ?? '',
    endDate: t.endDate ?? '',
    departureTime: t.departureTime ?? '',
    datesConfirmed: t.datesConfirmed ?? false,
    timeZone: t.timeZone ?? 'UTC',
    travelerCount: t.travelerCount ?? 1,
    currency: t.currency ?? '',
    totalBudget: t.totalBudget == null ? '' : String(t.totalBudget),
    travelStyle: t.travelStyle ?? '',
    stage: t.stage ?? 'planning',
    archived: t.archived ?? false,
  }
}

/** Full replacement payload from an existing trip (e.g. for archive/unarchive). */
export function tripToInput(t: Trip) {
  return toTripInput(tripToForm(t))
}
