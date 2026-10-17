import { records, text } from './model'
import { zonedTimestamp } from '../transport/model'
import type { PlanDocument, PlanRow } from './model'

export type TravelMode =
  'walking' | 'cycling' | 'driving' | 'train' | 'flight' | 'bus'
export interface Point {
  lat: number
  lng: number
  name?: string
}
export function point(value: unknown): Point | undefined {
  if (!value || typeof value !== 'object') return undefined
  const row = value as PlanRow
  return typeof row.lat === 'number' &&
    typeof row.lng === 'number' &&
    Number.isFinite(row.lat) &&
    Number.isFinite(row.lng) &&
    Math.abs(row.lat) <= 90 &&
    Math.abs(row.lng) <= 180
    ? { lat: row.lat, lng: row.lng, name: text(row.name) }
    : undefined
}
export function minute(value: unknown): number | undefined {
  if (
    typeof value !== 'string' ||
    !/^([01]\d|2[0-3]):[0-5]\d$|^24:00$/.test(value)
  )
    return undefined
  const [hour, min] = value.split(':').map(Number)
  return hour * 60 + min
}
const epoch = (date: string) => Date.parse(date + 'T00:00:00Z') / 86_400_000
export function span(row: PlanRow, day: string): [number, number] | undefined {
  if (row.kind === 'hotel' || row.bookingStatus === 'cancelled')
    return undefined
  const start = minute(row.start),
    end = minute(row.end)
  if (start == null || end == null) return undefined
  const from = (epoch(text(row.date)) - epoch(day)) * 1440 + start,
    to = (epoch(text(row.endDate) || text(row.date)) - epoch(day)) * 1440 + end
  if (
    !Number.isFinite(from) ||
    !Number.isFinite(to) ||
    to <= from ||
    to <= 0 ||
    from >= 1440
  )
    return undefined
  return [Math.max(0, from), Math.min(1440, to)]
}
export const recommendedBuffer = (row: PlanRow) =>
  row.kind === 'flight'
    ? 120
    : row.kind === 'train'
      ? 30
      : ['bus', 'ferry'].includes(text(row.kind))
        ? 20
        : 0
export function connectionKey(from: PlanRow, to: PlanRow) {
  return `${text(from.ref)}::${text(to.ref)}`
}
export function connectionSignature(
  from: PlanRow,
  to: PlanRow,
  mode: string,
  scheduled = false,
) {
  return JSON.stringify([
    from.ref,
    to.ref,
    point(from.destination) ||
      point(from.location) ||
      from.destination ||
      from.location,
    point(to.location) || to.location,
    mode,
    ...(scheduled
      ? [from.date, from.endDate, from.end, to.date, to.start]
      : []),
  ])
}
export function validConnection(
  document: PlanDocument,
  from: PlanRow,
  to: PlanRow,
): PlanRow | undefined {
  const saved = records(document.connections).find(
    (row) => row.key === connectionKey(from, to),
  )
  return saved &&
    saved.signature ===
      connectionSignature(
        from,
        to,
        text(saved.mode),
        typeof saved.departure === 'string',
      )
    ? saved
    : undefined
}
export interface DayItem {
  row: PlanRow
  index: number
  start: number
  end: number
  lane: number
}
export function dayItems(document: PlanDocument, day: string): Array<DayItem> {
  const result = document.activities
    .flatMap((row, index) => {
      const interval = span(row, day)
      return interval
        ? [{ row, index, start: interval[0], end: interval[1], lane: 0 }]
        : []
    })
    .sort((a, b) => a.start - b.start || a.end - b.end)
  const lanes: Array<number> = []
  for (const item of result) {
    let lane = lanes.findIndex((end) => end <= item.start)
    if (lane < 0) lane = lanes.length
    lanes[lane] = Math.max(item.end, item.start + 60)
    item.lane = lane
  }
  return result
}
export function timeLabel(value: number) {
  return `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`
}
export function minuteInDay(
  timestamp: unknown,
  day: string,
  timeZone: string,
): number | undefined {
  if (typeof timestamp !== 'string' || !Number.isFinite(Date.parse(timestamp)))
    return undefined
  const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(timestamp)),
    get = (key: string) => parts.find((part) => part.type === key)?.value
  return (
    (epoch(`${get('year')}-${get('month')}-${get('day')}`) - epoch(day)) *
      1440 +
    Number(get('hour')) * 60 +
    Number(get('minute'))
  )
}
export function assessDay(document: PlanDocument, day: string) {
  const items = dayItems(document, day),
    overlaps: Array<[DayItem, DayItem]> = []
  for (let i = 0; i < items.length; i++)
    for (let j = i + 1; j < items.length; j++)
      if (items[j].start < items[i].end) overlaps.push([items[i], items[j]])
  const untimed = document.activities.filter(
    (row) =>
      row.date === day &&
      row.kind !== 'hotel' &&
      row.bookingStatus !== 'cancelled' &&
      (minute(row.start) == null || minute(row.end) == null),
  )
  const transfers = items.slice(1).map((next, index) => {
    const previous = items[index],
      saved = validConnection(document, previous.row, next.row),
      duration =
        typeof saved?.durationMinutes === 'number'
          ? saved.durationMinutes
          : undefined,
      buffer =
        typeof saved?.bufferMinutes === 'number'
          ? saved.bufferMinutes
          : recommendedBuffer(next.row),
      gap = next.start - previous.end
    const timeZone =
        text((document.trip as PlanRow | undefined)?.timeZone) || 'UTC',
      departure = minuteInDay(saved?.departure, day, timeZone),
      arrival = minuteInDay(saved?.arrival, day, timeZone),
      departureBuffer =
        typeof saved?.departureBufferMinutes === 'number'
          ? saved.departureBufferMinutes
          : 0
    return {
      from: previous,
      to: next,
      saved,
      duration,
      buffer,
      gap,
      departure,
      arrival,
      departureBuffer,
      remaining: connectionMargin(
        saved
          ? { ...saved, departureBufferMinutes: departureBuffer }
          : undefined,
        day,
        timeZone,
        previous.end,
        next.start - buffer,
      ),
    }
  })
  return {
    items,
    overlaps,
    untimed,
    transfers,
    longDay: items.reduce((sum, row) => sum + row.end - row.start, 0) > 13 * 60,
    lateFinish: items.some((row) => row.end > 23 * 60),
  }
}

/** Time left after travel and boarding, including a service's fixed timetable. */
export function connectionMargin(
  choice: PlanRow | undefined,
  day: string,
  timeZone: string,
  previousEnd: number,
  latestArrival: number,
): number | undefined {
  if (!choice) return undefined
  const boarding =
    typeof choice.departureBufferMinutes === 'number'
      ? choice.departureBufferMinutes
      : recommendedBuffer({ kind: choice.mode })
  try {
    const serviceTime = (key: 'departure' | 'arrival') => {
      const local =
        choice[key === 'departure' ? 'localDeparture' : 'localArrival']
      if (
        typeof local === 'string' &&
        local &&
        !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(local)
      )
        throw new Error('invalid local time')
      return typeof local === 'string'
        ? local
          ? zonedTimestamp(local.slice(0, 10), local.slice(11, 16), timeZone)
          : undefined
        : choice[key]
    }
    const departure = minuteInDay(serviceTime('departure'), day, timeZone),
      arrival = minuteInDay(serviceTime('arrival'), day, timeZone)
    if (departure != null && arrival != null)
      return Math.min(
        departure - previousEnd - boarding,
        latestArrival - arrival,
      )
    return typeof choice.durationMinutes === 'number'
      ? latestArrival - previousEnd - choice.durationMinutes - boarding
      : undefined
  } catch {
    return undefined
  }
}

export function dayStops(
  document: PlanDocument,
  day: string,
  includeActual = false,
) {
  const actualRefs = new Set(
    includeActual
      ? document.actuals
          .filter((row) => row.date === day || span(row, day) != null)
          .map((row) => row.activityRef)
      : [],
  )
  return document.activities
    .map((row, index) => ({ row, index }))
    .filter(
      ({ row }) =>
        actualRefs.has(row.ref) ||
        (row.bookingStatus !== 'cancelled' &&
          (row.date === day ||
            span(row, day) != null ||
            (row.kind === 'hotel' &&
              text(row.date) <= day &&
              text(row.endDate || row.date) >= day))),
    )
    .sort(
      (a, b) =>
        (minute(a.row.start) ?? 1440) - (minute(b.row.start) ?? 1440) ||
        a.index - b.index,
    )
}
export interface TimelineBlock {
  key: string
  kind: 'activity' | 'travel' | 'buffer' | 'actual'
  start: number
  end: number
  lane: number
  row: PlanRow
  index: number
  mode?: string
  title: string
}
export function timelineBlocks(
  document: PlanDocument,
  day: string,
  showActual = false,
): Array<TimelineBlock> {
  const result = assessDay(document, day)
  const blocks: Array<TimelineBlock> = result.items.map((item) => ({
    ...item,
    key: `activity-${item.index}`,
    kind: 'activity',
    title: text(item.row.title),
  }))
  for (const transfer of result.transfers) {
    const arrival = transfer.to.start,
      travelEnd = transfer.arrival ?? arrival - transfer.buffer,
      travelStart =
        transfer.departure ??
        (transfer.duration != null ? travelEnd - transfer.duration : undefined)
    if (
      transfer.duration != null &&
      transfer.duration > 0 &&
      travelStart != null
    )
      blocks.push({
        key: `travel-${transfer.from.index}-${transfer.to.index}`,
        kind: 'travel',
        start: Math.max(0, travelStart),
        end: Math.min(1440, travelEnd),
        lane: 0,
        row: transfer.to.row,
        index: transfer.to.index,
        mode: text(transfer.saved?.mode),
        title: `${text(transfer.from.row.title)} → ${text(transfer.to.row.title)}`,
      })
    if (travelStart != null && transfer.departureBuffer > 0)
      blocks.push({
        key: `departure-buffer-${transfer.to.index}`,
        kind: 'buffer',
        start: Math.max(0, travelStart - transfer.departureBuffer),
        end: Math.min(1440, travelStart),
        lane: 0,
        row: transfer.to.row,
        index: transfer.to.index,
        title: text(transfer.to.row.title),
      })
    if (transfer.buffer > 0)
      blocks.push({
        key: `buffer-${transfer.to.index}`,
        kind: 'buffer',
        start: Math.max(0, arrival - transfer.buffer),
        end: arrival,
        lane: 0,
        row: transfer.to.row,
        index: transfer.to.index,
        title: text(transfer.to.row.title),
      })
  }
  if (showActual)
    for (const actual of document.actuals) {
      const index = document.activities.findIndex(
          (row) => row.ref === actual.activityRef,
        ),
        row = document.activities[index]
      if (index < 0) continue
      const interval = span({ ...actual, kind: row.kind }, day)
      if (interval)
        blocks.push({
          key: `actual-${text(actual.ref)}`,
          kind: 'actual',
          start: interval[0],
          end: interval[1],
          lane: 0,
          row,
          index,
          title: text(row.title),
        })
    }
  const sorted = blocks
    .filter((block) => block.end > block.start)
    .sort((a, b) => a.start - b.start || a.end - b.end)
  const lanes: Array<number> = []
  for (const block of sorted) {
    let lane = lanes.findIndex((end) => end <= block.start)
    if (lane < 0) lane = lanes.length
    lanes[lane] = Math.max(block.end, block.start + 60)
    block.lane = lane
  }
  return sorted
}
