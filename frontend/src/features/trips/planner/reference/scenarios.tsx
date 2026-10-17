import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { formatMoney } from '#/lib/format'
import { records, text } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { r } from './copy'
import {
  object,
  planMetrics,
  scenarioSnapshot,
  switchScenario,
  upsert,
  dateRange,
} from './domain'
import { RecordForm } from './record-form'
import { Confirm } from './confirm'

export function Scenarios({
  document,
  dates,
  currency,
  travelers,
  disabled,
  onSave,
}: {
  document: PlanDocument
  dates: Array<string>
  currency: string
  travelers: number
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
}) {
  const [editor, setEditor] = useState<PlanRow>(),
    [pending, setPending] = useState<string>()
  const scenarios = records(document.scenarios),
    active = text(document.activeScenarioRef)
  function initialize(doc: PlanDocument) {
    if (records(doc.scenarios).length) return doc
    const ref = crypto.randomUUID()
    return {
      ...doc,
      activeScenarioRef: ref,
      scenarios: [
        { ref, name: r('nav.itinerary'), snapshot: scenarioSnapshot(doc) },
      ],
    }
  }
  async function add(blank: boolean) {
    const next = initialize(document),
      ref = crypto.randomUUID()
    const snapshot = blank
      ? {
          ...scenarioSnapshot(document),
          activities: [],
          expenses: [],
          dayPlans: [],
          journeys: [],
          connections: [],
          selectedPlaceRefs: [],
        }
      : scenarioSnapshot(document)
    next.scenarios = [
      ...records(next.scenarios),
      {
        ref,
        name: blank
          ? r('sc.new')
          : r('c.duplicate') + ' · ' + r('nav.itinerary'),
        snapshot,
      },
    ]
    return onSave(switchScenario(next, ref))
  }
  const rows = scenarios.map((scenario) => {
    const snapshot =
      scenario.ref === active
        ? document
        : ({ ...document, ...object(scenario.snapshot) } as PlanDocument)
    const range =
      text(snapshot.planningStartDate) && text(snapshot.planningEndDate)
        ? dateRange(
            text(snapshot.planningStartDate),
            text(snapshot.planningEndDate),
          )
        : dates
    return {
      scenario,
      metrics: planMetrics(snapshot, range, currency, travelers),
    }
  })
  return (
    <section className="space-y-5">
      <div className="planner-toolbar">
        <h3 className="text-lg font-semibold">{r('sc.compare')}</h3>
        <div className="flex gap-2">
          <Button
            variant="outline"
            disabled={disabled}
            onClick={() => void add(true)}
          >
            {r('sc.new')}
          </Button>
          <Button disabled={disabled} onClick={() => void add(false)}>
            {r('c.duplicate')}
          </Button>
        </div>
      </div>
      <div className="reference-table">
        <table>
          <thead>
            <tr>
              <th>{r('c.name')}</th>
              <th>{r('sc.cost')}</th>
              <th>{r('sc.transportHours')}</th>
              <th>{r('sc.highFatigue')}</th>
              <th>{r('sc.freeHours')}</th>
              <th>{r('sc.issues')}</th>
              <th>{r('c.edit')}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(({ scenario, metrics }) => (
              <tr key={text(scenario.ref)}>
                <th scope="row">
                  {text(scenario.name)}
                  {scenario.ref === active ? ' ✓' : ''}
                </th>
                <td>{formatMoney(metrics.planned, currency)}</td>
                <td>{metrics.transportHours.toFixed(1)}</td>
                <td>{metrics.highFatigueDays}</td>
                <td>{metrics.freeHours.toFixed(1)}</td>
                <td>{metrics.issues}</td>
                <td>
                  <div className="flex flex-wrap gap-1">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={disabled || scenario.ref === active}
                      onClick={() =>
                        void onSave(
                          switchScenario(document, text(scenario.ref)),
                        )
                      }
                    >
                      {r('sc.use')}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={disabled}
                      onClick={() => setEditor(scenario)}
                    >
                      {r('c.edit')}
                    </Button>
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={disabled || scenarios.length <= 1}
                      onClick={() => setPending(text(scenario.ref))}
                    >
                      {r('c.delete')}
                    </Button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {editor && (
        <RecordForm
          title={r('nav.scenarios')}
          row={editor}
          fields={[
            { key: 'name', label: 'c.name', required: true },
            { key: 'notes', label: 'c.notes', type: 'textarea' },
          ]}
          disabled={disabled}
          onClose={() => setEditor(undefined)}
          onSave={(row) => onSave(upsert(document, 'scenarios', row))}
        />
      )}
      {pending && (
        <Confirm
          title={r('c.delete')}
          description={
            r('nav.scenarios') +
            ' · ' +
            text(scenarios.find((s) => s.ref === pending)?.name)
          }
          disabled={disabled}
          onClose={() => setPending(undefined)}
          onConfirm={() => {
            let next =
              pending === active
                ? switchScenario(
                    document,
                    text(scenarios.find((s) => s.ref !== pending)?.ref),
                  )
                : document
            next = {
              ...next,
              scenarios: records(next.scenarios).filter(
                (s) => s.ref !== pending,
              ),
            }
            return onSave(next)
          }}
        />
      )}
    </section>
  )
}
