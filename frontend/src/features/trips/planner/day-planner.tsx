import { useEffect, useRef, useState } from 'react'
import { ArrowLeft, ArrowRight, Plus } from 'lucide-react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { formatDate } from '#/lib/format'
import type { Trip } from '#/lib/api/types'
import { roadRoute } from '../maps.functions'
import { p } from './copy'
import { records, text } from './model'
import type { PlanDocument, PlanRow } from './model'
import {
  assessDay,
  connectionKey,
  connectionSignature,
  point,
  timeLabel,
  dayStops,
  timelineBlocks,
  recommendedBuffer,
} from './schedule'
import type { TravelMode } from './schedule'
import { PlanMap } from './plan-map'
import { TransportComparison } from './transport-comparison'
import { RouteSuggestions } from './route-suggestions'
import { LiveTransport } from './live-transport'
import { mergeConnection } from './connection-record'
import { PlaceSearch } from './place-search'
import { localDateTime, zonedTimestamp } from '../transport/model'

const modes: Array<TravelMode> = [
  'walking',
  'cycling',
  'driving',
  'train',
  'flight',
  'bus',
]
type Transfer = ReturnType<typeof assessDay>['transfers'][number]
const shiftDay = (day: string, delta: number) =>
  new Date(Date.parse(day + 'T00:00:00Z') + delta * 86400000)
    .toISOString()
    .slice(0, 10)

export function DayPlanner({
  trip,
  document,
  canEdit,
  busy,
  save,
  onEdit,
  onAdd,
  onActual,
}: {
  trip: Trip
  document: PlanDocument
  canEdit: boolean
  busy: boolean
  save: (next: PlanDocument) => Promise<boolean>
  onEdit: (index: number) => void
  onAdd: (day: string) => void
  onActual: (row: PlanRow) => void
}) {
  const [day, setDay] = useState(
    trip.startDate ||
      text(document.activities.find((row) => row.date)?.date) ||
      new Date().toISOString().slice(0, 10),
  )
  const [selected, setSelected] = useState<string | undefined>(),
    [showActual, setShowActual] = useState(false)
  const [endpoint, setEndpoint] = useState<'location' | 'destination'>(
    'location',
  )
  const selectedStop = document.activities.find((row) => row.ref === selected)
  async function setLocation(
    lat: number,
    lng: number,
    name?: string,
    sourceUrl?: string,
  ) {
    if (!selectedStop) return
    const previous = selectedStop[endpoint]
    await save({
      ...document,
      activities: document.activities.map((row) =>
        row.ref === selected
          ? {
              ...row,
              [endpoint]: {
                ...(previous && typeof previous === 'object' ? previous : {}),
                name:
                  name ||
                  text(
                    typeof previous === 'string'
                      ? previous
                      : (previous as PlanRow | undefined)?.name,
                  ) ||
                  text(row.title),
                lat,
                lng,
                sourceUrl,
              },
            }
          : row,
      ),
    })
  }
  const result = assessDay(document, day),
    scroller = useRef<HTMLDivElement>(null)
  const blocks = timelineBlocks(document, day, showActual),
    stops = dayStops(document, day, showActual)
  const lanes = Math.max(1, ...blocks.map((item) => item.lane + 1))
  useEffect(() => {
    if (scroller.current)
      scroller.current.scrollTop =
        Math.max(0, (result.items[0]?.start ?? 420) - 60) * 0.9
  }, [day]) // Scroll to the first activity when changing days.
  const mapped = stops.flatMap(({ row }, index) =>
    [point(row.location), point(row.destination)]
      .filter((value) => value != null)
      .map((value) => ({ ...value, number: index + 1, ref: text(row.ref) })),
  )
  const routes = result.transfers.flatMap((item) =>
    item.saved?.geometry
      ? [item.saved.geometry as Array<[number, number]>]
      : [],
  )

  return (
    <div className="space-y-6">
      <div className="planner-toolbar">
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="icon"
            aria-label={p('previousDay')}
            onClick={() => setDay(shiftDay(day, -1))}
          >
            <ArrowLeft />
          </Button>
          <Input
            type="date"
            aria-label={p('selectDay')}
            value={day}
            onChange={(event) => {
              if (event.target.value) setDay(event.target.value)
            }}
            className="w-auto"
          />
          <Button
            variant="outline"
            size="icon"
            aria-label={p('nextDay')}
            onClick={() => setDay(shiftDay(day, 1))}
          >
            <ArrowRight />
          </Button>
        </div>
        {canEdit && (
          <Button disabled={busy} onClick={() => onAdd(day)}>
            <Plus />
            {p('addActivity')}
          </Button>
        )}
      </div>
      <p className="text-xs text-ink-3">
        {p('dayZone')} {trip.timeZone || 'UTC'}
      </p>
      <RouteSuggestions
        key={day}
        tripId={trip.id}
        day={day}
        document={document}
        disabled={busy || !canEdit}
        onSave={save}
      />
      <div className="day-summary" role="status">
        <strong>
          {result.overlaps.length ||
          result.transfers.some(
            (leg) => leg.remaining != null && leg.remaining < 0,
          )
            ? p('notFeasible')
            : result.untimed.length ||
                result.transfers.some((leg) => leg.duration == null)
              ? p('needsChecks')
              : result.items.length
                ? p('dayFits')
                : p('dayEmpty')}
        </strong>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={showActual}
            onChange={(event) => setShowActual(event.target.checked)}
          />
          {p('showActual')}
        </label>
      </div>
      <div className="day-layout">
        <section className="min-w-0" aria-label={p('dayPlan')}>
          <h3 className="mb-3 font-semibold">{formatDate(day)}</h3>
          {!result.items.length && (
            <p className="mb-4 text-sm text-ink-2">
              {result.untimed.length ? p('unscheduled') : p('dayEmpty')}
            </p>
          )}
          <div
            className="day-scroll"
            ref={scroller}
            tabIndex={0}
            aria-label={p('tabTimeline')}
          >
            <div className="day-hours">
              {Array.from({ length: 25 }, (_, hour) => (
                <div key={hour} className="day-hour" style={{ top: hour * 54 }}>
                  <span>{String(hour).padStart(2, '0')}:00</span>
                </div>
              ))}
              {blocks.map((item) => (
                <button
                  key={item.key}
                  type="button"
                  className={`day-event day-event-${item.kind} ${item.kind === 'activity' && result.overlaps.some((pair) => pair.some((overlap) => overlap.index === item.index)) ? 'day-event-overlap' : ''} ${selected === item.row.ref ? 'day-event-selected' : ''}`}
                  onClick={() => {
                    setSelected(text(item.row.ref))
                    if (item.kind === 'travel' || item.kind === 'buffer')
                      window.document
                        .getElementById(`connection-${item.index}`)
                        ?.scrollIntoView({
                          behavior: 'smooth',
                          block: 'center',
                        })
                  }}
                  style={{
                    top: item.start * 0.9,
                    height: Math.max(48, (item.end - item.start) * 0.9 - 3),
                    left: `calc(58px + (100% - 64px) * ${item.lane / lanes})`,
                    width: `calc((100% - 64px) / ${lanes} - 4px)`,
                  }}
                  aria-label={`${item.kind === 'travel' ? p('routeDuration') : item.kind === 'buffer' ? p('bufferBlock') : item.kind === 'actual' ? p('actualTimes') : p('plannedTimes')}: ${item.title}, ${timeLabel(item.start)}–${timeLabel(item.end)}`}
                >
                  <span className="block text-xs tabular-nums">
                    {timeLabel(item.start)}–{timeLabel(item.end)}
                  </span>
                  <strong className="mt-1 block truncate font-medium">
                    {item.kind === 'travel'
                      ? `${modes.includes(item.mode as TravelMode) ? p(item.mode as TravelMode) : p('routeDuration')} · ${item.title}`
                      : item.kind === 'buffer'
                        ? `${p('bufferBlock')} · ${item.title}`
                        : item.kind === 'actual'
                          ? `${p('actualTimes')} · ${item.title}`
                          : item.title}
                  </strong>
                </button>
              ))}
            </div>
          </div>
        </section>
        <div className="min-w-0 space-y-5">
          <PlanMap
            places={mapped.map((place) => ({ ...place }))}
            routes={routes}
            selectedRef={selected}
            onSelect={setSelected}
          />
          {selectedStop && canEdit && (
            <details className="day-location">
              <summary>
                {p('setStopLocation')}: {text(selectedStop.title)}
              </summary>
              <div className="mt-4 space-y-4">
                <label className="block text-sm">
                  {p('fieldLocation')}
                  <select
                    className="planner-select mt-2"
                    value={endpoint}
                    onChange={(event) =>
                      setEndpoint(
                        event.target.value as 'location' | 'destination',
                      )
                    }
                  >
                    <option value="location">{p('fieldLocation')}</option>
                    <option value="destination">{p('fieldTo')}</option>
                  </select>
                </label>
                <PlaceSearch
                  key={selected + '-' + endpoint}
                  tripId={trip.id}
                  disabled={busy}
                  onChoose={(place) =>
                    void setLocation(
                      place.lat,
                      place.lng,
                      place.name,
                      place.sourceUrl,
                    )
                  }
                />
              </div>
            </details>
          )}
          {mapped.length === 0 ? (
            <p className="text-sm text-ink-2">{p('noMapPoints')}</p>
          ) : (
            result.items.some((item) => !point(item.row.location)) && (
              <p className="text-sm text-ink-2">{p('mapMissingCount')}</p>
            )
          )}
          {(result.overlaps.length > 0 ||
            result.longDay ||
            result.lateFinish) && (
            <div className="day-review" aria-live="polite">
              {result.overlaps.length === 0 ? (
                <p className="text-sm">{p('dayClear')}</p>
              ) : (
                <>
                  <h4 className="font-medium text-bad">{p('dayOverlap')}</h4>
                  <ul className="mt-2 space-y-2 text-sm">
                    {result.overlaps.map(([a, b], index) => (
                      <li key={index}>
                        {text(a.row.title)} · {text(b.row.title)}
                      </li>
                    ))}
                  </ul>
                </>
              )}
              {result.longDay && (
                <p className="mt-3 text-sm text-warn">{p('longDay')}</p>
              )}
              {result.lateFinish && (
                <p className="mt-3 text-sm text-warn">{p('lateFinish')}</p>
              )}
            </div>
          )}
          <section aria-label={p('stopsOfDay')}>
            <h4 className="mb-2 font-semibold">{p('stopsOfDay')}</h4>
            <p className="mb-3 text-xs text-ink-2">{p('chooseStop')}</p>
            <ol className="day-stops">
              {stops.map(({ row, index }, number) => (
                <li
                  key={text(row.ref)}
                  className={selected === row.ref ? 'is-selected' : ''}
                >
                  <button
                    className="day-stop-name"
                    type="button"
                    onClick={() => setSelected(text(row.ref))}
                    aria-pressed={selected === row.ref}
                  >
                    <span className="day-stop-number">{number + 1}</span>
                    <span>
                      <strong>{text(row.title)}</strong>
                      <small>
                        {row.kind === 'hotel'
                          ? `${p('kindHotel')} · ${formatDate(text(row.date), 'short')} – ${formatDate(text(row.endDate || row.date), 'short')}`
                          : text(row.start) || p('timeTbd')}
                        {!point(row.location) ? ` · ${p('noCoordinates')}` : ''}
                      </small>
                    </span>
                  </button>
                  {canEdit && (
                    <div className="day-stop-actions">
                      <Button
                        variant="ghost"
                        size="sm"
                        disabled={busy}
                        onClick={() => onEdit(index)}
                      >
                        {p('actionEdit')}
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        disabled={busy}
                        onClick={() => {
                          setSelected(text(row.ref))
                          onActual(row)
                        }}
                      >
                        {p('recordVisit')}
                      </Button>
                    </div>
                  )}
                </li>
              ))}
            </ol>
          </section>
        </div>
      </div>
      <section>
        <h3 className="mb-2 font-semibold">{p('connections')}</h3>
        <p className="mb-4 text-sm leading-relaxed text-ink-2">
          {p('manualSchedule')}
        </p>
        {result.transfers.length === 0 ? (
          <p className="text-sm text-ink-3">{p('dayEmpty')}</p>
        ) : (
          <div className="planner-list">
            {result.transfers.map((transfer) => (
              <Connection
                key={
                  connectionKey(transfer.from.row, transfer.to.row) +
                  JSON.stringify(transfer.saved)
                }
                tripId={trip.id}
                day={day}
                timeZone={trip.timeZone || 'UTC'}
                travelers={trip.travelerCount ?? 1}
                currency={trip.currency || ''}
                transfer={transfer}
                busy={busy}
                canEdit={canEdit}
                onSave={(row) =>
                  save(
                    mergeConnection(
                      document,
                      transfer.from.row,
                      transfer.to.row,
                      row,
                    ),
                  )
                }
              />
            ))}
          </div>
        )}
      </section>
    </div>
  )
}

function Connection({
  tripId,
  day,
  timeZone,
  travelers,
  currency,
  transfer,
  busy,
  canEdit,
  onSave,
}: {
  tripId: string
  day: string
  timeZone: string
  travelers: number
  currency: string
  transfer: Transfer
  busy: boolean
  canEdit: boolean
  onSave: (row: PlanRow) => Promise<boolean>
}) {
  const saved = transfer.saved
  const [mode, setMode] = useState<TravelMode>(
    (saved?.mode as TravelMode | undefined) || 'walking',
  )
  const [duration, setDuration] = useState(text(saved?.durationMinutes)),
    [buffer, setBuffer] = useState(transfer.buffer)
  const [route, setRoute] = useState<PlanRow | undefined>(saved),
    [loading, setLoading] = useState(false),
    [error, setError] = useState('')
  const [departureBuffer, setDepartureBuffer] = useState(
    typeof saved?.departureBufferMinutes === 'number'
      ? saved.departureBufferMinutes
      : 0,
  )
  const [alternatives, setAlternatives] = useState<Array<PlanRow>>(
    records(saved?.alternatives),
  )
  const [serviceDeparture, setServiceDeparture] = useState(
      localDateTime(saved?.departure, timeZone),
    ),
    [serviceArrival, setServiceArrival] = useState(
      localDateTime(saved?.arrival, timeZone),
    )
  function scheduleChange(key: 'departure' | 'arrival', value: string) {
    setRoute(undefined)
    const start = key === 'departure' ? value : serviceDeparture,
      end = key === 'arrival' ? value : serviceArrival
    if (key === 'departure') setServiceDeparture(value)
    else setServiceArrival(value)
    if (start && end) {
      try {
        const a = zonedTimestamp(
            start.slice(0, 10),
            start.slice(11, 16),
            timeZone,
          ),
          b = zonedTimestamp(end.slice(0, 10), end.slice(11, 16), timeZone)
        if (b > a)
          setDuration(
            String(Math.ceil((Date.parse(b) - Date.parse(a)) / 60000)),
          )
      } catch {
        /* The form reports invalid local times on save. */
      }
    }
  }
  const [fare, setFare] = useState(text(saved?.amount)),
    [fareCurrency, setFareCurrency] = useState(
      text(saved?.currency) || currency,
    )
  const currentChoice: PlanRow | undefined =
    duration === ''
      ? undefined
      : {
          ...(route ?? { source: 'manual' }),
          mode,
          durationMinutes: Number(duration),
          amount: fare !== '' ? Number(fare) : undefined,
          currency: fareCurrency,
          localDeparture: serviceDeparture,
          localArrival: serviceArrival,
          departureBufferMinutes: departureBuffer,
        }
  const choices = currentChoice
    ? [...alternatives.filter((row) => row.mode !== mode), currentChoice]
    : alternatives
  async function chooseMode(next: TravelMode) {
    setAlternatives(choices)
    const option = choices.find((row) => row.mode === next)
    setMode(next)
    setDuration(text(option?.durationMinutes))
    setRoute(option)
    setServiceDeparture(
      text(option?.localDeparture) ||
        localDateTime(option?.departure, timeZone),
    )
    setServiceArrival(
      text(option?.localArrival) || localDateTime(option?.arrival, timeZone),
    )
    setDepartureBuffer(
      typeof option?.departureBufferMinutes === 'number'
        ? option.departureBufferMinutes
        : recommendedBuffer({ kind: next }),
    )
    setFare(text(option?.amount))
    setFareCurrency(text(option?.currency) || currency)
    setError('')
    window.document
      .getElementById(
        `leg-${transfer.from.index}-${transfer.to.index}-duration`,
      )
      ?.focus()
    if (
      option &&
      typeof option.durationMinutes === 'number' &&
      ['walking', 'cycling', 'driving'].includes(next) &&
      !option.geometry &&
      from &&
      to
    ) {
      setLoading(true)
      try {
        const result = await roadRoute({
          data: {
            tripId,
            mode: next as 'walking' | 'cycling' | 'driving',
            from,
            to,
          },
        })
        if (result.ok) {
          setRoute({ ...option, ...result.data })
          setDuration(String(result.data.durationMinutes))
        } else setError(p('routeUnavailable'))
      } catch {
        setError(p('routeUnavailable'))
      } finally {
        setLoading(false)
      }
    }
  }
  const from =
      point(transfer.from.row.destination) || point(transfer.from.row.location),
    to = point(transfer.to.row.location)
  const road = ['walking', 'cycling', 'driving'].includes(mode),
    id = `leg-${transfer.from.index}-${transfer.to.index}`
  const shownSource = route ?? (saved?.mode === mode ? saved : undefined)
  const remaining = transfer.remaining
  const directions = new URL('https://www.google.com/maps/dir/')
  directions.searchParams.set('api', '1')
  directions.searchParams.set(
    'origin',
    from
      ? `${from.lat},${from.lng}`
      : text((transfer.from.row.destination as PlanRow | undefined)?.name) ||
          text((transfer.from.row.location as PlanRow | undefined)?.name) ||
          text(transfer.from.row.title),
  )
  directions.searchParams.set(
    'destination',
    to
      ? `${to.lat},${to.lng}`
      : text((transfer.to.row.location as PlanRow | undefined)?.name) ||
          text(transfer.to.row.title),
  )
  directions.searchParams.set(
    'travelmode',
    road
      ? { walking: 'walking', cycling: 'bicycling', driving: 'driving' }[
          mode as 'walking' | 'cycling' | 'driving'
        ]
      : 'transit',
  )
  async function estimate() {
    if (!from || !to || !road) return
    setLoading(true)
    setError('')
    try {
      const response = await roadRoute({
        data: {
          tripId,
          mode: mode as 'walking' | 'cycling' | 'driving',
          from,
          to,
        },
      })
      if (response.ok) {
        setDuration(String(response.data.durationMinutes))
        setRoute({ ...response.data })
      } else setError(p('routeUnavailable'))
    } catch {
      setError(p('routeUnavailable'))
    } finally {
      setLoading(false)
    }
  }
  return (
    <article className="connection-row" id={`connection-${transfer.to.index}`}>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <h4 className="min-w-0 font-medium">
          {text(transfer.from.row.title)} <span className="text-ink-3">→</span>{' '}
          {text(transfer.to.row.title)}
        </h4>
        <p
          className={`text-sm ${remaining != null && remaining < 0 ? 'text-bad' : remaining == null ? 'text-ink-3' : 'text-brand'}`}
        >
          {remaining == null
            ? p('routeUnknown')
            : `${Math.abs(remaining)} ${p(remaining < 0 ? 'shortMinutes' : 'spareMinutes')}`}
        </p>
      </div>
      <p className="mt-2 text-xs text-ink-3">
        {transfer.gap} {p('gapMinutes')} · {timeLabel(transfer.from.end)}–
        {timeLabel(transfer.to.start)}
      </p>
      <TransportComparison
        tripId={tripId}
        from={from}
        to={to}
        choices={choices}
        window={{
          day,
          timeZone,
          previousEnd: transfer.from.end,
          latestArrival: transfer.to.start - buffer,
        }}
        disabled={busy || !canEdit || loading}
        onResults={(results) => {
          setAlternatives((old) => [
            ...old.filter(
              (row) => !results.some((option) => option.mode === row.mode),
            ),
            ...results,
          ])
          const selected = results.find((row) => row.mode === mode)
          if (selected) {
            setRoute(selected)
            setDuration(text(selected.durationMinutes))
          }
        }}
        onChoose={chooseMode}
      />
      <LiveTransport
        key={mode}
        tripId={tripId}
        travelers={travelers}
        currency={currency}
        mode={mode}
        date={text(transfer.from.row.endDate || transfer.from.row.date)}
        clock={
          text(transfer.from.row.end) === '24:00'
            ? '23:59'
            : text(transfer.from.row.end) || '08:00'
        }
        timeZone={timeZone}
        from={from}
        to={to}
        disabled={busy || !canEdit}
        onChoose={(offer) => {
          setAlternatives(choices)
          setMode(offer.mode)
          setDuration(String(offer.durationMinutes))
          setFare(text(offer.amount))
          setFareCurrency(offer.currency || currency)
          setRoute({ ...offer })
          setDepartureBuffer(recommendedBuffer({ kind: offer.mode }))
          setServiceDeparture(localDateTime(offer.departure, timeZone))
          setServiceArrival(localDateTime(offer.arrival, timeZone))
          setError('')
        }}
      />
      <form
        className="mt-4"
        onSubmit={async (event) => {
          event.preventDefault()
          if (Boolean(serviceDeparture) !== Boolean(serviceArrival)) {
            setError(p('timesPair'))
            return
          }
          let departure: string | undefined, arrival: string | undefined
          try {
            if (serviceDeparture && serviceArrival) {
              departure = zonedTimestamp(
                serviceDeparture.slice(0, 10),
                serviceDeparture.slice(11, 16),
                timeZone,
              )
              arrival = zonedTimestamp(
                serviceArrival.slice(0, 10),
                serviceArrival.slice(11, 16),
                timeZone,
              )
              if (arrival <= departure) {
                setError(p('scheduleInvalid'))
                return
              }
            }
          } catch {
            setError(p('scheduleInvalid'))
            return
          }
          await onSave({
            ...(route ?? {
              source: 'manual',
              fetchedAt: new Date().toISOString(),
            }),
            key: connectionKey(transfer.from.row, transfer.to.row),
            fromRef: transfer.from.row.ref,
            toRef: transfer.to.row.ref,
            signature: connectionSignature(
              transfer.from.row,
              transfer.to.row,
              mode,
              !!departure,
            ),
            mode,
            durationMinutes:
              departure && arrival
                ? Math.ceil(
                    (Date.parse(arrival) - Date.parse(departure)) / 60000,
                  )
                : Number(duration),
            departure,
            arrival,
            bufferMinutes: buffer,
            amount: fare !== '' ? Number(fare) : undefined,
            currency: fareCurrency,
            departureBufferMinutes: departureBuffer,
            alternatives: choices.map((option) => ({
              mode: option.mode,
              durationMinutes: option.durationMinutes,
              distanceKm: option.distanceKm,
              source: option.source,
              fetchedAt: option.fetchedAt,
              departure: option.departure,
              arrival: option.arrival,
              expiresAt: option.expiresAt,
              amount: option.amount,
              currency: option.currency,
              operator: option.operator,
              localDeparture: option.localDeparture,
              localArrival: option.localArrival,
              departureBufferMinutes: option.departureBufferMinutes,
            })),
          })
        }}
      >
        {['train', 'flight', 'bus'].includes(mode) && (
          <div className="mb-4 grid gap-4 sm:grid-cols-2">
            <div>
              <label
                htmlFor={`${id}-service-departure`}
                className="mb-2 block text-xs"
              >
                {p('scheduledDeparture')}
              </label>
              <Input
                id={`${id}-service-departure`}
                type="datetime-local"
                aria-label={p('scheduledDeparture')}
                value={serviceDeparture}
                disabled={busy || !canEdit}
                onChange={(event) =>
                  scheduleChange('departure', event.target.value)
                }
              />
            </div>
            <div>
              <label
                htmlFor={`${id}-service-arrival`}
                className="mb-2 block text-xs"
              >
                {p('scheduledArrival')}
              </label>
              <Input
                id={`${id}-service-arrival`}
                type="datetime-local"
                value={serviceArrival}
                disabled={busy || !canEdit}
                onChange={(event) =>
                  scheduleChange('arrival', event.target.value)
                }
              />
            </div>
            <p className="text-xs text-ink-3 sm:col-span-2">
              {p('dayZone')} {timeZone}
            </p>
          </div>
        )}
        <div className="connection-fields">
          <div>
            <label className="mb-2 block text-xs" htmlFor={`${id}-mode`}>
              {p('travelMode')}
            </label>
            <select
              id={`${id}-mode`}
              className="planner-select"
              value={mode}
              disabled={!canEdit || busy || loading}
              onChange={(event) => {
                chooseMode(event.target.value as TravelMode)
              }}
            >
              {modes.map((value) => (
                <option key={value} value={value}>
                  {p(value)}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="mb-2 block text-xs" htmlFor={`${id}-duration`}>
              {p('durationMinutes')}
            </label>
            <Input
              id={`${id}-duration`}
              type="number"
              min={0}
              max={14400}
              step={1}
              required
              readOnly={!!(serviceDeparture && serviceArrival)}
              value={duration}
              disabled={!canEdit || busy || loading}
              onChange={(event) => {
                setDuration(event.target.value)
                setRoute(undefined)
              }}
            />
          </div>
          <div>
            <label className="mb-2 block text-xs" htmlFor={`${id}-buffer`}>
              {p('bufferMinutes')}
            </label>
            <Input
              id={`${id}-buffer`}
              type="number"
              min={0}
              max={1440}
              required
              value={buffer}
              disabled={!canEdit || busy || loading}
              onChange={(event) => setBuffer(Number(event.target.value))}
            />
          </div>
        </div>
        <div className="mt-4 grid gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor={`${id}-fare`} className="mb-2 block text-xs">
              {p('totalFare')}
            </label>
            <Input
              id={`${id}-fare`}
              type="number"
              min={0}
              step="any"
              value={fare}
              disabled={busy || !canEdit}
              onChange={(event) => setFare(event.target.value)}
            />
          </div>
          <div>
            <label
              htmlFor={`${id}-fare-currency`}
              className="mb-2 block text-xs"
            >
              {p('currency')}
            </label>
            <Input
              id={`${id}-fare-currency`}
              maxLength={3}
              pattern="[A-Z]{3}"
              value={fareCurrency}
              required={fare !== ''}
              disabled={busy || !canEdit}
              onChange={(event) =>
                setFareCurrency(event.target.value.toUpperCase())
              }
            />
          </div>
        </div>
        {['train', 'flight', 'bus'].includes(mode) && (
          <div className="my-4">
            <label
              htmlFor={`${id}-departure-buffer`}
              className="mb-2 block text-xs"
            >
              {p('departureBuffer')}
            </label>
            <Input
              id={`${id}-departure-buffer`}
              type="number"
              min={0}
              max={1440}
              value={departureBuffer}
              disabled={busy || !canEdit}
              onChange={(event) =>
                setDepartureBuffer(Number(event.target.value))
              }
            />
          </div>
        )}
        <div className="mt-3 flex flex-wrap items-center gap-3">
          {canEdit && (
            <>
              {road && (
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={busy || loading || !from || !to}
                  onClick={() => void estimate()}
                >
                  {loading ? p('routeLoading') : p('estimateRoute')}
                </Button>
              )}
              <Button
                type="submit"
                size="sm"
                disabled={busy || loading || duration === ''}
              >
                {p('saveConnection')}
              </Button>
            </>
          )}
          <a
            className="text-sm text-brand underline underline-offset-4"
            target="_blank"
            rel="noreferrer"
            href={
              mode === 'flight'
                ? `https://www.google.com/travel/flights?q=${encodeURIComponent(text(transfer.from.row.title) + ' to ' + text(transfer.to.row.title))}`
                : directions.toString()
            }
          >
            {p('openDirections')}
          </a>
        </div>
        {canEdit && road && (!from || !to) && (
          <p className="mt-3 text-xs text-ink-2">{p('missingCoordinates')}</p>
        )}
        {error && (
          <p role="alert" className="mt-3 text-sm text-warn">
            {error}
          </p>
        )}
        {shownSource && (
          <p className="mt-3 text-xs text-ink-3">
            {p('routeSource')}:{' '}
            {text(shownSource.source) === 'manual'
              ? p('manualSource')
              : text(shownSource.source)}
            {typeof shownSource.distanceKm === 'number'
              ? ` · ${Number(shownSource.distanceKm).toFixed(1)} km`
              : ''}
            {shownSource.fetchedAt
              ? ` · ${new Date(text(shownSource.fetchedAt)).toLocaleDateString()}`
              : ''}
          </p>
        )}
      </form>
    </article>
  )
}
