import { useId, useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { roadMatrix, roadRoute } from '../maps.functions'
import type { RoadMatrix } from '../maps.functions'
import { p } from './copy'
import { text } from './model'
import type { PlanDocument } from './model'
import { minute, point, timeLabel } from './schedule'
import {
  applyOrder,
  canCompareStops,
  protectedStop,
  routeStops,
  suggestOrders,
} from './route-order'
import { PlanMap } from './plan-map'

export function RouteSuggestions({
  tripId,
  day,
  document,
  disabled,
  onSave,
}: {
  tripId: string
  day: string
  document: PlanDocument
  disabled: boolean
  onSave: (document: PlanDocument) => Promise<boolean>
}) {
  const id = useId(),
    stops = routeStops(document, day)
  const [mode, setMode] = useState<'walking' | 'cycling' | 'driving'>('walking')
  const [start, setStart] = useState(timeLabel(minute(stops[0]?.start) ?? 540)),
    [end, setEnd] = useState('22:00')
  const [visit, setVisit] = useState(60),
    [buffer, setBuffer] = useState(10)
  const [movable, setMovable] = useState<Array<string>>([])
  const [busy, setBusy] = useState(false),
    [error, setError] = useState('')
  const [result, setResult] = useState<{ key: string; matrix: RoadMatrix }>()
  const [selected, setSelected] = useState(0)
  const [preview, setPreview] = useState<{
    key: string
    routes: Array<Array<[number, number]>>
  }>()
  const allowed = canCompareStops(stops, day)
  const settings = {
    start: minute(start) ?? -1,
    end: minute(end) ?? -1,
    visit,
    buffer,
    movable,
  }
  const key = JSON.stringify([stops, settings, mode])
  const options =
    result?.key === key ? suggestOrders(stops, result.matrix, settings) : []
  const choice = options.at(selected)
  const previewKey = `${key}:${selected}`
  async function compare() {
    setBusy(true)
    setError('')
    setPreview(undefined)
    try {
      const response = await roadMatrix({
        data: { tripId, mode, stops: stops.map((row) => point(row.location)!) },
      })
      if (!response.ok) {
        setError(p('routeUnavailable'))
        return
      }
      setSelected(0)
      setResult({ key, matrix: response.data })
    } catch {
      setError(p('routeUnavailable'))
    } finally {
      setBusy(false)
    }
  }
  async function previewRoads() {
    if (!choice) return
    setBusy(true)
    setError('')
    setPreview(undefined)
    try {
      const routes: Array<Array<[number, number]>> = []
      for (let position = 1; position < choice.order.length; position++) {
        const response = await roadRoute({
          data: {
            tripId,
            mode,
            from: point(stops[choice.order[position - 1]].location)!,
            to: point(stops[choice.order[position]].location)!,
          },
        })
        if (!response.ok) throw new Error('route unavailable')
        routes.push(response.data.geometry)
      }
      setPreview({ key: previewKey, routes })
    } catch {
      setError(p('routeUnavailable'))
    } finally {
      setBusy(false)
    }
  }
  return (
    <details className="route-suggestions">
      <summary>{p('suggestStopOrders')}</summary>
      <div className="mt-4 space-y-4">
        <p className="text-sm text-ink-2">{p('stopOrderHelp')}</p>
        {!allowed ? (
          <p className="text-sm text-ink-2">{p('stopOrderScope')}</p>
        ) : (
          <>
            <div className="grid grid-cols-2 gap-4 lg:grid-cols-5">
              <label className="space-y-2 text-sm" htmlFor={`${id}-mode`}>
                <span>{p('travelMode')}</span>
                <select
                  id={`${id}-mode`}
                  className="planner-select w-full"
                  value={mode}
                  disabled={disabled || busy}
                  onChange={(event) =>
                    setMode(event.target.value as typeof mode)
                  }
                >
                  {(['walking', 'cycling', 'driving'] as const).map((value) => (
                    <option key={value} value={value}>
                      {p(value)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="space-y-2 text-sm" htmlFor={`${id}-start`}>
                <span>{p('routeDayStart')}</span>
                <Input
                  id={`${id}-start`}
                  type="time"
                  value={start}
                  disabled={disabled || busy}
                  onChange={(event) => setStart(event.target.value)}
                />
              </label>
              <label className="space-y-2 text-sm" htmlFor={`${id}-end`}>
                <span>{p('routeDayEnd')}</span>
                <Input
                  id={`${id}-end`}
                  type="time"
                  value={end}
                  disabled={disabled || busy}
                  onChange={(event) => setEnd(event.target.value)}
                />
              </label>
              <label className="space-y-2 text-sm" htmlFor={`${id}-visit`}>
                <span>{p('defaultVisitMinutes')}</span>
                <Input
                  id={`${id}-visit`}
                  type="number"
                  min={5}
                  max={720}
                  value={visit}
                  disabled={disabled || busy}
                  onChange={(event) => setVisit(Number(event.target.value))}
                />
              </label>
              <label className="space-y-2 text-sm" htmlFor={`${id}-buffer`}>
                <span>{p('bufferMinutes')}</span>
                <Input
                  id={`${id}-buffer`}
                  type="number"
                  min={0}
                  max={180}
                  value={buffer}
                  disabled={disabled || busy}
                  onChange={(event) => setBuffer(Number(event.target.value))}
                />
              </label>
            </div>
            <fieldset className="space-y-2">
              <legend className="mb-2 text-sm font-medium">
                {p('movableStops')}
              </legend>
              {stops.map((row, index) => (
                <label
                  key={text(row.ref)}
                  className="flex items-center gap-3 text-sm"
                >
                  <input
                    type="checkbox"
                    disabled={
                      disabled || busy || index === 0 || protectedStop(row)
                    }
                    checked={
                      movable.includes(text(row.ref)) &&
                      index > 0 &&
                      !protectedStop(row)
                    }
                    onChange={(event) =>
                      setMovable((old) =>
                        event.target.checked
                          ? [...old, text(row.ref)]
                          : old.filter((ref) => ref !== row.ref),
                      )
                    }
                  />
                  <span>
                    {text(row.title)}
                    {index === 0
                      ? ` · ${p('routeStartingStop')}`
                      : protectedStop(row)
                        ? ` · ${p('routeFixedStop')}`
                        : ''}
                  </span>
                </label>
              ))}
            </fieldset>
            <Button
              type="button"
              variant="outline"
              disabled={
                disabled ||
                busy ||
                settings.start < 0 ||
                settings.end <= settings.start ||
                visit < 5 ||
                visit > 720 ||
                buffer < 0 ||
                buffer > 180
              }
              onClick={() => void compare()}
            >
              {busy ? p('routeLoading') : p('compareStopOrders')}
            </Button>
            {options.length > 0 && (
              <>
                <fieldset className="space-y-3">
                  <legend className="mb-2 font-medium">
                    {p('chooseStopOrder')}
                  </legend>
                  {options.map((option, index) => (
                    <label
                      key={option.order.join(',')}
                      className="route-order-option"
                    >
                      <input
                        type="radio"
                        name={`${id}-option`}
                        value={index}
                        checked={selected === index}
                        disabled={busy || disabled}
                        onChange={() => {
                          setSelected(index)
                          setPreview(undefined)
                        }}
                      />
                      <span className="min-w-0">
                        <strong>
                          {index === 0
                            ? p('currentOrder')
                            : `${p('routeAlternative')} ${index}`}
                        </strong>
                        <span className="block mt-1 text-sm text-ink-2">
                          {option.travel} {p('routeTravelMinutes')} ·{' '}
                          {p('routeFinish')} {timeLabel(option.finish)} ·{' '}
                          {option.wait} {p('routeWaitingMinutes')}
                        </span>
                        <span className="block mt-2 text-sm">
                          {option.order
                            .map((i) => text(stops[i].title))
                            .join(' → ')}
                        </span>
                        {!option.feasible && (
                          <span className="block mt-2 text-sm text-bad">
                            {p('routeDoesNotFit')}
                          </span>
                        )}
                      </span>
                    </label>
                  ))}
                </fieldset>
                {options.length === 1 && (
                  <p className="text-sm text-ink-2">{p('noOtherStopOrders')}</p>
                )}
                {choice && (
                  <>
                    <ol
                      className="space-y-2 text-sm"
                      aria-label={p('proposedTimes')}
                    >
                      {choice.visits.map((item) => (
                        <li key={item.index}>
                          <span className="font-medium">
                            {timeLabel(item.start)}–{timeLabel(item.end)}
                          </span>{' '}
                          · {text(stops[item.index].title)}
                        </li>
                      ))}
                    </ol>
                    <Button
                      type="button"
                      variant="outline"
                      disabled={busy || disabled}
                      onClick={() => void previewRoads()}
                    >
                      {busy ? p('routeLoading') : p('previewRoute')}
                    </Button>
                    {preview?.key === previewKey && (
                      <>
                        <PlanMap
                          places={choice.order.map((index, position) => ({
                            ...point(stops[index].location)!,
                            name: text(stops[index].title),
                            ref: text(stops[index].ref),
                            number: position + 1,
                          }))}
                          routes={preview.routes}
                        />
                        <p className="text-xs text-ink-2">
                          {p('routeApplyHelp')}
                        </p>
                        <Button
                          type="button"
                          disabled={busy || disabled || !choice.feasible}
                          onClick={async () => {
                            if (
                              !result ||
                              result.key !== key ||
                              !choice.feasible
                            )
                              return
                            const next = applyOrder(
                              document,
                              stops,
                              choice,
                              result.matrix,
                              settings,
                              mode,
                            )
                            // Store only the displayed road paths, tied to these exact endpoints.
                            const paths = new Map(
                              choice.visits
                                .slice(1)
                                .map((item, index) => [
                                  `${text(stops[choice.order[index]].ref)}::${text(stops[item.index].ref)}`,
                                  preview.routes[index],
                                ]),
                            )
                            next.connections = (
                              next.connections as Array<Record<string, unknown>>
                            ).map((row) =>
                              paths.has(text(row.key))
                                ? { ...row, geometry: paths.get(text(row.key)) }
                                : row,
                            )
                            if (await onSave(next)) {
                              setResult(undefined)
                              setPreview(undefined)
                            }
                          }}
                        >
                          {p('applyStopOrder')}
                        </Button>
                      </>
                    )}
                  </>
                )}
              </>
            )}
            <p className="text-xs text-ink-2">{p('stopOrderLimits')}</p>
          </>
        )}
        {error && (
          <p role="alert" className="text-sm text-warn">
            {error}
          </p>
        )}
      </div>
    </details>
  )
}
