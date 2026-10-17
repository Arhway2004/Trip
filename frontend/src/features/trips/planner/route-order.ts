import { records, text } from './model'
import {
  connectionKey,
  connectionSignature,
  minute,
  point,
  timeLabel,
} from './schedule'
import type { PlanDocument, PlanRow } from './model'
import type { RoadMatrix } from '../maps.functions'

export const transportKinds = new Set([
  'flight',
  'train',
  'bus',
  'ferry',
  'transfer',
  'transport',
])
export function protectedStop(row: PlanRow) {
  return (
    row.locked === true ||
    row.isLocked === true ||
    row.bookingStatus === 'booked' ||
    row.bookingStatus === 'confirmed' ||
    !!text(row.bookingReference) ||
    transportKinds.has(text(row.kind))
  )
}
export function routeStops(document: PlanDocument, day: string) {
  return document.activities
    .filter(
      (row) =>
        row.date === day &&
        row.kind !== 'hotel' &&
        row.bookingStatus !== 'cancelled',
    )
    .sort((a, b) => (minute(a.start) ?? 1440) - (minute(b.start) ?? 1440))
}
export function canCompareStops(stops: Array<PlanRow>, day: string) {
  return (
    stops.length >= 2 &&
    stops.length <= 8 &&
    new Set(stops.map((row) => row.ref)).size === stops.length &&
    stops.every((row) => {
      const at = point(row.location),
        end = point(row.destination)
      return (
        at &&
        !transportKinds.has(text(row.kind)) &&
        (!row.endDate || row.endDate === day) &&
        (!end || (end.lat === at.lat && end.lng === at.lng)) &&
        (!protectedStop(row) ||
          (minute(row.start) != null &&
            minute(row.end) != null &&
            minute(row.end)! > minute(row.start)!))
      )
    })
  )
}
export interface RouteVisit {
  index: number
  start: number
  end: number
  travel: number
}
export interface RouteOption {
  order: Array<number>
  visits: Array<RouteVisit>
  travel: number
  finish: number
  wait: number
  feasible: boolean
}
export interface RouteSettings {
  start: number
  end: number
  visit: number
  buffer: number
  movable: Array<string>
}

export function suggestOrders(
  stops: Array<PlanRow>,
  matrix: RoadMatrix,
  settings: RouteSettings,
): Array<RouteOption> {
  if (
    stops.length < 2 ||
    stops.length > 8 ||
    matrix.minutes.length !== stops.length ||
    matrix.minutes.some((row) => row.length !== stops.length) ||
    ![settings.start, settings.end, settings.visit, settings.buffer].every(
      Number.isFinite,
    ) ||
    settings.start < 0 ||
    settings.end > 1440 ||
    settings.start >= settings.end ||
    settings.visit <= 0 ||
    settings.buffer < 0
  )
    return []
  const fixed = (index: number) =>
    index === 0 ||
    protectedStop(stops[index]) ||
    !settings.movable.includes(text(stops[index].ref))
  const anchors = stops.map((_, i) => i).filter(fixed)
  function evaluate(order: Array<number>): RouteOption {
    let clock = settings.start,
      travel = 0,
      wait = 0,
      feasible = true
    const visits = order.map((index, position) => {
      const row = stops[index],
        road = position ? matrix.minutes[order[position - 1]][index] : 0
      if (road === null || !Number.isFinite(road) || road < 0) feasible = false
      const leg = road ?? 0
      travel += leg
      clock += leg + (position ? settings.buffer : 0)
      const oldStart = minute(row.start),
        oldEnd = minute(row.end)
      const duration =
        oldStart != null && oldEnd != null && oldEnd > oldStart
          ? oldEnd - oldStart
          : settings.visit
      const start = fixed(index) && oldStart != null ? oldStart : clock
      if (start < clock) feasible = false
      wait += Math.max(0, start - clock)
      const end = fixed(index) && oldEnd != null ? oldEnd : start + duration
      if (end <= start || end > settings.end) feasible = false
      clock = end
      return { index, start, end, travel: leg }
    })
    return { order, visits, travel, wait, finish: clock, feasible }
  }
  const current = evaluate(stops.map((_, index) => index)),
    all: Array<RouteOption> = []
  function search(order: Array<number>, remaining: Array<number>) {
    if (!remaining.length) {
      const option = evaluate(order)
      if (option.feasible) all.push(option)
      return
    }
    const nextAnchor = anchors.find((index) => remaining.includes(index))
    for (const index of remaining)
      if (!fixed(index) || index === nextAnchor)
        search(
          [...order, index],
          remaining.filter((other) => other !== index),
        )
  }
  search(
    [0],
    stops.slice(1).map((_, i) => i + 1),
  )
  // Avoid presenting orders that are worse in every displayed measure.
  const dominates = (a: RouteOption, b: RouteOption) =>
    a.travel <= b.travel && a.finish <= b.finish && a.wait <= b.wait
  let frontier: Array<RouteOption> = []
  for (const candidate of all) {
    if (frontier.some((other) => dominates(other, candidate))) continue
    frontier = frontier.filter((other) => !dominates(candidate, other))
    frontier.push(candidate)
  }
  const choices = [current]
  const add = (sorted: Array<RouteOption>) => {
    const candidate = sorted.find(
      (row) =>
        !choices.some((old) => old.order.join(',') === row.order.join(',')),
    )
    if (candidate) choices.push(candidate)
  }
  add([...frontier].sort((a, b) => a.travel - b.travel || a.finish - b.finish))
  add([...frontier].sort((a, b) => a.finish - b.finish || a.travel - b.travel))
  add([...frontier].sort((a, b) => a.wait - b.wait || a.travel - b.travel))
  return choices.slice(0, 4)
}

/** Caller supplies a freshly computed option for the current document. */
export function applyOrder(
  document: PlanDocument,
  stops: Array<PlanRow>,
  option: RouteOption,
  matrix: RoadMatrix,
  settings: RouteSettings,
  mode: 'walking' | 'cycling' | 'driving',
): PlanDocument {
  if (!option.feasible) return document
  const updates = new Map<string, PlanRow>(
    option.visits.map((visit) => [
      text(stops[visit.index].ref),
      {
        ...stops[visit.index],
        start: timeLabel(visit.start),
        end: timeLabel(visit.end),
      },
    ]),
  )
  const refs = new Set(updates.keys()),
    oldConnections = records(document.connections)
  const obsolete = new Set(
    oldConnections
      .filter((row) => refs.has(text(row.fromRef)) && refs.has(text(row.toRef)))
      .map((row) => row.key),
  )
  const connections = oldConnections.filter((row) => !obsolete.has(row.key))
  const retained = new Set<string>()
  for (let position = 1; position < option.visits.length; position++) {
    const visit = option.visits[position],
      previous = option.visits[position - 1]
    const from = updates.get(text(stops[previous.index].ref))!,
      to = updates.get(text(stops[visit.index].ref))!
    const key = connectionKey(from, to),
      saved = oldConnections.find(
        (row) => row.key === key && row.mode === mode && !row.departure,
      )
    if (saved) retained.add(key)
    connections.push({
      ...saved,
      key,
      fromRef: from.ref,
      toRef: to.ref,
      mode,
      signature: connectionSignature(from, to, mode),
      durationMinutes: visit.travel,
      bufferMinutes: settings.buffer,
      departureBufferMinutes: 0,
      source: matrix.source,
      fetchedAt: matrix.fetchedAt,
    })
  }
  return {
    ...document,
    activities: document.activities.map(
      (row) => updates.get(text(row.ref)) || row,
    ),
    connections,
    expenses: document.expenses.filter(
      (row) =>
        row.kind !== 'planned' ||
        row.isPaid === true ||
        !obsolete.has(row.connectionRef) ||
        retained.has(text(row.connectionRef)),
    ),
  }
}
