import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { formatMoney } from '#/lib/format'
import { text, records } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { r } from './copy'
import { num, planMetrics, hotelCoverage, upsert } from './domain'
import { budgetReport } from './budget'
import { RecordForm } from './record-form'

export function Insights({
  document,
  dates,
  currency,
  travelers,
}: {
  document: PlanDocument
  dates: Array<string>
  currency: string
  travelers: number
}) {
  const metrics = planMetrics(document, dates, currency, travelers),
    coverage = hotelCoverage(document, dates)
  return (
    <section className="space-y-6">
      <h3 className="text-lg font-semibold">{r('dash.issues')}</h3>
      <dl className="reference-metrics">
        <div>
          <dt>{r('sc.transportHours')}</dt>
          <dd>{metrics.transportHours.toFixed(1)}</dd>
        </div>
        <div>
          <dt>{r('sc.freeHours')}</dt>
          <dd>{metrics.freeHours.toFixed(1)}</dd>
        </div>
        <div>
          <dt>{r('sc.hotelChanges')}</dt>
          <dd>{metrics.hotelChanges}</dd>
        </div>
        <div>
          <dt>{r('sc.issues')}</dt>
          <dd>{metrics.issues}</dd>
        </div>
      </dl>
      <div className="reference-table">
        <table>
          <caption>{r('dash.fatigue')}</caption>
          <thead>
            <tr>
              <th>{r('c.date')}</th>
              <th>{r('sc.avgFatigue')}</th>
              <th>{r('sc.freeHours')}</th>
              <th>{r('dash.issues')}</th>
            </tr>
          </thead>
          <tbody>
            {metrics.days.map((day) => (
              <tr key={day.date}>
                <th scope="row">{day.date}</th>
                <td>{day.score}/10</td>
                <td>{(day.free / 60).toFixed(1)}</td>
                <td>
                  {day.check.overlaps.length > 0 && (
                    <p className="text-bad">
                      {r('w.activityOverlap', { a: '', b: '' })}
                    </p>
                  )}
                  {day.check.transfers
                    .filter((t) => t.remaining != null && t.remaining < 0)
                    .map((t, i) => (
                      <p className="text-bad" key={i}>
                        {text(t.from.row.title)} → {text(t.to.row.title)} ·{' '}
                        {Math.abs(t.remaining!)} min
                      </p>
                    ))}
                  {day.check.untimed.length > 0 && (
                    <p>
                      {day.check.untimed.length} · {r('c.time')}
                    </p>
                  )}
                  {day.early && <p>{r('fz.early', { t: '07:00' })}</p>}
                  {day.late && <p>{r('fz.late', { t: '22:00' })}</p>}
                  {day.score >= 7 && (
                    <p>
                      {r('fs.moveAttraction')} · {r('fs.addRest')}
                    </p>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <p className="text-xs text-ink-2">{r('fz.note')}</p>
      <h4 className="font-semibold">{r('ht.coverage')}</h4>
      <ul className="space-y-2 text-sm">
        {coverage
          .filter(
            (day) =>
              day.hotels.length !== 1 ||
              (day.city &&
                day.hotels.some((h) => h.city && h.city !== day.city)),
          )
          .map((day) => (
            <li key={day.date}>
              {day.date} ·{' '}
              {day.hotels.length === 0
                ? r('ht.missing')
                : day.hotels.map((h) => text(h.title)).join(' + ')}{' '}
              · {day.city}
            </li>
          ))}
      </ul>
      <h4 className="font-semibold">{r('dash.upcoming')}</h4>
      <ul className="space-y-2 text-sm">
        {document.activities
          .filter(
            (a) =>
              ['flight', 'train', 'bus', 'hotel'].includes(text(a.kind)) &&
              a.bookingStatus !== 'cancelled',
          )
          .sort((a, b) =>
            (text(a.date) + text(a.start)).localeCompare(
              text(b.date) + text(b.start),
            ),
          )
          .slice(0, 10)
          .map((a) => (
            <li key={text(a.ref)}>
              {text(a.date)} {text(a.start)} · {text(a.title)} ·{' '}
              {r(
                a.bookingStatus === 'confirmed'
                  ? 'cs.confirmed'
                  : 'status.' +
                      (a.bookingStatus === 'notBooked'
                        ? 'planning'
                        : text(a.bookingStatus) || 'planning'),
              )}
            </li>
          ))}
      </ul>
    </section>
  )
}

function Bars({
  rows,
  currency,
}: {
  rows: Array<{ label: string; planned: number; actual: number }>
  currency: string
}) {
  const max = Math.max(1, ...rows.flatMap((row) => [row.planned, row.actual]))
  return (
    <div className="space-y-4">
      {rows.map((row) => (
        <div key={row.label}>
          <div className="mb-1 flex flex-wrap justify-between gap-2 text-sm">
            <span>{row.label}</span>
            <span>
              {formatMoney(row.planned, currency)} /{' '}
              {formatMoney(row.actual, currency)}
            </span>
          </div>
          <div className="budget-bar-pair" aria-hidden>
            <span style={{ width: `${(row.planned / max) * 100}%` }} />
            <span style={{ width: `${(row.actual / max) * 100}%` }} />
          </div>
        </div>
      ))}
    </div>
  )
}
export function BudgetAnalysis({
  document,
  currency,
  limit,
  disabled,
  onSave,
}: {
  document: PlanDocument
  currency: string
  limit: number
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
}) {
  const report = budgetReport(document, currency, limit),
    [group, setGroup] = useState<'date' | 'category' | 'city'>('date'),
    [line, setLine] = useState<PlanRow>(),
    [allowance, setAllowance] = useState<PlanRow>()
  return (
    <section className="space-y-6">
      <dl className="reference-metrics">
        {[
          ['bd.projected', report.forecast],
          ['bd.actual', report.actual],
          ['bd.paid', report.paid],
          ['bd.unpaid', report.unpaid],
          ['bd.remaining', report.remaining],
        ].map(([label, value]) => (
          <div key={label}>
            <dt>{r(String(label))}</dt>
            <dd>{formatMoney(Number(value), currency)}</dd>
          </div>
        ))}
      </dl>
      <p className="text-sm text-ink-2">{r('bd.explain')}</p>
      {report.missing.length > 0 && (
        <p role="status" className="text-sm text-warn">
          {r('c.currency')}: {report.missing.join(', ')}
        </p>
      )}
      <label className="block max-w-sm text-sm">
        {r('nav.budget')}
        <select
          className="planner-select w-full"
          value={group}
          onChange={(e) => setGroup(e.target.value as typeof group)}
        >
          <option value="date">{r('bd.byDay')}</option>
          <option value="category">{r('bd.byCategory')}</option>
          <option value="city">{r('bd.byCity')}</option>
        </select>
      </label>
      <p className="text-xs text-ink-2">
        {r('bd.chartPlanned')} / {r('bd.chartActual')}
      </p>
      <Bars rows={report.group(group)} currency={currency} />
      <div className="planner-toolbar">
        <h4 className="font-semibold">{r('bd.lines')}</h4>
        <Button
          variant="outline"
          disabled={disabled}
          onClick={() =>
            setLine({
              ref: crypto.randomUUID(),
              name: '',
              target: 0,
              categories: '',
              cities: '',
            })
          }
        >
          {r('bd.addLine')}
        </Button>
      </div>
      <div className="reference-table">
        <table>
          <thead>
            <tr>
              <th>{r('c.name')}</th>
              <th>{r('bd.target')}</th>
              <th>{r('bd.projected')}</th>
              <th>{r('bd.variance')}</th>
              <th>{r('c.edit')}</th>
            </tr>
          </thead>
          <tbody>
            {records(document.budgetLines).map((row) => {
              const forecast =
                report.group('line').find((g) => g.label === row.ref)
                  ?.forecast || 0
              return (
                <tr key={text(row.ref)}>
                  <th scope="row">{text(row.name)}</th>
                  <td>{formatMoney(num(row.target), currency)}</td>
                  <td>{formatMoney(forecast, currency)}</td>
                  <td className={forecast > num(row.target) ? 'text-bad' : ''}>
                    {formatMoney(num(row.target) - forecast, currency)}
                  </td>
                  <td>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={disabled}
                      onClick={() => setLine(row)}
                    >
                      {r('c.edit')}
                    </Button>
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <div className="planner-toolbar">
        <h4 className="font-semibold">{r('bd.allowances')}</h4>
        <Button
          variant="outline"
          disabled={disabled}
          onClick={() =>
            setAllowance({
              ref: crypto.randomUUID(),
              title: '',
              amount: 0,
              currency,
              kind: 'planned',
              isAllowance: true,
              isPaid: false,
            })
          }
        >
          {r('bd.addPlanned')}
        </Button>
      </div>
      <div className="planner-list">
        {document.expenses
          .filter((e) => e.isAllowance)
          .map((e) => (
            <article className="planner-row" key={text(e.ref)}>
              <div className="flex-1">
                <h5>{text(e.title)}</h5>
                <p className="text-sm text-ink-2">
                  {formatMoney(num(e.amount), text(e.currency) || currency)}
                </p>
              </div>
              <Button
                variant="ghost"
                disabled={disabled}
                onClick={() => setAllowance(e)}
              >
                {r('c.edit')}
              </Button>
            </article>
          ))}
      </div>
      {line && (
        <RecordForm
          title={r('bd.lines')}
          row={line}
          fields={[
            { key: 'name', label: 'c.name', required: true },
            { key: 'target', label: 'bd.target', type: 'number', min: 0 },
            { key: 'categories', label: 'bd.lineCats' },
            { key: 'cities', label: 'bd.lineCities' },
          ]}
          disabled={disabled}
          onClose={() => setLine(undefined)}
          onSave={(row) => onSave(upsert(document, 'budgetLines', row))}
        />
      )}
      {allowance && (
        <RecordForm
          title={r('bd.allowances')}
          row={allowance}
          fields={[
            { key: 'title', label: 'c.description', required: true },
            {
              key: 'amount',
              label: 'c.price',
              type: 'number',
              min: 0,
              required: true,
            },
            { key: 'currency', label: 'c.currency', required: true },
            { key: 'category', label: 'c.category' },
            { key: 'date', label: 'c.date', type: 'date' },
            { key: 'city', label: 'c.city' },
            {
              key: 'budgetLineRef',
              label: 'att.budgetLine',
              type: 'select',
              options: records(document.budgetLines).map((l) => [
                text(l.ref),
                text(l.name),
              ]),
            },
            { key: 'isAllowance', label: 'bd.allowance', type: 'checkbox' },
            { key: 'notes', label: 'c.notes', type: 'textarea' },
          ]}
          disabled={disabled}
          onClose={() => setAllowance(undefined)}
          onSave={(row) =>
            /^[A-Z]{3}$/.test(text(row.currency))
              ? onSave(upsert(document, 'expenses', row))
              : Promise.resolve(false)
          }
        />
      )}
    </section>
  )
}
