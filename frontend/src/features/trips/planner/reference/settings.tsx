import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import type { PlanDocument, PlanRow } from '../model'
import { records, text } from '../model'
import { fetchExchangeRate } from '../../maps.functions'
import { r } from './copy'
import { object, upsert } from './domain'
import { RecordForm } from './record-form'

export function PlanningSettings({
  tripId,
  document,
  currency,
  disabled,
  onSave,
}: {
  tripId: string
  document: PlanDocument
  currency: string
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
}) {
  const [from, setFrom] = useState(currency === 'CNY' ? 'THB' : 'CNY'),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [editor, setEditor] = useState<{ section: string; row: PlanRow }>()
  return (
    <section className="space-y-6">
      <h3 className="text-lg font-semibold">{r('nav.settings')}</h3>
      <label className="block max-w-xs text-sm">
        {r('set.display')}
        <select
          className="planner-select w-full"
          disabled={disabled}
          value={text(object(document.preferences).displayCurrency) || currency}
          onChange={(e) =>
            void onSave({
              ...document,
              preferences: {
                ...object(document.preferences),
                displayCurrency: e.target.value,
              },
            })
          }
        >
          {[
            ...new Set([
              currency,
              ...document.exchangeRates.map((row) => text(row.currency)),
            ]),
          ]
            .filter(Boolean)
            .map((code) => (
              <option key={code}>{code}</option>
            ))}
        </select>
      </label>
      <h4 className="font-semibold">{r('set.rate')}</h4>
      <div className="flex flex-wrap items-end gap-3">
        <label className="text-sm">
          {r('c.from')}
          <Input
            className="max-w-36"
            value={from}
            maxLength={3}
            disabled={disabled || busy}
            onChange={(e) => setFrom(e.target.value.toUpperCase())}
          />
        </label>
        <span className="pb-2">→ {currency}</span>
        <Button
          variant="outline"
          disabled={
            disabled || busy || from === currency || !/^[A-Z]{3}$/.test(from)
          }
          onClick={async () => {
            setBusy(true)
            setError('')
            try {
              const result = await fetchExchangeRate({
                data: { tripId, from, to: currency },
              })
              if (!result.ok) {
                setError(r('set.rateFail', { e: '' }))
                return
              }
              const row = { currency: from, ...result.data },
                next = {
                  ...document,
                  exchangeRates: [
                    ...document.exchangeRates.filter(
                      (rate) => rate.currency !== from,
                    ),
                    row,
                  ],
                }
              await onSave(next)
            } catch {
              setError(r('set.rateFail', { e: '' }))
            } finally {
              setBusy(false)
            }
          }}
        >
          {busy ? r('c.loading') : r('set.fetchRate')}
        </Button>
      </div>
      <ul className="space-y-2 text-sm">
        {document.exchangeRates.map((rate) => (
          <li key={text(rate.currency)}>
            1 {text(rate.currency)} = {text(rate.rate)} {currency} ·{' '}
            {text(rate.source) || r('cs.user')} {text(rate.date)}
          </li>
        ))}
      </ul>
      {error && (
        <p role="alert" className="text-sm text-warn">
          {error}
        </p>
      )}
      <div className="planner-toolbar">
        <h4 className="font-semibold">{r('set.cities')}</h4>
        <Button
          variant="outline"
          disabled={disabled}
          onClick={() =>
            setEditor({
              section: 'destinations',
              row: {
                ref: crypto.randomUUID(),
                city: '',
                country: '',
                timeZone: 'Asia/Shanghai',
              },
            })
          }
        >
          {r('set.addCity')}
        </Button>
      </div>
      <div className="planner-list">
        {document.destinations.map((row, index) => (
          <article className="planner-row" key={text(row.ref) || index}>
            <div className="flex-1">
              <strong>{text(row.city)}</strong>
              <p className="text-sm text-ink-2">
                {text(row.country)} · {text(row.timeZone)} ·{' '}
                {text(row.altitude)}
              </p>
            </div>
            <Button
              variant="ghost"
              disabled={disabled}
              onClick={() =>
                setEditor({
                  section: 'destinations',
                  row: { ...row, ref: row.ref || `city-${index}` },
                })
              }
            >
              {r('c.edit')}
            </Button>
          </article>
        ))}
      </div>
      <h4 className="font-semibold">{r('set.places')}</h4>
      <p className="text-sm text-ink-2">
        {r('tr.fromPlace')} / {r('tr.toPlace')}
      </p>
      <div className="planner-list">
        {document.places
          .filter((p) =>
            [
              'airport',
              'railwayStation',
              'busStation',
              'ferryTerminal',
            ].includes(text(p.category)),
          )
          .map((row, index) => (
            <article className="planner-row" key={text(row.ref) || index}>
              <strong className="flex-1">{text(row.name)}</strong>
              <Button
                variant="ghost"
                disabled={disabled}
                onClick={() =>
                  setEditor({
                    section: 'places',
                    row: { ...row, ref: row.ref || `place-${index}` },
                  })
                }
              >
                {r('c.edit')}
              </Button>
            </article>
          ))}
      </div>
      <Button
        variant="outline"
        disabled={disabled}
        onClick={() =>
          setEditor({
            section: 'places',
            row: {
              ref: crypto.randomUUID(),
              name: '',
              category: 'railwayStation',
            },
          })
        }
      >
        {r('set.addPlace')}
      </Button>
      {editor && (
        <RecordForm
          title={r(editor.section === 'places' ? 'set.places' : 'set.cities')}
          row={editor.row}
          fields={
            editor.section === 'destinations'
              ? [
                  { key: 'city', label: 'c.city', required: true },
                  { key: 'country', label: 'c.name' },
                  { key: 'nameZh', label: 'att.nameZh' },
                  { key: 'nameTh', label: 'att.nameTh' },
                  {
                    key: 'lat',
                    label: 'att.lat',
                    type: 'number',
                    min: -90,
                    max: 90,
                  },
                  {
                    key: 'lng',
                    label: 'att.lng',
                    type: 'number',
                    min: -180,
                    max: 180,
                  },
                  { key: 'altitude', label: 'att.altitude', type: 'number' },
                  { key: 'timeZone', label: 'set.tz' },
                ]
              : [
                  { key: 'name', label: 'c.name', required: true },
                  {
                    key: 'category',
                    label: 'c.type',
                    type: 'select',
                    options: [
                      ['airport', 'place.airport'],
                      ['railwayStation', 'place.station'],
                      ['busStation', 'place.bus'],
                      ['ferryTerminal', 'place.ferry'],
                    ],
                  },
                  { key: 'city', label: 'c.city' },
                  { key: 'iata', label: 'fl.iata' },
                  { key: 'timeZone', label: 'set.tz' },
                  {
                    key: 'transferMinutes',
                    label: 'set.transfer',
                    type: 'number',
                    min: 0,
                  },
                  {
                    key: 'lat',
                    label: 'att.lat',
                    type: 'number',
                    min: -90,
                    max: 90,
                  },
                  {
                    key: 'lng',
                    label: 'att.lng',
                    type: 'number',
                    min: -180,
                    max: 180,
                  },
                  { key: 'notes', label: 'c.notes', type: 'textarea' },
                ]
          }
          disabled={disabled}
          onClose={() => setEditor(undefined)}
          onSave={(row) => {
            if (row.timeZone) {
              try {
                new Intl.DateTimeFormat('en', { timeZone: text(row.timeZone) })
              } catch {
                return Promise.resolve(false)
              }
            }
            let next = document
            if (
              editor.section === 'destinations' &&
              text(row.ref).startsWith('city-')
            ) {
              const index = Number(text(row.ref).slice(5))
              next = {
                ...document,
                destinations: document.destinations.map((old, i) =>
                  i === index ? row : old,
                ),
              }
              return onSave(next)
            }
            return onSave(upsert(document, editor.section, row))
          }}
        />
      )}
      <details>
        <summary>{r('set.tests')}</summary>
        <p className="mt-3 text-sm text-ink-2">
          {r('dash.issues')}: {records(document.connections).length} ·{' '}
          {r('nav.itinerary')}: {document.activities.length}
        </p>
        <pre className="mt-3 overflow-auto text-xs">
          npm test · npm run typecheck · npm run build
        </pre>
      </details>
    </section>
  )
}
