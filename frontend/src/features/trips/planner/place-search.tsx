import { useId, useState } from 'react'
import { Search } from 'lucide-react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { importMapLink, searchPlaces } from '../maps.functions'
import type { SearchPlace } from '../maps.functions'
import { p } from './copy'

export function PlaceSearch({
  tripId,
  onChoose,
  disabled,
}: {
  tripId: string
  onChoose: (place: SearchPlace) => void
  disabled: boolean
}) {
  const inputId = useId()
  const [query, setQuery] = useState(''),
    [busy, setBusy] = useState(false),
    [results, setResults] = useState<Array<SearchPlace> | null>(null),
    [error, setError] = useState('')
  async function find() {
    if (busy) return
    setBusy(true)
    setError('')
    setResults(null)
    try {
      let search = query.trim()
      if (/^https?:\/\//i.test(search)) {
        const linked = await importMapLink({
          data: { tripId, url: search },
        })
        if (!linked.ok) {
          setError(p('mapLinkFailed'))
          return
        }
        if (linked.data.pin) {
          setResults([linked.data.pin])
          return
        }
        search = linked.data.query || ''
      }
      const response = await searchPlaces({
        data: { tripId, query: search },
      })
      if (response.ok) setResults(response.data)
      else setError(p('searchFailed'))
    } catch {
      setError(p('searchFailed'))
    } finally {
      setBusy(false)
    }
  }
  return (
    <div className="mb-5 space-y-3">
      <div className="flex items-end gap-2">
        <div className="min-w-0 flex-1">
          <label htmlFor={inputId} className="mb-2 block text-sm font-medium">
            {p('searchPlaces')}
          </label>
          <Input
            id={inputId}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={(event) => {
              if (event.key === 'Enter') {
                event.preventDefault()
                event.stopPropagation()
                if (query.trim().length >= 2 && !disabled) void find()
              }
            }}
            maxLength={4096}
            placeholder={p('placeOrMapLink')}
            aria-describedby={`${inputId}-help`}
            disabled={disabled || busy}
          />
        </div>
        <Button
          variant="outline"
          type="button"
          onClick={() => void find()}
          disabled={busy || disabled || query.trim().length < 2}
        >
          <Search />
          {busy ? p('routeLoading') : p('searchAction')}
        </Button>
      </div>
      <p id={`${inputId}-help`} className="text-xs text-ink-2">
        {p('mapLinkHelp')}
      </p>
      {error && (
        <p role="alert" className="text-sm text-warn">
          {error}
        </p>
      )}
      {results && (
        <div aria-live="polite">
          {results.length === 0 ? (
            <p className="text-sm text-ink-2">{p('searchEmpty')}</p>
          ) : (
            <ul className="planner-list">
              {results.map((place, index) => (
                <li key={index} className="planner-row">
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">{place.name}</p>
                    <p className="mt-1 text-xs text-ink-2">{place.address}</p>
                  </div>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    disabled={disabled}
                    onClick={() => onChoose(place)}
                  >
                    {p('actionSave')}
                  </Button>
                </li>
              ))}
            </ul>
          )}
          {results.some(
            (place) => place.source === 'google-maps-shared-pin',
          ) ? (
            <p className="mt-2 text-xs text-ink-3">
              {p('mapLinkConfirm')}{' '}
              <a
                className="underline"
                href={results[0]?.sourceUrl}
                target="_blank"
                rel="noreferrer"
              >
                {p('openGoogleMaps')}
              </a>
            </p>
          ) : (
            <p className="mt-2 text-xs text-ink-3">
              ©{' '}
              <a
                className="underline"
                href="https://www.openstreetmap.org/copyright"
                target="_blank"
                rel="noreferrer"
              >
                OpenStreetMap
              </a>{' '}
              · Nominatim
            </p>
          )}
        </div>
      )}
    </div>
  )
}
