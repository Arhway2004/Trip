import { budgetTotals, records, text } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { assessDay } from '../schedule'
import { zonedTimestamp } from '../../transport/model'

export const num = (value: unknown, fallback = 0) =>
  typeof value === 'number' && Number.isFinite(value) ? value : fallback
export const object = (value: unknown): PlanRow =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as PlanRow)
    : {}
export const shift = (date: string, days: number) =>
  new Date(Date.parse(date + 'T00:00:00Z') + days * 86400000)
    .toISOString()
    .slice(0, 10)
export const daysBetween = (from: string, to: string) =>
  Math.round(
    (Date.parse(to + 'T00:00:00Z') - Date.parse(from + 'T00:00:00Z')) /
      86400000,
  )
export function dateRange(from: string, to: string) {
  const count = daysBetween(from, to)
  return Number.isFinite(count) && count >= 0 && count < 730
    ? Array.from({ length: count + 1 }, (_, index) => shift(from, index))
    : []
}
export const protectedBooking = (row: PlanRow) =>
  row.isLocked === true ||
  row.locked === true ||
  ['booked', 'confirmed', 'completed'].includes(text(row.bookingStatus)) ||
  !!row.bookingReference
export function dayData(doc: PlanDocument, date: string) {
  return (
    records(doc.dayPlans).find((row) => row.date === date) || {
      date,
      type: 'sightseeing',
      foodAmount: 0,
    }
  )
}
export function upsert(
  doc: PlanDocument,
  section: string,
  row: PlanRow,
): PlanDocument {
  const rows = records(doc[section]),
    ref = text(row.ref) || crypto.randomUUID()
  return {
    ...doc,
    [section]: rows.some((old) => old.ref === ref)
      ? rows.map((old) => (old.ref === ref ? { ...old, ...row, ref } : old))
      : [...rows, { ...row, ref }],
  }
}
export function removeRecord(
  doc: PlanDocument,
  section: string,
  ref: string,
): PlanDocument {
  return {
    ...doc,
    [section]: records(doc[section]).filter((row) => row.ref !== ref),
  }
}
export function libraryRows(doc: PlanDocument): Array<PlanRow> {
  const rows = records(doc.attractions)
  return [
    ...rows,
    ...doc.places.filter(
      (p) =>
        ['attraction', 'restaurant'].includes(text(p.category)) &&
        !rows.some((a) => a.ref === p.ref),
    ),
  ]
}
export function libraryCosts(
  doc: PlanDocument,
  travelers: number,
): PlanDocument {
  const generated = new Map<string, PlanRow>()
  const covered = new Set(
    doc.activities
      .filter(
        (a) =>
          a.bookingStatus !== 'cancelled' &&
          ['train', 'bus', 'transfer', 'transport', 'ferry'].includes(
            text(a.kind),
          ),
      )
      .map((a) => a.placeRef),
  )
  for (const place of libraryRows(doc).filter(
    (row) => row.selected && row.priority !== 'skip',
  )) {
    const visits = doc.activities
      .filter(
        (a) => a.placeRef === place.ref && a.bookingStatus !== 'cancelled',
      )
      .sort((a, b) => text(a.date).localeCompare(text(b.date)))
    for (const type of ['ticket', 'transport'] as const) {
      if (type === 'transport' && covered.has(place.ref)) continue
      const amount =
        num(place[type === 'ticket' ? 'ticketPrice' : 'transportCost']) *
        travelers
      if (!amount) continue
      const currency = text(
        place[type === 'ticket' ? 'ticketCurrency' : 'transportCurrency'],
      )
      const key = `${type}:${text(place[type === 'ticket' ? 'sharedTicketKey' : 'sharedTransportKey']) || text(place.ref)}:${currency}${type === 'transport' ? ':' + text(visits[0]?.date) : ''}`
      const old = generated.get(key)
      if (!old || num(old.amount) < amount)
        generated.set(key, {
          ref: `library:${key}`,
          title:
            text(place.name) + (type === 'transport' ? ' · transport' : ''),
          kind: 'planned',
          category: type === 'ticket' ? 'attractions' : 'transport',
          amount,
          currency,
          date: visits[0]?.date,
          activityRef: visits[0]?.ref,
          placeRef: place.ref,
          budgetLineRef: place.budgetLineRef,
          source: 'library',
          isPaid: false,
          city: place.city,
        })
    }
  }
  return {
    ...doc,
    expenses: [
      ...doc.expenses.filter((row) => row.source !== 'library'),
      ...generated.values(),
    ],
  }
}
export function addPlaceVisit(
  doc: PlanDocument,
  place: PlanRow,
  date: string,
  travelers: number,
): PlanDocument {
  const at =
    typeof place.lat === 'number' && typeof place.lng === 'number'
      ? { name: place.name, lat: place.lat, lng: place.lng }
      : { name: place.name }
  const next = {
    ...upsert(doc, 'attractions', { ...place, selected: true }),
    activities: [
      ...doc.activities,
      {
        ref: crypto.randomUUID(),
        title: place.name,
        kind: 'sightseeing',
        date,
        placeRef: place.ref,
        location: at,
        cost: 0,
        currency: place.ticketCurrency,
        notes: place.notes,
        isOptional: place.priority === 'optional',
      },
    ],
  }
  return libraryCosts(next, travelers)
}
export function bookingCost(row: PlanRow, travelers: number) {
  if (row.bookingStatus === 'cancelled') return 0
  if (row.kind === 'hotel' && row.pricePerNight != null)
    return (
      num(row.pricePerNight) *
      Math.max(1, num(row.rooms, 1)) *
      Math.max(0, daysBetween(text(row.date), text(row.endDate)))
    )
  if (row.unitPrice != null)
    return (
      num(row.unitPrice) *
        (row.priceMode === 'total'
          ? 1
          : Math.max(1, num(row.passengers, travelers))) +
      num(row.baggageFee) +
      num(row.seatFee) +
      num(row.otherFees)
    )
  return num(row.cost)
}
export function flightInstant(row: PlanRow, arrival: boolean, zone: string) {
  const date = text(
    arrival
      ? row.arrivalDate || row.endDate || row.date
      : row.departureDate || row.date,
  )
  const clock = text(
    arrival ? row.arrivalTime || row.end : row.departureTime || row.start,
  )
  if (!date || !clock) return undefined
  try {
    return (
      Date.parse(
        zonedTimestamp(
          date,
          clock,
          text(arrival ? row.arrivalTimeZone : row.departureTimeZone) || zone,
        ),
      ) / 60000
    )
  } catch {
    return undefined
  }
}
export function journeyDetails(doc: PlanDocument, ref: string, zone: string) {
  const legs = doc.activities
    .filter(
      (row) =>
        row.kind === 'flight' &&
        text(row.journeyRef) === ref &&
        row.bookingStatus !== 'cancelled',
    )
    .sort(
      (a, b) =>
        num(a.legOrder) - num(b.legOrder) ||
        (flightInstant(a, false, zone) ?? Infinity) -
          (flightInstant(b, false, zone) ?? Infinity),
    )
  const connections = legs.slice(1).map((to, index) => {
    const from = legs[index],
      arrival = flightInstant(from, true, zone),
      departure = flightInstant(to, false, zone)
    return {
      from,
      to,
      minutes:
        arrival != null && departure != null ? departure - arrival : undefined,
      airportChange: text(from.arrivalAirport) !== text(to.departureAirport),
    }
  })
  const first = legs[0] && flightInstant(legs[0], false, zone),
    last = legs.at(-1) && flightInstant(legs.at(-1)!, true, zone)
  return {
    legs,
    connections,
    duration: first != null && last != null ? last - first : undefined,
  }
}
export function hotelCoverage(doc: PlanDocument, dates: Array<string>) {
  return dates.slice(0, -1).map((date) => ({
    date,
    city: text(dayData(doc, date).overnightCity),
    hotels: doc.activities.filter(
      (row) =>
        row.kind === 'hotel' &&
        row.bookingStatus !== 'cancelled' &&
        text(row.date) <= date &&
        text(row.endDate) > date,
    ),
  }))
}
export function fillHotels(
  doc: PlanDocument,
  dates: Array<string>,
  currency: string,
): PlanDocument {
  const missing = hotelCoverage(doc, dates).filter(
    (day) => !day.hotels.length && day.city,
  )
  const groups: Array<{ start: string; end: string; city: string }> = []
  for (const day of missing) {
    const last = groups.at(-1)
    if (last && last.city === day.city && last.end === day.date)
      last.end = shift(day.date, 1)
    else
      groups.push({ start: day.date, end: shift(day.date, 1), city: day.city })
  }
  return {
    ...doc,
    activities: [
      ...doc.activities,
      ...groups.map((group) => ({
        ref: crypto.randomUUID(),
        title: `Hotel TBD · ${group.city}`,
        kind: 'hotel',
        date: group.start,
        endDate: group.end,
        city: group.city,
        currency,
        rooms: 1,
        bookingStatus: 'notBooked',
        verification: 'needs',
        start: '14:00',
        end: '12:00',
      })),
    ],
  }
}
export function planMetrics(
  doc: PlanDocument,
  dates: Array<string>,
  currency: string,
  travelers: number,
) {
  const totals = budgetTotals(doc, currency, travelers)
  const days = dates.map((date) => {
    const check = assessDay(doc, date),
      rows = check.items.map((i) => i.row)
    const travel =
      check.items
        .filter((i) =>
          ['flight', 'train', 'bus', 'ferry', 'transfer', 'transport'].includes(
            text(i.row.kind),
          ),
        )
        .reduce((sum, i) => sum + i.end - i.start, 0) +
      check.transfers.reduce((sum, t) => sum + (t.duration ?? 0), 0)
    const activity = check.items.reduce((sum, i) => sum + i.end - i.start, 0)
    const walking = rows.reduce((sum, row) => {
      const place = libraryRows(doc).find((p) => p.ref === row.placeRef)
      return (
        sum +
        (place?.walking === 'high' ? 1 : place?.walking === 'low' ? 0.25 : 0.5)
      )
    }, 0)
    const altitude = Math.max(
      0,
      ...rows.map((row) =>
        num(libraryRows(doc).find((p) => p.ref === row.placeRef)?.altitude),
      ),
    )
    const early = (check.items.at(0)?.start ?? 1440) < 420,
      late = check.items.some((i) => i.end > 1320)
    const score = Math.max(
      1,
      Math.min(
        10,
        Math.round(
          1 +
            travel / 120 +
            walking * 0.6 +
            (early ? 1 : 0) +
            (late ? 1 : 0) +
            (altitude >= 3000 ? 1 : 0) +
            Math.max(0, rows.length - 4) * 0.4 -
            (dayData(doc, date).type === 'rest' ? 1 : 0),
        ),
      ),
    )
    return {
      date,
      check,
      travel,
      activity,
      free: Math.max(
        0,
        900 -
          activity -
          check.transfers.reduce(
            (sum, t) => sum + (t.duration ?? 0) + t.buffer + t.departureBuffer,
            0,
          ),
      ),
      score,
      early,
      late,
      altitude,
      walking,
    }
  })
  return {
    ...totals,
    days,
    transportHours: days.reduce((sum, d) => sum + d.travel, 0) / 60,
    highFatigueDays: days.filter((d) => d.score >= 7).length,
    avgFatigue: days.length
      ? days.reduce((sum, d) => sum + d.score, 0) / days.length
      : 0,
    issues: days.reduce(
      (sum, d) =>
        sum +
        d.check.overlaps.length +
        d.check.transfers.filter((t) => t.remaining != null && t.remaining < 0)
          .length,
      0,
    ),
    hotelChanges: Math.max(
      0,
      doc.activities.filter(
        (a) => a.kind === 'hotel' && a.bookingStatus !== 'cancelled',
      ).length - 1,
    ),
    freeHours: days.reduce((sum, d) => sum + d.free, 0) / 60,
  }
}
export function cloneDay(
  doc: PlanDocument,
  from: string,
  to: string,
): PlanDocument {
  const delta = daysBetween(from, to)
  const copies = doc.activities
    .filter((row) => row.date === from)
    .map((row) => ({
      ...row,
      ref: crypto.randomUUID(),
      date: to,
      endDate: row.endDate ? shift(text(row.endDate), delta) : undefined,
      bookingStatus: 'notBooked',
      bookingReference: undefined,
      isLocked: false,
      locked: false,
      isPaid: false,
      journeyRef: undefined,
    }))
  return {
    ...doc,
    activities: [...doc.activities, ...copies],
    dayPlans: [
      ...records(doc.dayPlans).filter((row) => row.date !== to),
      { ...dayData(doc, from), date: to },
    ],
  }
}
export function shiftPlanDates(
  doc: PlanDocument,
  delta: number,
  moveBookings: boolean,
): PlanDocument {
  const move = (row: PlanRow, keys: Array<string>) =>
    Object.fromEntries(
      Object.entries(row).map(([key, value]) => [
        key,
        keys.includes(key) &&
        typeof value === 'string' &&
        /^\d{4}-\d{2}-\d{2}$/.test(value)
          ? shift(value, delta)
          : value,
      ]),
    )
  return {
    ...doc,
    activities: doc.activities.map((row) =>
      protectedBooking(row) && !moveBookings
        ? row
        : move(row, ['date', 'endDate', 'departureDate', 'arrivalDate']),
    ),
    dayPlans: records(doc.dayPlans).map((row) => move(row, ['date'])),
    connections: records(doc.connections).filter((row) => !row.departure),
    todos: doc.todos.map((row) => move(row, ['dueDate'])),
  }
}
const snapshotKeys = [
  'activities',
  'dayPlans',
  'journeys',
  'budgetLines',
  'connections',
]
export function scenarioSnapshot(doc: PlanDocument): PlanRow {
  return {
    ...Object.fromEntries(snapshotKeys.map((key) => [key, doc[key] ?? []])),
    expenses: doc.expenses.filter((row) => row.kind === 'planned'),
    selectedPlaceRefs: libraryRows(doc)
      .filter((row) => row.selected)
      .map((row) => row.ref),
    planningStartDate: doc.planningStartDate,
    planningEndDate: doc.planningEndDate,
  }
}
export function switchScenario(
  doc: PlanDocument,
  target: string,
): PlanDocument {
  const scenarios = records(doc.scenarios),
    active = text(doc.activeScenarioRef)
  const found = scenarios.find((row) => row.ref === target)
  if (!found) return doc
  const updated = scenarios.map((row) =>
    row.ref === active ? { ...row, snapshot: scenarioSnapshot(doc) } : row,
  )
  const snapshot = object(found.snapshot),
    selected = Array.isArray(snapshot.selectedPlaceRefs)
      ? snapshot.selectedPlaceRefs
      : []
  return {
    ...doc,
    ...snapshot,
    expenses: [
      ...records(snapshot.expenses),
      ...doc.expenses.filter((row) => row.kind !== 'planned'),
    ],
    places: doc.places.map((row) => ({
      ...row,
      selected: selected.includes(row.ref),
    })),
    attractions: records(doc.attractions).map((row) => ({
      ...row,
      selected: selected.includes(row.ref),
    })),
    scenarios: updated,
    activeScenarioRef: target,
  }
}
