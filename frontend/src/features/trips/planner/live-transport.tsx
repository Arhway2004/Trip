import { useId, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { formatMoney } from '#/lib/format'
import { unwrap } from '#/lib/api/problem'
import { liveTransport, transportStatus } from '../transport.functions'
import type { TransportOffer } from '../transport/model'
import { publicTransportSearch } from '../transport/public-search'
import { p } from './copy'
import type { Point, TravelMode } from './schedule'

export function LiveTransport({
  tripId,
  mode,
  date,
  clock,
  timeZone,
  from,
  to,
  disabled,
  onChoose,
  travelers = 1,
  currency,
}: {
  tripId: string
  mode: TravelMode
  date: string
  clock: string
  timeZone: string
  from?: Point
  to?: Point
  disabled: boolean
  travelers?: number
  currency?: string
  onChoose: (offer: TransportOffer) => void
}) {
  const uid = useId()
  const [open, setOpen] = useState(false),
    [origin, setOrigin] = useState(from?.name || ''),
    [destination, setDestination] = useState(to?.name || ''),
    [adults, setAdults] = useState(Math.min(9, Math.max(1, travelers))),
    [departureDate, setDepartureDate] = useState(date),
    [departureClock, setDepartureClock] = useState(clock),
    [busy, setBusy] = useState(false),
    [results, setResults] = useState<Array<TransportOffer> | null>(null),
    [error, setError] = useState('')
  const status = useQuery({
    queryKey: ['transport-status', tripId],
    queryFn: async () => unwrap(await transportStatus({ data: { tripId } })),
    enabled: open,
    staleTime: 300000,
  })
  if (!['train', 'flight', 'bus'].includes(mode)) return null
  const ready = mode === 'flight' ? status.data?.flights : status.data?.transit
  const clockFormat = (iso: string) =>
    new Intl.DateTimeFormat(undefined, {
      timeZone,
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(iso))
  const publicUrl = publicTransportSearch({
    mode,
    origin,
    destination,
    date: departureDate,
    adults,
    currency,
  })
  const validPublic =
    origin.trim().length > 1 &&
    destination.trim().length > 1 &&
    departureDate &&
    adults >= 1 &&
    adults <= 9
  return (
    <details
      className="live-transport"
      onToggle={(event) => setOpen(event.currentTarget.open)}
    >
      <summary>{p('liveSearch')}</summary>
      <div className="mt-4 space-y-4">
        <p className="text-sm text-ink-2">{p('publicSearchHelp')}</p>
        <form
          onSubmit={async (event) => {
            event.preventDefault()
            if (busy) return
            if (!ready) {
              window.open(publicUrl, '_blank', 'noopener,noreferrer')
              return
            }
            if (
              mode === 'flight' &&
              (!/^[A-Z]{3}$/.test(origin) || !/^[A-Z]{3}$/.test(destination))
            ) {
              window.open(publicUrl, '_blank', 'noopener,noreferrer')
              return
            }
            setBusy(true)
            setResults(null)
            setError('')
            try {
              const result = await liveTransport({
                data: {
                  tripId,
                  mode: mode as 'train' | 'bus' | 'flight',
                  date: departureDate,
                  clock: departureClock,
                  from,
                  to,
                  ...(mode === 'flight' ? { origin, destination } : {}),
                  adults,
                },
              })
              if (result.ok) setResults(result.data)
              else
                setError(
                  p(
                    result.problem.status === 429
                      ? 'liveRateLimit'
                      : 'liveUnavailable',
                  ),
                )
            } catch {
              setError(p('liveUnavailable'))
            } finally {
              setBusy(false)
            }
          }}
          className="space-y-4"
        >
          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <label
                className="mb-2 block text-xs"
                htmlFor={`live-origin-${uid}`}
              >
                {p('fromCity')}
              </label>
              <Input
                id={`live-origin-${uid}`}
                value={origin}
                required
                minLength={2}
                maxLength={100}
                onChange={(event) => setOrigin(event.target.value)}
              />
            </div>
            <div>
              <label
                className="mb-2 block text-xs"
                htmlFor={`live-destination-${uid}`}
              >
                {p('toCity')}
              </label>
              <Input
                id={`live-destination-${uid}`}
                value={destination}
                required
                minLength={2}
                maxLength={100}
                onChange={(event) => setDestination(event.target.value)}
              />
            </div>
            <div>
              <label
                className="mb-2 block text-xs"
                htmlFor={`live-date-${uid}`}
              >
                {p('fieldDate')}
              </label>
              <Input
                id={`live-date-${uid}`}
                type="date"
                value={departureDate}
                required
                onChange={(event) => setDepartureDate(event.target.value)}
              />
            </div>
            <div>
              <label
                className="mb-2 block text-xs"
                htmlFor={`live-adults-${uid}`}
              >
                {p('adultTravelers')}
              </label>
              <Input
                id={`live-adults-${uid}`}
                type="number"
                min={1}
                max={9}
                value={adults}
                required
                onChange={(event) => setAdults(Number(event.target.value))}
              />
            </div>
            {ready && mode !== 'flight' && (
              <div>
                <label
                  className="mb-2 block text-xs"
                  htmlFor={`live-clock-${uid}`}
                >
                  {p('fieldStart')}
                </label>
                <Input
                  id={`live-clock-${uid}`}
                  type="time"
                  value={departureClock}
                  required
                  onChange={(event) => setDepartureClock(event.target.value)}
                />
              </div>
            )}
          </div>
          {mode === 'flight' && (
            <p className="text-sm text-ink-2">{p('flightTransferHelp')}</p>
          )}
          <div className="flex flex-wrap items-center gap-3">
            <Button disabled={disabled || busy || !validPublic} type="submit">
              {busy
                ? p('routeLoading')
                : ready
                  ? p('searchTransport')
                  : p('openLiveSearch')}
            </Button>
            {ready && validPublic && (
              <a
                href={publicUrl}
                target="_blank"
                rel="noreferrer"
                className="text-sm text-brand underline"
              >
                {mode === 'flight' ? 'Google Flights' : '12Go'}
              </a>
            )}
            {mode === 'train' && (
              <a
                href="https://www.12306.cn/en/index.html"
                target="_blank"
                rel="noreferrer"
                className="text-sm text-brand underline"
              >
                {p('checkChinaRail')}
              </a>
            )}
          </div>
          <p className="text-xs text-ink-3">
            {ready ? p('dayZone') + ' ' + timeZone : p('enterCheckedTimes')}
          </p>
          {mode === 'train' && (
            <p className="text-xs text-ink-3">{p('chinaRailHelp')}</p>
          )}
        </form>
        {error && (
          <p role="alert" className="text-sm text-warn">
            {error}
          </p>
        )}
        {results?.length === 0 && (
          <p role="status" className="text-sm text-ink-2">
            {p('liveNoResults')}
          </p>
        )}
        {results?.map((offer) => (
          <article key={offer.id} className="live-offer">
            <div className="flex flex-wrap justify-between gap-3">
              <div>
                <h5 className="font-semibold">
                  {offer.operator} {offer.service}
                </h5>
                <p className="mt-2 text-sm">
                  {clockFormat(offer.departure)} → {clockFormat(offer.arrival)}
                </p>
                <p className="mt-1 text-xs text-ink-2">
                  {offer.durationMinutes} {p('minutesUnit')} · {offer.source} ·{' '}
                  {new Date(offer.fetchedAt).toLocaleString()}
                </p>
              </div>
              <div>
                <p className="font-medium">
                  {offer.amount != null && offer.currency
                    ? formatMoney(offer.amount, offer.currency)
                    : p('fareUnavailable')}
                </p>
                {offer.priceScope === 'party' && (
                  <p className="mt-1 text-xs text-ink-3">
                    {p('priceParty')}: {offer.travelers}
                  </p>
                )}
              </div>
            </div>
            <ul className="my-3 space-y-1 text-xs text-ink-2">
              {offer.details.map((detail, index) => (
                <li key={index}>{detail}</li>
              ))}
            </ul>
            {offer.expiresAt && (
              <p className="mb-3 text-xs text-ink-3">
                {p('quoteExpiry')}: {clockFormat(offer.expiresAt)}
              </p>
            )}
            <Button
              type="button"
              variant="outline"
              disabled={
                disabled ||
                (!!offer.expiresAt && Date.parse(offer.expiresAt) < Date.now())
              }
              onClick={() => onChoose(offer)}
            >
              {p('useSchedule')}
            </Button>
            <p className="mt-3 text-xs text-ink-3">
              {offer.attributions.join(' · ')}
            </p>
          </article>
        ))}
        {results && results.length > 0 && (
          <p className="text-xs text-ink-2">{p('fareQuoteHelp')}</p>
        )}
      </div>
    </details>
  )
}
