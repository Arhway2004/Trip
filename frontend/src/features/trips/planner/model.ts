import { queryOptions } from '@tanstack/react-query'
import { unwrap } from '#/lib/api/problem'
import { getPlan } from '../plan.functions'

export type PlanRow = Record<string, unknown>
export const sections = [
  'activities',
  'todos',
  'expenses',
  'exchangeRates',
  'destinations',
  'places',
  'photos',
  'actuals',
] as const
export type Section = (typeof sections)[number]
export type PlanDocument = Record<string, unknown> &
  Record<Section, Array<PlanRow>>
export const planQuery = (tripId: string) =>
  queryOptions({
    queryKey: ['trip', tripId, 'plan'],
    queryFn: async () => unwrap(await getPlan({ data: { tripId } })),
    staleTime: 15_000,
    refetchOnWindowFocus: false,
  })
export const text = (value: unknown): string =>
  typeof value === 'string'
    ? value
    : typeof value === 'number'
      ? String(value)
      : ''
export const records = (value: unknown): Array<PlanRow> =>
  Array.isArray(value)
    ? value.filter(
        (v): v is PlanRow =>
          v != null && typeof v === 'object' && !Array.isArray(v),
      )
    : []
export function parseDocument(raw: string): PlanDocument {
  const result = JSON.parse(raw) as PlanDocument
  for (const section of sections) result[section] = records(result[section])
  result.activities = result.activities.map((row, index) => ({
    ...row,
    ref: text(row.ref) || `web-activity-${index}`,
  }))
  result.actuals = result.actuals.map((row, index) => ({
    ...row,
    ref: text(row.ref) || `web-actual-${index}`,
  }))
  return result
}
export function imageSource(bytes: string | undefined) {
  if (!bytes) return undefined
  const mime = bytes.startsWith('/9j/')
    ? 'image/jpeg'
    : bytes.startsWith('iVBORw0KGgo')
      ? 'image/png'
      : bytes.startsWith('UklGR')
        ? 'image/webp'
        : bytes.startsWith('R0lGOD')
          ? 'image/gif'
          : undefined
  return mime ? `data:${mime};base64,${bytes}` : undefined
}
export function color(value: unknown, fallback: string): string {
  if (typeof value === 'number')
    return '#' + (value >>> 0).toString(16).padStart(8, '0').slice(-6)
  return typeof value === 'string' &&
    /^#(?:[\da-f]{6}|[\da-f]{8})$/i.test(value)
    ? '#' + value.slice(-6)
    : fallback
}
export function fieldValue(row: PlanRow, key: string): unknown {
  const [parent, child] = key.split('.')
  if (!child) return row[parent]
  const value = row[parent]
  if (typeof value === 'string' && child === 'name') return value
  return value && typeof value === 'object'
    ? (value as PlanRow)[child]
    : undefined
}
export function setField(row: PlanRow, key: string, value: unknown): PlanRow {
  const [parent, child] = key.split('.')
  const next = { ...row }
  if (!child) {
    if (value === '' || value == null) delete next[parent]
    else next[parent] = value
    return next
  }
  const old =
    typeof row[parent] === 'string'
      ? { name: row[parent] }
      : (row[parent] as PlanRow | undefined)
  const nested = { ...old }
  if (value === '' || value == null) delete nested[child]
  else nested[child] = value
  if (Object.keys(nested).length) next[parent] = nested
  else delete next[parent]
  return next
}

// Same accounting as mobile: activity costs + planned extras; actual entries
// linked to activities settle those costs without adding them a second time.
export function budgetTotals(
  document: PlanDocument,
  base: string,
  travelers = 1,
) {
  const rates = new Map(
    document.exchangeRates.map((r) => [
      text(r.currency).toUpperCase(),
      Number(r.rate),
    ]),
  )
  rates.set(base, 1)
  const missing = new Set<string>()
  function convert(value: unknown, currency: unknown) {
    const amount = Number(value ?? 0),
      code = text(currency).toUpperCase() || base
    const rate = rates.get(code)
    if (amount && (!rate || !Number.isFinite(rate))) {
      missing.add(code || '—')
      return 0
    }
    return amount * (rate ?? 1)
  }
  let planned = 0,
    spent = 0,
    paid = 0,
    perPerson = 0
  for (const row of document.activities)
    if (row.bookingStatus !== 'cancelled')
      planned += convert(row.cost, row.currency)
  for (const row of document.expenses) {
    const amount = convert(row.amount, row.currency)
    if (row.kind === 'planned') {
      planned += amount
    } else {
      spent += amount
      if (row.isPaid !== false) paid += amount
      perPerson +=
        row.isShared === false ? amount : amount / Math.max(1, travelers)
    }
  }
  return { planned, spent, paid, perPerson, missing: [...missing] }
}

export async function readPhoto(
  file: File,
): Promise<{ name: string; bytes: string }> {
  if (file.size > 5 * 1024 * 1024) throw new Error('photoTooLarge')
  const data = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader()
    reader.onerror = () => reject(new Error('photoUnreadable'))
    reader.onload = () => resolve(String(reader.result).split(',')[1])
    reader.readAsDataURL(file)
  })
  const source = imageSource(data)
  if (!source) throw new Error('photoUnsupported')
  const ext = source.startsWith('data:image/jpeg')
    ? 'jpg'
    : source.startsWith('data:image/png')
      ? 'png'
      : source.startsWith('data:image/webp')
        ? 'webp'
        : 'gif'
  return { name: `media/${crypto.randomUUID()}.${ext}`, bytes: data }
}

export function mediaFits(
  media: Record<string, string>,
  files: Array<File> = [],
) {
  const bytes = Object.values(media).reduce(
    (sum, value) => sum + Math.floor((value.length * 3) / 4),
    0,
  )
  return (
    Object.keys(media).length + files.length <= 999 &&
    bytes + files.reduce((sum, file) => sum + file.size, 0) < 18 * 1024 * 1024
  )
}
