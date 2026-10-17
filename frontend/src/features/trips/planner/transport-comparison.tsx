import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { roadRoute } from '../maps.functions'
import { p } from './copy'
import { text } from './model'
import { formatMoney } from '#/lib/format'
import { connectionMargin } from './schedule'
import type { PlanRow } from './model'
import type { Point, TravelMode } from './schedule'

export const travelModes: Array<TravelMode> = [
  'walking',
  'cycling',
  'driving',
  'train',
  'flight',
  'bus',
]
export function TransportComparison({
  tripId,
  from,
  to,
  choices,
  onResults,
  onChoose,
  window,
  disabled,
}: {
  tripId: string
  from?: Point
  to?: Point
  choices: Array<PlanRow>
  window: {
    day: string
    timeZone: string
    previousEnd: number
    latestArrival: number
  }
  disabled: boolean
  onResults: (choices: Array<PlanRow>) => void
  onChoose: (mode: TravelMode) => void
}) {
  const [loading, setLoading] = useState(false),
    [failed, setFailed] = useState<Array<string>>([])
  async function compare() {
    if (!from || !to) return
    setLoading(true)
    setFailed([])
    const results: Array<PlanRow> = []
    try {
      for (const mode of ['walking', 'cycling', 'driving'] as const) {
        try {
          const result = await roadRoute({ data: { tripId, mode, from, to } })
          if (result.ok) results.push({ ...result.data, mode })
          else setFailed((old) => [...old, mode])
        } catch {
          setFailed((old) => [...old, mode])
        }
      }
      onResults(results)
    } finally {
      setLoading(false)
    }
  }
  return (
    <details className="transport-comparison">
      <summary>{p('compareModes')}</summary>
      <div className="mt-4 space-y-3">
        <p className="text-sm text-ink-2">{p('comparisonHelp')}</p>
        <Button
          type="button"
          variant="outline"
          disabled={disabled || loading || !from || !to}
          onClick={() => void compare()}
        >
          {loading ? p('routeLoading') : p('compareRoadModes')}
        </Button>
        {(!from || !to) && (
          <p className="text-xs text-ink-2">{p('missingCoordinates')}</p>
        )}
        <div className="transport-table-wrap">
          <table className="transport-table">
            <caption className="sr-only">{p('compareModes')}</caption>
            <thead>
              <tr>
                <th scope="col">{p('travelMode')}</th>
                <th scope="col">{p('routeDuration')}</th>
                <th scope="col">{p('routeDistance')}</th>
                <th scope="col">{p('totalFare')}</th>
                <th scope="col">
                  <span className="sr-only">{p('chooseMode')}</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {travelModes.map((mode) => {
                const choice = choices.find((row) => row.mode === mode),
                  remaining = connectionMargin(
                    choice,
                    window.day,
                    window.timeZone,
                    window.previousEnd,
                    window.latestArrival,
                  ),
                  duration =
                    typeof choice?.durationMinutes === 'number'
                      ? choice.durationMinutes
                      : undefined
                return (
                  <tr key={mode}>
                    <th scope="row">{p(mode)}</th>
                    <td>
                      {duration == null ? (
                        '—'
                      ) : (
                        <>
                          <span>
                            {duration} {p('minutesUnit')}
                          </span>
                          {remaining != null && (
                            <small
                              className={
                                remaining < 0 ? 'text-bad' : 'text-ink-2'
                              }
                            >
                              {Math.abs(remaining)}{' '}
                              {p(
                                remaining < 0 ? 'shortMinutes' : 'spareMinutes',
                              )}
                            </small>
                          )}
                        </>
                      )}
                    </td>
                    <td>
                      {typeof choice?.distanceKm === 'number'
                        ? `${choice.distanceKm.toFixed(1)} km`
                        : '—'}
                    </td>
                    <td>
                      {typeof choice?.amount === 'number' &&
                      typeof choice.currency === 'string'
                        ? formatMoney(choice.amount, choice.currency)
                        : '—'}
                    </td>
                    <td>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        disabled={disabled || loading}
                        onClick={() => onChoose(mode)}
                        aria-label={`${p('chooseMode')}: ${p(mode)}`}
                      >
                        {p('chooseMode')}
                      </Button>
                      {failed.includes(mode) && (
                        <span className="sr-only">{p('comparisonFailed')}</span>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        {failed.length > 0 && (
          <p role="status" className="text-xs text-warn">
            {p('comparisonFailed')}{' '}
            {failed.map((mode) => text(mode)).join(', ')}
          </p>
        )}
      </div>
    </details>
  )
}
