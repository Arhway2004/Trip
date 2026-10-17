import { useState } from 'react'
import { Button } from '#/components/ui/button'
import type { PlanDocument } from '../model'
import { text } from '../model'
import { exportPlan, getPlan } from '../../plan.functions'
import { listTrips } from '../../trips.functions'
import { r } from './copy'
import {
  aiMarkdown,
  csv,
  csvZip,
  datasets,
  download,
  excel,
  pdfReport,
  printReport,
  scrub,
} from './reports'

export function ReportTools({
  tripId,
  title,
  document,
  dates,
  currency,
  limit,
  travelers,
}: {
  tripId: string
  title: string
  document: PlanDocument
  dates: Array<string>
  currency: string
  limit: number
  travelers: number
}) {
  const [privacy, setPrivacy] = useState({
      excludeRefs: true,
      excludeNotes: false,
    }),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [csvName, setCsvName] = useState('Itinerary')
  const doc = scrub(document, privacy),
    data = datasets(doc, currency, limit, dates, travelers)
  const run = async (task: () => unknown | Promise<unknown>) => {
    setBusy(true)
    setError('')
    try {
      await task()
    } catch {
      setError(r('c.saveError', { e: '' }))
    } finally {
      setBusy(false)
    }
  }
  return (
    <section className="space-y-6">
      <h3 className="text-lg font-semibold">{r('nav.export')}</h3>
      <fieldset className="space-y-3">
        <legend className="mb-3 font-medium">{r('ex.privacy')}</legend>
        <label className="flex gap-2 text-sm">
          <input
            type="checkbox"
            checked={privacy.excludeRefs}
            onChange={(e) =>
              setPrivacy((old) => ({ ...old, excludeRefs: e.target.checked }))
            }
          />
          {r('ex.excludeRefs')}
        </label>
        <label className="flex gap-2 text-sm">
          <input
            type="checkbox"
            checked={privacy.excludeNotes}
            onChange={(e) =>
              setPrivacy((old) => ({ ...old, excludeNotes: e.target.checked }))
            }
          />
          {r('ex.excludeNotes')}
        </label>
      </fieldset>
      <div className="reference-export-actions">
        <Button
          variant="outline"
          disabled={busy}
          onClick={() =>
            download(
              'wanderplan-trip.json',
              JSON.stringify(doc, null, 2),
              'application/json',
            )
          }
        >
          {r('ex.json')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => void run(() => excel(data, 'wanderplan-report.xlsx'))}
        >
          {r('ex.excel')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => void run(() => pdfReport(title, data))}
        >
          {r('ex.pdf')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => void run(() => printReport(title, data))}
        >
          {r('ex.print')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => void run(() => csvZip(data, 'wanderplan-csv.zip'))}
        >
          {r('ex.csvZip')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() =>
            download(
              'wanderplan-analysis.md',
              aiMarkdown(title, doc),
              'text/markdown',
            )
          }
        >
          {r('ex.chatgpt')}
        </Button>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() =>
            download(
              'wanderplan-analysis.json',
              JSON.stringify(
                {
                  format: 'wanderplan.trip',
                  schemaVersion: 3,
                  ...doc,
                  analysis: data.Checks,
                },
                null,
                2,
              ),
              'application/json',
            )
          }
        >
          JSON · {r('ex.chatgpt')}
        </Button>
      </div>
      <div className="flex flex-wrap items-end gap-3">
        <label className="text-sm">
          {r('ex.csv')}
          <select
            className="planner-select"
            value={csvName}
            onChange={(e) => setCsvName(e.target.value)}
          >
            {Object.keys(data).map((name) => (
              <option key={name}>{name}</option>
            ))}
          </select>
        </label>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() =>
            download(
              csvName + '.csv',
              csv(data[csvName as keyof typeof data]),
              'text/csv;charset=utf-8',
            )
          }
        >
          {r('ex.csv')}
        </Button>
      </div>
      <hr className="border-border" />
      <h4 className="font-semibold">{r('ex.backup')}</h4>
      <p className="text-sm text-ink-2">{r('ex.backupHint')}</p>
      <Button
        disabled={busy}
        onClick={() =>
          void run(async () => {
            const result = await exportPlan({ data: { tripId } })
            if (!result.ok) throw new Error('backup unavailable')
            const bytes = Uint8Array.from(atob(result.data.base64), (c) =>
              c.charCodeAt(0),
            )
            download('wanderplan-full-backup.wanderplan', new Blob([bytes]))
          })
        }
      >
        {r('ex.backup')}
      </Button>
      <Button
        variant="outline"
        disabled={busy}
        onClick={() =>
          void run(async () => {
            const trips = await listTrips({ data: { includeArchived: true } })
            if (!trips.ok) throw new Error('backup unavailable')
            const entries = []
            let size = 0
            for (const trip of trips.data) {
              const plan = await getPlan({ data: { tripId: trip.id } })
              if (!plan.ok) throw new Error('backup unavailable')
              size +=
                plan.data.documentJson.length +
                Object.values(plan.data.media).reduce(
                  (sum, bytes) => sum + bytes.length,
                  0,
                )
              if (size > 95 * 1024 * 1024) throw new Error('backup too large')
              entries.push({
                document: JSON.parse(plan.data.documentJson) as PlanDocument,
                media: plan.data.media,
              })
            }
            download(
              'wanderplan-all-trips-backup.json',
              JSON.stringify({
                format: 'wanderplan.backup',
                schemaVersion: 1,
                trips: entries,
              }),
              'application/json',
            )
          })
        }
      >
        {r('ex.backupAll')}
      </Button>
      <p className="text-xs text-ink-2">
        {r('ex.privacy')} · {r('ex.backupPrivate')}
      </p>
      {busy && (
        <p role="status" className="text-sm text-ink-2">
          {r('ex.generating')}
        </p>
      )}
      {error && (
        <p role="alert" className="text-sm text-bad">
          {error}
        </p>
      )}
      <details>
        <summary>{r('ex.preview')}</summary>
        <div className="reference-table mt-4">
          <table>
            <caption>{text(title)}</caption>
            <thead>
              <tr>
                {data.Itinerary[0].slice(0, 7).map((label) => (
                  <th key={String(label)}>{String(label)}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.Itinerary.slice(1).map((row, i) => (
                <tr key={i}>
                  {row.slice(0, 7).map((cell, j) => (
                    <td key={j}>{String(cell)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </details>
    </section>
  )
}
