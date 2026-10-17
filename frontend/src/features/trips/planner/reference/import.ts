import type { PlanDocument, PlanRow } from '../model'
import { text, parseDocument } from '../model'
import {
  bookingCost,
  libraryCosts,
  num,
  object,
  scenarioSnapshot,
  shift,
} from './domain'
import { localDateTime, zonedTimestamp } from '../../transport/model'

export interface RestoreTrip {
  document: PlanDocument
  media: Record<string, string>
}
const status = (value: unknown) =>
  value === 'booked' || value === 'completed'
    ? 'booked'
    : value === 'cancelled'
      ? 'cancelled'
      : 'notBooked'
function sourceRows(value: unknown, path: string) {
  if (value == null) return []
  if (
    !Array.isArray(value) ||
    value.some((v) => !v || typeof v !== 'object' || Array.isArray(v))
  )
    throw new Error(path + ': expected records')
  return value as Array<PlanRow>
}
function referenceTrip(raw: PlanRow): RestoreTrip {
  const scenarioRows = sourceRows(raw.scenarios, 'scenarios')
  if (!scenarioRows.length)
    throw new Error('scenarios: at least one plan is required')
  const currency = object(raw.currency),
    base = text(currency.primary) || 'THB',
    secondary = text(currency.secondary) || 'CNY',
    pax = Math.max(1, num(raw.travelers, 1))
  const cities = sourceRows(raw.cities, 'cities'),
    zone = text(cities[0]?.tz) || 'Asia/Shanghai',
    places = sourceRows(raw.places, 'places'),
    attractions = sourceRows(raw.attractions, 'attractions')
  const location = (p: PlanRow | undefined) =>
    p && typeof p.lat === 'number' && typeof p.lng === 'number'
      ? { name: text(p.name || p.nameEn), lat: p.lat, lng: p.lng }
      : p
        ? { name: text(p.name || p.nameEn) }
        : undefined
  const docs = scenarioRows.map((sc) => {
    const first = text(sc.startDate)
    if (
      !/^\d{4}-\d{2}-\d{2}$/.test(first) ||
      !Number.isFinite(Date.parse(first))
    )
      throw new Error('scenario.startDate: valid date required')
    const days = sourceRows(sc.days, 'days'),
      selected = object(sc.selected)
    let doc = parseDocument(
      JSON.stringify({
        format: 'wanderplan.trip',
        schemaVersion: 3,
        trip: {
          title: text(raw.name) || 'Imported trip',
          description: text(raw.notes),
          startDate: first,
          endDate: shift(first, Math.max(0, days.length - 1)),
          timeZone: zone,
          currency: base,
          travelerCount: pax,
          totalBudget: num(raw.budgetLimit),
          stage: 'planning',
          datesConfirmed: false,
        },
        planningStartDate: first,
        planningEndDate: shift(first, Math.max(0, days.length - 1)),
        destinations: cities.map((c) => ({
          ref: c.id,
          city: text(c.en || c.zh),
          country: text(c.country),
          lat: c.lat,
          lng: c.lng,
          altitude: c.altitude,
          timeZone: c.tz,
          nameZh: c.zh,
          nameTh: c.th,
        })),
        places: places
          .filter((p) => typeof p.lat === 'number' && typeof p.lng === 'number')
          .map((p) => ({
            ...p,
            ref: text(p.id),
            category:
              p.type === 'station'
                ? 'railwayStation'
                : p.type === 'bus'
                  ? 'busStation'
                  : p.type === 'ferry'
                    ? 'ferryTerminal'
                    : p.type === 'custom'
                      ? 'attraction'
                      : p.type,
            name: text(p.name || p.nameEn),
          })),
        attractions: attractions.map((a) => ({
          ...a,
          ref: text(a.id),
          category: 'attraction',
          attractionCategory: a.category,
          name: text(a.nameEn || a.name),
          selected: !!selected[text(a.id)],
          durationMinutes: a.durationMin,
          verification: a.coordStatus,
          budgetLineRef: a.budgetLineId,
        })),
        dayPlans: days.map((d, i) => ({
          ...d,
          ref: shift(first, i),
          date: shift(first, i),
          foodAmount: num(object(d.food).amount),
          currency: text(object(d.food).currency) || base,
        })),
        journeys: sourceRows(sc.journeys, 'journeys').map((j) => ({
          ...j,
          ref: text(j.id),
        })),
        budgetLines: sourceRows(sc.budgetLines, 'budgetLines').map((l) => ({
          ...l,
          ref: text(l.id),
          name: text(object(l.name).en) || text(l.name) || text(l.id),
          categories: Array.isArray(l.categories)
            ? l.categories.join(',')
            : l.categories,
          cities: Array.isArray(l.cities) ? l.cities.join(',') : l.cities,
        })),
        exchangeRates:
          secondary !== base && num(currency.rate) > 0
            ? [
                {
                  currency: secondary,
                  rate: num(currency.rate),
                  source: currency.rateSource,
                  date: currency.rateDate,
                },
              ]
            : [],
      }),
    )
    const activities: Array<PlanRow> = []
    days.forEach((day, index) =>
      sourceRows(day.activities, 'day.activities').forEach((a) => {
        const attraction = attractions.find((p) => p.id === a.attractionId),
          cost = object(a.cost)
        activities.push({
          ...a,
          ref: text(a.id),
          title:
            text(a.title) ||
            text(attraction?.nameEn || attraction?.name) ||
            text(a.kind) ||
            'Activity',
          date: shift(first, index),
          endDate:
            a.end && a.start && text(a.end) < text(a.start)
              ? shift(first, index + 1)
              : undefined,
          kind:
            a.kind === 'attraction'
              ? 'sightseeing'
              : a.kind === 'meal'
                ? 'food'
                : a.kind === 'custom'
                  ? 'other'
                  : a.kind || 'other',
          start: a.start || undefined,
          end: a.end || undefined,
          location: location(attraction) || a.location,
          placeRef: a.attractionId || undefined,
          cost: attraction ? 0 : num(cost.amount) * (cost.perPerson ? pax : 1),
          currency: text(cost.currency) || base,
          bookingStatus: status(a.status),
          isOptional: attraction?.priority === 'optional',
          notes: text(a.notes),
        })
      }),
    )
    for (const f of sourceRows(sc.flights, 'flights')) {
      const depDate = text(f.depDate) || first,
        arrDate = text(f.arrDate) || depDate,
        depZone = text(f.depTz) || zone,
        arrZone = text(f.arrTz) || zone
      let localStart = '',
        localEnd = ''
      if (f.depTime && f.arrTime) {
        try {
          localStart = localDateTime(
            zonedTimestamp(depDate, text(f.depTime), depZone),
            zone,
          )
          localEnd = localDateTime(
            zonedTimestamp(arrDate, text(f.arrTime), arrZone),
            zone,
          )
        } catch {
          throw new Error('flight: invalid local date/time')
        }
      }
      const row: PlanRow = {
        ...f,
        ref: text(f.id),
        title: [
          f.flightNo,
          `${text(f.depIata) || text(f.depAirport)} → ${text(f.arrIata) || text(f.arrAirport)}`,
        ]
          .filter(Boolean)
          .join(' '),
        kind: 'flight',
        date: localStart ? localStart.slice(0, 10) : depDate,
        endDate: localEnd ? localEnd.slice(0, 10) : arrDate,
        start: localStart ? localStart.slice(11) : undefined,
        end: localEnd ? localEnd.slice(11) : undefined,
        departureDate: depDate,
        arrivalDate: arrDate,
        departureTime: f.depTime,
        arrivalTime: f.arrTime,
        departureTimeZone: depZone,
        arrivalTimeZone: arrZone,
        departureAirport: f.depIata,
        arrivalAirport: f.arrIata,
        departureTerminal: f.depTerminal,
        arrivalTerminal: f.arrTerminal,
        provider: f.airline,
        serviceNumber: f.flightNo,
        journeyRef: f.journeyId,
        legOrder: f.order,
        unitPrice: num(f.price),
        priceMode: f.priceMode === 'total' ? 'total' : 'perPerson',
        passengers: num(f.pax, pax),
        baggageFee: num(f.extraBaggageCost),
        seatFee: num(f.seatFee),
        otherFees: num(f.otherFees),
        currency: text(f.currency) || base,
        bookingStatus: status(f.status),
        bookingReference: text(f.bookingRef),
        bookingUrl: text(f.bookingUrl),
        isPaid: f.paid === true,
        location: location(places.find((p) => p.iata === f.depIata)),
        destination: location(places.find((p) => p.iata === f.arrIata)),
      }
      row.cost = bookingCost(row, pax)
      activities.push(row)
    }
    for (const t of sourceRows(sc.transports, 'transports')) {
      const row: PlanRow = {
        ...t,
        ref: text(t.id),
        title: `${text(t.origin)} → ${text(t.destination)}`,
        kind: ['train', 'hsr'].includes(text(t.type))
          ? 'train'
          : t.type === 'ferry'
            ? 'ferry'
            : 'bus',
        date: text(t.depDate) || first,
        endDate: text(t.arrDate) || text(t.depDate) || first,
        start: t.depTime || undefined,
        end: t.arrTime || undefined,
        transportType: t.type,
        serviceNumber: t.serviceNo,
        placeRef: t.linkedAttractionId,
        fromPlaceRef: t.fromPlaceId,
        toPlaceRef: t.toPlaceId,
        unitPrice: num(t.price),
        priceMode: t.priceMode === 'total' ? 'total' : 'perPerson',
        passengers: num(t.travelers, pax),
        currency: text(t.currency) || base,
        bookingStatus: status(t.status),
        bookingReference: text(t.bookingRef),
        bookingUrl: text(t.bookingUrl),
        isPaid: t.paid === true,
        location: location(places.find((p) => p.id === t.fromPlaceId)) || {
          name: text(t.origin),
        },
        destination: location(places.find((p) => p.id === t.toPlaceId)) || {
          name: text(t.destination),
        },
      }
      row.cost = bookingCost(row, pax)
      activities.push(row)
    }
    for (const h of sourceRows(sc.hotels, 'hotels')) {
      const row: PlanRow = {
        ...h,
        ref: text(h.id),
        title: text(h.name) || 'Hotel',
        kind: 'hotel',
        date: text(h.checkIn) || first,
        endDate: h.checkOut || undefined,
        start: h.checkInTime || undefined,
        end: h.checkOutTime || undefined,
        rooms: num(h.rooms, 1),
        pricePerNight: num(h.pricePerNight),
        currency: text(h.currency) || base,
        bookingStatus: status(h.status),
        bookingReference: text(h.bookingRef),
        bookingUrl: text(h.bookingUrl),
        isPaid: h.paid === true,
        location: location(h),
      }
      row.cost = bookingCost(row, pax)
      activities.push(row)
    }
    doc.activities = activities
    doc.expenses = [
      ...sourceRows(sc.expenses, 'expenses').map((e) => ({
        ...e,
        ref: text(e.id),
        title: text(e.description) || text(e.category) || 'Expense',
        kind: 'actual',
        currency: text(e.currency) || base,
        amount: num(e.amount),
        date: e.date || undefined,
        activityRef: e.linkedItemId || undefined,
        budgetLineRef: e.budgetLineId,
        isPaid: e.paid !== false,
      })),
      ...sourceRows(sc.plannedExpenses, 'plannedExpenses').map((e) => ({
        ...e,
        ref: text(e.id),
        title: text(e.description) || text(e.category) || 'Expense',
        kind: 'planned',
        currency: text(e.currency) || base,
        amount: num(e.amount),
        date: e.date || undefined,
        budgetLineRef: e.budgetLineId,
        isAllowance: e.kind === 'allowance',
        isPaid: false,
      })),
      ...days
        .filter((d) => num(object(d.food).amount) > 0)
        .map((d) => {
          const index = days.indexOf(d)
          return {
            ref: 'food:' + shift(first, index),
            title: 'Food',
            kind: 'planned',
            date: shift(first, index),
            category: 'food',
            amount: num(object(d.food).amount),
            currency: text(object(d.food).currency) || base,
            isAllowance: true,
            source: 'day-food',
            isPaid: false,
          }
        }),
    ]
    doc = libraryCosts(doc, pax)
    return { sc, doc }
  })
  const active = docs.find((d) => d.sc.id === raw.activeScenarioId) || docs[0],
    doc = active.doc
  doc.scenarios = docs.map(({ sc, doc: snapshot }) => ({
    ref: text(sc.id),
    name: text(sc.name) || 'Scenario',
    notes: sc.notes,
    snapshot: scenarioSnapshot(snapshot),
  }))
  doc.activeScenarioRef = active.sc.id
  doc.referenceImport = raw
  return { document: doc, media: {} }
}
export function convertReference(
  value: unknown,
): Array<RestoreTrip> | undefined {
  const raw = object(value)
  if (raw.schema !== 'china-trip-planner') return undefined
  if (raw.schemaVersion !== 1)
    throw new Error('Unsupported reference schema version')
  const trips = raw.trips ? sourceRows(raw.trips, 'trips') : [object(raw.trip)]
  if (!trips.length || trips.some((t) => !t.name || !t.scenarios))
    throw new Error('Reference file contains no valid trips')
  return trips.map(referenceTrip)
}
