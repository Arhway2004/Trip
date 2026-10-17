import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import type { PlanDocument, PlanRow } from '../model'
import { text } from '../model'
import { PlaceSearch } from '../place-search'
import { r } from './copy'
import {
  addPlaceVisit,
  libraryCosts,
  libraryRows,
  removeRecord,
  upsert,
} from './domain'
import { RecordForm } from './record-form'
import type { Field } from './record-form'

const choices = (prefix: string, values: Array<string>) =>
  values.map((v): [string, string] => [v, `${prefix}.${v}`])
const fields: Array<Field> = [
  { key: 'name', label: 'c.name', required: true },
  { key: 'nameEn', label: 'att.nameEn' },
  { key: 'nameTh', label: 'att.nameTh' },
  { key: 'city', label: 'c.city' },
  {
    key: 'attractionCategory',
    label: 'c.category',
    type: 'select',
    options: choices('cat', [
      'scenic',
      'nature',
      'park',
      'historic',
      'temple',
      'culture',
      'shopping',
      'food',
      'experience',
      'other',
    ]),
  },
  {
    key: 'priority',
    label: 'c.priority',
    type: 'select',
    options: choices('priority', ['must', 'interested', 'optional', 'skip']),
  },
  { key: 'description', label: 'c.description', type: 'textarea' },
  { key: 'address', label: 'c.address' },
  { key: 'lat', label: 'att.lat', type: 'number', min: -90, max: 90 },
  { key: 'lng', label: 'att.lng', type: 'number', min: -180, max: 180 },
  {
    key: 'verification',
    label: 'c.verification',
    type: 'select',
    options: choices('verif', ['verified', 'user', 'estimated', 'needs']),
  },
  { key: 'ticketPrice', label: 'att.ticket', type: 'number', min: 0 },
  { key: 'ticketCurrency', label: 'c.currency', required: true },
  { key: 'sharedTicketKey', label: 'att.sharedTicket' },
  { key: 'transportCost', label: 'att.transport', type: 'number', min: 0 },
  { key: 'transportCurrency', label: 'c.currency' },
  { key: 'sharedTransportKey', label: 'att.sharedTransport' },
  {
    key: 'durationMinutes',
    label: 'att.duration',
    type: 'number',
    min: 5,
    max: 1440,
  },
  { key: 'openingHours', label: 'att.hours' },
  { key: 'recommendedTime', label: 'att.recTime' },
  { key: 'seasonalClosures', label: 'att.seasonal' },
  { key: 'reservation', label: 'att.reservation' },
  { key: 'reservationRequired', label: 'att.resRequired', type: 'checkbox' },
  {
    key: 'walking',
    label: 'att.walking',
    type: 'select',
    options: choices('walk', ['low', 'medium', 'high']),
  },
  {
    key: 'altitude',
    label: 'att.altitude',
    type: 'number',
    min: -500,
    max: 9000,
  },
  { key: 'transportOptions', label: 'att.transportOptions', type: 'textarea' },
  { key: 'winterNotes', label: 'att.winter', type: 'textarea' },
  { key: 'url', label: 'att.url', type: 'url' },
  { key: 'lastVerified', label: 'att.lastVerified', type: 'date' },
  { key: 'notes', label: 'c.notes', type: 'textarea' },
]
export function AttractionLibrary({
  tripId,
  document,
  disabled,
  currency,
  travelers,
  date,
  onSave,
}: {
  tripId: string
  document: PlanDocument
  disabled: boolean
  currency: string
  travelers: number
  date: string
  onSave: (doc: PlanDocument) => Promise<boolean>
}) {
  const [query, setQuery] = useState(''),
    [city, setCity] = useState(''),
    [priority, setPriority] = useState(''),
    [selectedOnly, setSelectedOnly] = useState(false),
    [editor, setEditor] = useState<PlanRow>(),
    [visitDate, setVisitDate] = useState(date),
    [error, setError] = useState('')
  const places = libraryRows(document)
  const save = (next: PlanDocument) => onSave(libraryCosts(next, travelers))
  return (
    <section className="space-y-5">
      <div className="planner-toolbar">
        <h3 className="text-lg font-semibold">{r('nav.attractions')}</h3>
        <Button
          disabled={disabled}
          onClick={() =>
            setEditor({
              ref: crypto.randomUUID(),
              name: '',
              category: 'attraction',
              ticketCurrency: currency,
              transportCurrency: currency,
              priority: 'interested',
              walking: 'medium',
              durationMinutes: 60,
            })
          }
        >
          {r('att.add')}
        </Button>
      </div>
      <div className="grid gap-3 sm:grid-cols-3">
        <label className="text-sm">
          {r('c.search')}
          <Input value={query} onChange={(e) => setQuery(e.target.value)} />
        </label>
        <label className="text-sm">
          {r('c.city')}
          <select
            className="planner-select w-full"
            value={city}
            onChange={(e) => setCity(e.target.value)}
          >
            <option value="">{r('c.all')}</option>
            {[...new Set(places.map((p) => text(p.city)))]
              .filter(Boolean)
              .map((c) => (
                <option key={c}>{c}</option>
              ))}
          </select>
        </label>
        <label className="text-sm">
          {r('c.priority')}
          <select
            className="planner-select w-full"
            value={priority}
            onChange={(e) => setPriority(e.target.value)}
          >
            <option value="">{r('c.all')}</option>
            {choices('priority', [
              'must',
              'interested',
              'optional',
              'skip',
            ]).map(([v, label]) => (
              <option key={v} value={v}>
                {r(label)}
              </option>
            ))}
          </select>
        </label>
      </div>
      <label className="flex gap-2 text-sm">
        <input
          type="checkbox"
          checked={selectedOnly}
          onChange={(e) => setSelectedOnly(e.target.checked)}
        />
        {r('dash.selected')}
      </label>
      <label className="block max-w-xs text-sm">
        {r('c.date')}
        <Input
          type="date"
          value={visitDate}
          onChange={(e) => setVisitDate(e.target.value)}
        />
      </label>
      <div className="planner-list">
        {places
          .filter(
            (p) =>
              (!city || p.city === city) &&
              (!priority || p.priority === priority) &&
              (!selectedOnly || p.selected) &&
              [p.name, p.nameEn, p.nameTh, p.description]
                .join(' ')
                .toLowerCase()
                .includes(query.toLowerCase()),
          )
          .map((place, index) => (
            <article className="planner-row" key={text(place.ref) || index}>
              <div className="min-w-0 flex-1">
                <label className="flex gap-3 font-medium">
                  <input
                    type="checkbox"
                    disabled={disabled}
                    checked={place.selected === true}
                    onChange={(e) =>
                      void save(
                        upsert(document, 'attractions', {
                          ...place,
                          selected: e.target.checked,
                        }),
                      )
                    }
                  />
                  {text(place.name)}
                </label>
                <p className="mt-2 text-sm text-ink-2">
                  {text(place.city)} ·{' '}
                  {r('priority.' + (text(place.priority) || 'interested'))} ·{' '}
                  {text(place.durationMinutes) || '60'} min
                </p>
                <p className="mt-2 text-sm text-ink-2">
                  {text(place.description)}
                </p>
                {Boolean(place.openingHours) && (
                  <p className="mt-2 text-sm">
                    {r('att.hours')}: {text(place.openingHours)}
                  </p>
                )}
                <div className="mt-3 flex flex-wrap gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    disabled={disabled || !visitDate}
                    onClick={() =>
                      void onSave(
                        addPlaceVisit(document, place, visitDate, travelers),
                      )
                    }
                  >
                    {r('att.addToDay')}
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={disabled}
                    onClick={() => setEditor(place)}
                  >
                    {r('c.edit')}
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={disabled}
                    onClick={() => {
                      if (
                        document.activities.some(
                          (a) => a.placeRef === place.ref,
                        )
                      ) {
                        setError(
                          r('att.deleteConfirm', { n: text(place.name) }),
                        )
                        setEditor(place)
                      } else
                        void save({
                          ...removeRecord(
                            document,
                            'attractions',
                            text(place.ref),
                          ),
                          places: document.places.filter(
                            (p) => p.ref !== place.ref,
                          ),
                        })
                    }}
                  >
                    {r('c.delete')}
                  </Button>
                </div>
              </div>
            </article>
          ))}
      </div>
      {error && (
        <p role="status" className="text-sm text-warn">
          {error}
        </p>
      )}
      {editor && (
        <RecordForm
          title={r('att.edit')}
          row={editor}
          fields={fields}
          disabled={disabled}
          onClose={() => setEditor(undefined)}
          onSave={async (row) => {
            if (
              !/^[A-Z]{3}$/.test(text(row.ticketCurrency)) ||
              (row.transportCurrency &&
                !/^[A-Z]{3}$/.test(text(row.transportCurrency)))
            )
              return false
            return save(upsert(document, 'attractions', row))
          }}
          extra={(_draft, change) => (
            <PlaceSearch
              tripId={tripId}
              disabled={disabled}
              onChoose={(place) =>
                change({
                  ...place,
                  verification: 'verified',
                  lastVerified: new Date().toISOString().slice(0, 10),
                })
              }
            />
          )}
        />
      )}
    </section>
  )
}
