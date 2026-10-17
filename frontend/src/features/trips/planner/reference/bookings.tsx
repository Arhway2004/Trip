import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { text, records } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { formatMoney } from '#/lib/format'
import { localDateTime } from '../../transport/model'
import {
  bookingCost,
  fillHotels,
  flightInstant,
  hotelCoverage,
  journeyDetails,
  num,
  upsert,
} from './domain'
import { r } from './copy'
import { RecordForm } from './record-form'
import type { Field } from './record-form'
import { Confirm } from './confirm'

const currencies = (row: PlanRow, base: string) => text(row.currency) || base
const common: Array<Field> = [
  { key: 'currency', label: 'c.currency', required: true },
  {
    key: 'bookingStatus',
    label: 'c.status',
    type: 'select',
    options: [
      ['notBooked', 'status.planning'],
      ['booked', 'status.booked'],
      ['confirmed', 'cs.confirmed'],
      ['cancelled', 'status.cancelled'],
    ],
  },
  {
    key: 'verification',
    label: 'c.verification',
    type: 'select',
    options: ['verified', 'user', 'estimated', 'needs'].map((v) => [
      v,
      'verif.' + v,
    ]),
  },
  { key: 'isPaid', label: 'c.paid', type: 'checkbox' },
  { key: 'bookingReference', label: 'c.bookingRef' },
  { key: 'bookingUrl', label: 'c.bookingUrl', type: 'url' },
  { key: 'city', label: 'c.city' },
  { key: 'notes', label: 'c.notes', type: 'textarea' },
]
export function BookingTools({
  document,
  dates,
  zone,
  currency,
  travelers,
  disabled,
  onSave,
  onEdit,
}: {
  document: PlanDocument
  dates: Array<string>
  zone: string
  currency: string
  travelers: number
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
  onEdit: (index: number) => void
}) {
  const [view, setView] = useState<'flight' | 'ground' | 'hotel'>('flight'),
    [editor, setEditor] = useState<PlanRow>(),
    [journey, setJourney] = useState<PlanRow>(),
    [pending, setPending] = useState<PlanRow>()
  const journeys = records(document.journeys),
    rows = document.activities.filter((a) =>
      view === 'flight'
        ? a.kind === 'flight'
        : view === 'hotel'
          ? a.kind === 'hotel'
          : ['train', 'bus', 'ferry', 'transfer', 'transport'].includes(
              text(a.kind),
            ),
    )
  const create = () =>
    setEditor({
      ref: crypto.randomUUID(),
      kind: view === 'ground' ? 'train' : view,
      date: dates[0],
      endDate: view === 'hotel' ? dates[1] || dates[0] : dates[0],
      title: '',
      currency,
      bookingStatus: 'notBooked',
      passengers: travelers,
      rooms: 1,
      departureTimeZone: zone,
      arrivalTimeZone: zone,
      priceMode: 'total',
      departureDate: dates[0],
      arrivalDate: dates[0],
    })
  const placeOptions = document.places.map((p): [string, string] => [
    text(p.ref),
    text(p.name),
  ])
  const travelFields: Array<Field> = [
    { key: 'title', label: 'c.name', required: true },
    { key: 'provider', label: view === 'flight' ? 'fl.airline' : 'c.name' },
    {
      key: 'serviceNumber',
      label: view === 'flight' ? 'fl.flightNo' : 'tr.serviceNo',
    },
    ...(view === 'flight'
      ? ([
          {
            key: 'journeyRef',
            label: 'fl.journey',
            type: 'select',
            options: journeys.map((j): [string, string] => [
              text(j.ref),
              text(j.name),
            ]),
          },
          { key: 'legOrder', label: 'c.order', type: 'number', min: 0 },
          { key: 'departureAirport', label: 'fl.depAirport' },
          { key: 'arrivalAirport', label: 'fl.arrAirport' },
          { key: 'departureTerminal', label: 'fl.depTerminal' },
          { key: 'arrivalTerminal', label: 'fl.arrTerminal' },
          { key: 'departureTimeZone', label: 'fl.depTz', required: true },
          { key: 'arrivalTimeZone', label: 'fl.arrTz', required: true },
        ] as Array<Field>)
      : ([
          {
            key: 'transportType',
            label: 'c.type',
            type: 'select',
            options: [
              'hsr',
              'train',
              'bus',
              'shuttle',
              'airport_shuttle',
              'taxi',
              'ridehail',
              'metro',
              'citybus',
              'driver',
              'ferry',
              'walk',
              'other',
            ].map((v): [string, string] => [v, 'tt.' + v]),
          },
          { key: 'depStation', label: 'tr.depStation' },
          { key: 'arrStation', label: 'tr.arrStation' },
          {
            key: 'placeRef',
            label: 'tr.linked',
            type: 'select',
            options: placeOptions,
          },
        ] as Array<Field>)),
    {
      key: 'fromPlaceRef',
      label: 'tr.fromPlace',
      type: 'select',
      options: placeOptions,
    },
    {
      key: 'toPlaceRef',
      label: 'tr.toPlace',
      type: 'select',
      options: placeOptions,
    },
    { key: 'departureDate', label: 'fl.depDate', type: 'date', required: true },
    { key: 'departureTime', label: 'fl.depTime', type: 'time' },
    { key: 'arrivalDate', label: 'fl.arrDate', type: 'date', required: true },
    { key: 'arrivalTime', label: 'fl.arrTime', type: 'time' },
    { key: 'unitPrice', label: 'c.price', type: 'number', min: 0 },
    {
      key: 'priceMode',
      label: 'fl.priceMode',
      type: 'select',
      options: [
        ['total', 'fl.totalPrice'],
        ['perPerson', 'fl.perPax'],
      ],
    },
    {
      key: 'passengers',
      label: 'c.travelers',
      type: 'number',
      min: 1,
      max: 99,
    },
    { key: 'baggageFee', label: 'fl.extraBaggage', type: 'number', min: 0 },
    { key: 'seatFee', label: 'fl.seatFee', type: 'number', min: 0 },
    { key: 'otherFees', label: 'fl.otherFees', type: 'number', min: 0 },
    { key: 'luggageNotes', label: 'tr.luggage', type: 'textarea' },
    { key: 'transferNotes', label: 'tr.transferNotes', type: 'textarea' },
    ...common,
  ]
  const hotelFields: Array<Field> = [
    { key: 'title', label: 'ht.name', required: true },
    { key: 'address', label: 'c.address' },
    { key: 'date', label: 'ht.checkIn', type: 'date', required: true },
    { key: 'endDate', label: 'ht.checkOut', type: 'date', required: true },
    { key: 'start', label: 'ht.checkInTime', type: 'time' },
    { key: 'latestCheckIn', label: 'ht.latest', type: 'time' },
    { key: 'end', label: 'ht.checkOutTime', type: 'time' },
    { key: 'rooms', label: 'ht.rooms', type: 'number', min: 1 },
    { key: 'pricePerNight', label: 'ht.ppn', type: 'number', min: 0 },
    {
      key: 'heating',
      label: 'ht.heating',
      type: 'select',
      options: ['unknown', 'yes', 'no'].map((v) => [v, 'heating.' + v]),
    },
    { key: 'cancellation', label: 'ht.cancellation', type: 'textarea' },
    ...common,
  ]
  async function saveBooking(row: PlanRow) {
    if (!/^[A-Z]{3}$/.test(text(row.currency))) return false
    let next = { ...row }
    if (view !== 'hotel') {
      const dep = flightInstant(row, false, zone),
        arr = flightInstant(row, true, zone)
      if (
        (row.departureTime || row.arrivalTime) &&
        (dep == null || arr == null || arr <= dep)
      )
        return false
      if (dep != null && arr != null) {
        const start = localDateTime(new Date(dep * 60000).toISOString(), zone),
          end = localDateTime(new Date(arr * 60000).toISOString(), zone)
        next = {
          ...next,
          date: start.slice(0, 10),
          start: start.slice(11),
          endDate: end.slice(0, 10),
          end: end.slice(11),
        }
      } else
        next = {
          ...next,
          date: row.departureDate,
          endDate: row.arrivalDate,
          start: undefined,
          end: undefined,
        }
      if (view === 'ground')
        next.kind = ['train', 'hsr'].includes(text(row.transportType))
          ? 'train'
          : row.transportType === 'ferry'
            ? 'ferry'
            : ['bus', 'citybus', 'shuttle', 'airport_shuttle'].includes(
                  text(row.transportType),
                )
              ? 'bus'
              : 'transfer'
    } else if (text(row.endDate) <= text(row.date)) return false
    const from = document.places.find((p) => p.ref === row.fromPlaceRef),
      to = document.places.find((p) => p.ref === row.toPlaceRef)
    if (from) next.location = { name: from.name, lat: from.lat, lng: from.lng }
    if (to) next.destination = { name: to.name, lat: to.lat, lng: to.lng }
    next.cost = bookingCost(next, travelers)
    return onSave(upsert(document, 'activities', next))
  }
  function edit(row: PlanRow) {
    setEditor({
      ...row,
      departureDate: row.departureDate || row.date,
      arrivalDate: row.arrivalDate || row.endDate || row.date,
      departureTime: row.departureTime || row.start,
      arrivalTime: row.arrivalTime || row.end,
      departureTimeZone: row.departureTimeZone || zone,
      arrivalTimeZone: row.arrivalTimeZone || zone,
      currency: currencies(row, currency),
    })
  }
  return (
    <section className="space-y-5">
      <div className="planner-toolbar">
        <select
          className="planner-select !w-auto"
          aria-label={r('nav.transport')}
          value={view}
          onChange={(e) => setView(e.target.value as typeof view)}
        >
          <option value="flight">{r('nav.flights')}</option>
          <option value="ground">{r('nav.transport')}</option>
          <option value="hotel">{r('nav.hotels')}</option>
        </select>
        <div className="flex flex-wrap gap-2">
          {view === 'flight' && (
            <Button
              variant="outline"
              disabled={disabled}
              onClick={() =>
                setJourney({
                  ref: crypto.randomUUID(),
                  name: '',
                  ticketType: 'single',
                })
              }
            >
              {r('fl.addJourney')}
            </Button>
          )}
          {view === 'hotel' && (
            <Button
              variant="outline"
              disabled={disabled}
              onClick={() => void onSave(fillHotels(document, dates, currency))}
            >
              {r('ht.fromCity')}
            </Button>
          )}
          <Button disabled={disabled} onClick={create}>
            {r('c.add')}
          </Button>
        </div>
      </div>
      {view === 'flight' &&
        journeys.map((j) => {
          const detail = journeyDetails(document, text(j.ref), zone)
          return (
            <section
              className="space-y-2 border-b border-border pb-4"
              key={text(j.ref)}
            >
              <div className="flex items-center justify-between">
                <h4 className="font-semibold">
                  {text(j.name)} · {r('ticket.' + text(j.ticketType))}
                </h4>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={disabled}
                  onClick={() => setJourney(j)}
                >
                  {r('c.edit')}
                </Button>
              </div>
              <p className="text-sm">
                {r('fl.journeyTotal')}: {detail.duration ?? '—'} min
              </p>
              {detail.connections.map((c, i) => (
                <p
                  key={i}
                  className={`text-sm ${c.minutes != null && c.minutes < 0 ? 'text-bad' : 'text-ink-2'}`}
                >
                  {r('fl.layover', {
                    at: text(c.from.arrivalAirport) || '—',
                    d: c.minutes == null ? '—' : `${c.minutes} min`,
                  })}
                  {c.airportChange ? ` · ${r('conn.airport_change')}` : ''}
                </p>
              ))}
            </section>
          )
        })}
      {view === 'hotel' && (
        <div className="hotel-coverage" aria-label={r('ht.coverage')}>
          {hotelCoverage(document, dates).map((night) => (
            <div
              key={night.date}
              className={night.hotels.length !== 1 ? 'coverage-warning' : ''}
            >
              <strong>{night.date}</strong>
              <span>{night.city}</span>
              <span>
                {night.hotels.map((h) => text(h.title)).join(' + ') ||
                  r('ht.missing')}
              </span>
            </div>
          ))}
        </div>
      )}
      <div className="planner-list">
        {rows.map((row) => (
          <article className="planner-row" key={text(row.ref)}>
            <div className="min-w-0 flex-1">
              <h4 className="font-medium">{text(row.title)}</h4>
              <p className="mt-1 text-sm text-ink-2">
                {text(row.date)} {text(row.start)} →{' '}
                {text(row.endDate) || text(row.date)} {text(row.end)} ·{' '}
                {r(
                  row.bookingStatus === 'confirmed'
                    ? 'cs.confirmed'
                    : 'status.' +
                        (row.bookingStatus === 'notBooked'
                          ? 'planning'
                          : text(row.bookingStatus) || 'planning'),
                )}
              </p>
              <p className="mt-1 text-sm">
                {formatMoney(num(row.cost), currencies(row, currency))}
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={disabled}
                  onClick={() => edit(row)}
                >
                  {r('c.edit')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={disabled}
                  onClick={() => onEdit(document.activities.indexOf(row))}
                >
                  {r('nav.map')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={disabled}
                  onClick={() =>
                    setEditor({
                      ...row,
                      ref: crypto.randomUUID(),
                      bookingReference: undefined,
                      bookingStatus: 'notBooked',
                      isPaid: false,
                      isLocked: false,
                    })
                  }
                >
                  {r('c.duplicate')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  disabled={disabled}
                  onClick={() => setPending(row)}
                >
                  {r('c.delete')}
                </Button>
              </div>
            </div>
          </article>
        ))}
      </div>
      {editor && (
        <RecordForm
          title={r(
            view === 'hotel'
              ? 'nav.hotels'
              : view === 'flight'
                ? 'nav.flights'
                : 'nav.transport',
          )}
          row={editor}
          fields={view === 'hotel' ? hotelFields : travelFields}
          disabled={disabled}
          onClose={() => setEditor(undefined)}
          onSave={saveBooking}
        />
      )}
      {journey && (
        <RecordForm
          title={r('fl.journey')}
          row={journey}
          fields={[
            { key: 'name', label: 'fl.journeyName', required: true },
            {
              key: 'ticketType',
              label: 'fl.ticketType',
              type: 'select',
              options: ['single', 'separate', 'self_transfer'].map((v) => [
                v,
                'ticket.' + v,
              ]),
            },
            { key: 'notes', label: 'c.notes', type: 'textarea' },
          ]}
          disabled={disabled}
          onClose={() => setJourney(undefined)}
          onSave={(row) => onSave(upsert(document, 'journeys', row))}
        />
      )}
      {pending && (
        <Confirm
          title={r('c.delete')}
          description={text(pending.title) + ' · ' + r('fl.confirmBooked')}
          disabled={disabled}
          onClose={() => setPending(undefined)}
          onConfirm={() =>
            onSave({
              ...document,
              activities: document.activities.filter(
                (row) => row.ref !== pending.ref,
              ),
            })
          }
        />
      )}
    </section>
  )
}
