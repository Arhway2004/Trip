import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import type { PlanDocument, PlanRow } from '../model'
import { records, text } from '../model'
import { minute, timeLabel } from '../schedule'
import { r } from './copy'
import {
  cloneDay,
  dateRange,
  dayData,
  daysBetween,
  protectedBooking,
  shift,
  upsert,
} from './domain'
import { RecordForm } from './record-form'
import { Confirm } from './confirm'

export function PlanningCalendar({
  document,
  dates,
  disabled,
  currency,
  onSave,
  onEdit,
  onAdd,
}: {
  document: PlanDocument
  dates: Array<string>
  disabled: boolean
  currency: string
  onSave: (doc: PlanDocument) => Promise<boolean>
  onEdit: (index: number) => void
  onAdd: (date: string) => void
}) {
  const [view, setView] = useState<'week' | 'month'>('week'),
    [date, setDate] = useState(
      dates[0] || new Date().toISOString().slice(0, 10),
    ),
    [editor, setEditor] = useState<PlanRow>(),
    [duplicate, setDuplicate] = useState(false),
    [shiftDates, setShiftDates] = useState(false),
    [pending, setPending] = useState<{
      description: string
      next: PlanDocument
    }>()
  const monday = (d: string) =>
    shift(d, -((new Date(d + 'T00:00:00Z').getUTCDay() + 6) % 7))
  const first =
      view === 'week' ? monday(date) : monday(date.slice(0, 7) + '-01'),
    cells = dateRange(first, shift(first, view === 'week' ? 6 : 41))
  function move(row: PlanRow, to: string) {
    const delta = daysBetween(text(row.date), to),
      next = {
        ...document,
        activities: document.activities.map((a) =>
          a === row
            ? {
                ...a,
                date: to,
                endDate: a.endDate ? shift(text(a.endDate), delta) : undefined,
              }
            : a,
        ),
      }
    if (protectedBooking(row))
      setPending({ description: r('fl.confirmBooked'), next })
    else void onSave(next)
  }
  return (
    <section className="space-y-5">
      <div className="planner-toolbar">
        <div className="flex flex-wrap gap-2">
          <Button
            variant="outline"
            onClick={() => setDate(shift(date, view === 'week' ? -7 : -28))}
            aria-label={r('c.previous')}
          >
            ←
          </Button>
          <Input
            className="!w-auto"
            type="date"
            aria-label={r('c.date')}
            value={date}
            onChange={(e) => {
              if (e.target.value) setDate(e.target.value)
            }}
          />
          <Button
            variant="outline"
            onClick={() => setDate(shift(date, view === 'week' ? 7 : 28))}
            aria-label={r('c.next')}
          >
            →
          </Button>
          <select
            className="planner-select !w-auto"
            aria-label={r('nav.itinerary')}
            value={view}
            onChange={(e) => setView(e.target.value as typeof view)}
          >
            <option value="week">{r('it.week')}</option>
            <option value="month">{r('it.month')}</option>
          </select>
        </div>
        <Button
          variant="outline"
          disabled={disabled}
          onClick={() => setShiftDates(true)}
        >
          {r('dash.editDates')}
        </Button>
      </div>
      <p className="text-sm text-ink-2">{r('it.dragHint')}</p>
      <div className={`planning-calendar planning-calendar-${view}`}>
        {cells.map((day) => (
          <section
            key={day}
            className={`calendar-cell ${dates.includes(day) ? '' : 'calendar-outside'}`}
            aria-label={day}
            onDragOver={(e) => {
              if (!disabled) e.preventDefault()
            }}
            onDrop={(e) => {
              e.preventDefault()
              if (disabled) return
              const ref = e.dataTransfer.getData(
                  'application/x-wanderplan-activity',
                ),
                row = document.activities.find((a) => a.ref === ref)
              if (row) move(row, day)
            }}
          >
            <div className="flex items-center justify-between gap-2">
              <h4 className="text-sm font-semibold">
                {day.slice(5)}{' '}
                <span className="font-normal text-ink-2">
                  {text(dayData(document, day).city)}
                </span>
              </h4>
              <Button
                size="sm"
                variant="ghost"
                disabled={disabled}
                onClick={() => setEditor(dayData(document, day))}
                aria-label={`${r('c.edit')} ${day}`}
              >
                ⋯
              </Button>
            </div>
            {document.activities
              .map((row, index) => ({ row, index }))
              .filter(({ row }) => row.date === day)
              .sort(
                (a, b) =>
                  (minute(a.row.start) ?? 1440) - (minute(b.row.start) ?? 1440),
              )
              .map(({ row, index }) => (
                <div
                  key={text(row.ref)}
                  className="calendar-visit"
                  draggable={!disabled}
                  onDragStart={(e) =>
                    e.dataTransfer.setData(
                      'application/x-wanderplan-activity',
                      text(row.ref),
                    )
                  }
                >
                  <button
                    type="button"
                    disabled={disabled}
                    onClick={() => onEdit(index)}
                    className="text-left"
                  >
                    <span className="block text-xs text-ink-2">
                      {text(row.start) || '—'}
                      {row.end ? `–${text(row.end)}` : ''}
                    </span>
                    <strong className="text-sm">{text(row.title)}</strong>
                  </button>
                  <div className="mt-2 flex flex-wrap gap-1">
                    <Button
                      variant="ghost"
                      size="sm"
                      disabled={disabled}
                      aria-label={`${r('c.edit')} ${text(row.title)} ${r('c.date')}`}
                      onClick={() =>
                        setEditor({ moveRef: row.ref, date: row.date })
                      }
                    >
                      ↔
                    </Button>
                    {minute(row.end) != null && (
                      <Button
                        variant="ghost"
                        size="sm"
                        disabled={
                          disabled || (minute(row.end) ?? 0) + 15 > 1440
                        }
                        onClick={() => {
                          const next = {
                            ...document,
                            activities: document.activities.map((a) =>
                              a === row
                                ? {
                                    ...a,
                                    end: timeLabel(minute(row.end)! + 15),
                                  }
                                : a,
                            ),
                          }
                          if (protectedBooking(row))
                            setPending({
                              description: r('fl.confirmBooked'),
                              next,
                            })
                          else void onSave(next)
                        }}
                        aria-label={`${text(row.title)} +15 min`}
                      >
                        +15 min
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            <Button
              size="sm"
              variant="ghost"
              disabled={disabled}
              onClick={() => onAdd(day)}
              aria-label={`${r('it.addActivity')} ${day}`}
            >
              + {r('c.add')}
            </Button>
          </section>
        ))}
      </div>
      {editor && (
        <RecordForm
          title={r('nav.itinerary')}
          row={editor}
          disabled={disabled}
          onClose={() => {
            setEditor(undefined)
            setDuplicate(false)
          }}
          fields={
            editor.moveRef
              ? [{ key: 'date', label: 'c.date', type: 'date', required: true }]
              : [
                  {
                    key: 'date',
                    label: 'c.date',
                    type: 'date',
                    required: true,
                  },
                  { key: 'title', label: 'c.name' },
                  { key: 'city', label: 'c.city' },
                  { key: 'overnightCity', label: 'it.overnight' },
                  {
                    key: 'type',
                    label: 'c.type',
                    type: 'select',
                    options: [
                      'travel',
                      'sightseeing',
                      'rest',
                      'transit',
                      'free',
                    ].map((v) => [v, 'dayType.' + v]),
                  },
                  {
                    key: 'foodAmount',
                    label: 'it.food',
                    type: 'number',
                    min: 0,
                  },
                  { key: 'currency', label: 'c.currency' },
                  { key: 'notes', label: 'c.notes', type: 'textarea' },
                ]
          }
          onSave={async (row) => {
            if (row.moveRef) {
              const activity = document.activities.find(
                (a) => a.ref === row.moveRef,
              )
              if (activity) move(activity, text(row.date))
              return true
            }
            const next = upsert(document, 'dayPlans', {
              ...row,
              ref: text(row.date),
              currency: text(row.currency) || currency,
            })
            const clean = next.expenses.filter(
              (e) => !(e.source === 'day-food' && e.date === row.date),
            )
            if (Number(row.foodAmount) > 0)
              clean.push({
                ref: 'food:' + text(row.date),
                title: r('it.food'),
                date: row.date,
                kind: 'planned',
                category: 'food',
                amount: Number(row.foodAmount),
                currency: text(row.currency) || currency,
                isAllowance: true,
                source: 'day-food',
                isPaid: false,
              })
            next.expenses = clean
            return onSave(next)
          }}
          extra={() =>
            !editor.moveRef ? (
              <div className="flex flex-wrap gap-2">
                <Button
                  variant="outline"
                  type="button"
                  disabled={disabled}
                  onClick={() => setDuplicate(true)}
                >
                  {r('c.duplicate')}
                </Button>
                <Button
                  variant="outline"
                  type="button"
                  disabled={disabled}
                  onClick={() => {
                    const day = text(editor.date)
                    setEditor(undefined)
                    setPending({
                      description: r('it.clearConfirm'),
                      next: {
                        ...document,
                        activities: document.activities.filter(
                          (a) => a.date !== day,
                        ),
                      },
                    })
                  }}
                >
                  {r('it.clearDay')}
                </Button>
                <Button
                  variant="outline"
                  type="button"
                  disabled={disabled}
                  onClick={() => {
                    const day = text(editor.date)
                    const next = {
                      ...document,
                      activities: document.activities.map((a) =>
                        text(a.date) > day && !protectedBooking(a)
                          ? {
                              ...a,
                              date: shift(text(a.date), 1),
                              endDate: a.endDate
                                ? shift(text(a.endDate), 1)
                                : undefined,
                            }
                          : a,
                      ),
                      dayPlans: records(document.dayPlans).map((d) =>
                        text(d.date) > day
                          ? { ...d, date: shift(text(d.date), 1) }
                          : d,
                      ),
                    }
                    setEditor(undefined)
                    setPending({ description: r('it.insertDay'), next })
                  }}
                >
                  {r('it.insertDay')}
                </Button>
              </div>
            ) : null
          }
        />
      )}
      {duplicate && editor && (
        <RecordForm
          title={r('c.duplicate')}
          row={{ date: shift(text(editor.date), 1) }}
          fields={[
            { key: 'date', label: 'c.date', type: 'date', required: true },
          ]}
          disabled={disabled}
          onClose={() => setDuplicate(false)}
          onSave={(row) =>
            onSave(cloneDay(document, text(editor.date), text(row.date)))
          }
        />
      )}
      {shiftDates && (
        <RecordForm
          title={r('dash.editDates')}
          row={{ date: dates[0], moveBookings: false }}
          fields={[
            { key: 'date', label: 'c.date', type: 'date', required: true },
            {
              key: 'moveBookings',
              label: 'dash.shiftBookings',
              type: 'checkbox',
            },
          ]}
          disabled={disabled}
          onClose={() => setShiftDates(false)}
          onSave={async (row) => {
            const delta = daysBetween(dates[0], text(row.date))
            const { shiftPlanDates } = await import('./domain')
            setPending({
              description: `${dates[0]} → ${text(row.date)} · ${r('fl.confirmBooked')}`,
              next: {
                ...shiftPlanDates(document, delta, row.moveBookings === true),
                planningStartDate: text(row.date),
                planningEndDate: shift(dates.at(-1)!, delta),
              },
            })
            return true
          }}
        />
      )}
      {pending && (
        <Confirm
          title={r('c.confirm')}
          description={pending.description}
          disabled={disabled}
          onClose={() => setPending(undefined)}
          onConfirm={() => onSave(pending.next)}
        />
      )}
    </section>
  )
}
