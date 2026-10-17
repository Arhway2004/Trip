import { useRef, useState } from 'react'
import { Button } from '#/components/ui/button'
import { PlanMap } from '../plan-map'
import { point } from '../schedule'
import { records, text } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { nearbyPlaces } from '../../maps.functions'
import type { SearchPlace } from '../../maps.functions'
import { p } from '../copy'
import { r } from './copy'
import { object, upsert } from './domain'

export function MapTools({
  tripId,
  document,
  disabled,
  onSave,
}: {
  tripId: string
  document: PlanDocument
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
}) {
  const [layer, setLayer] = useState('all'),
    [selected, setSelected] = useState<string>(),
    [tile, setTile] = useState<'osm' | 'carto'>('osm'),
    [split, setSplit] = useState(55),
    [nearby, setNearby] = useState<Array<SearchPlace>>(),
    [category, setCategory] = useState<
      'attraction' | 'restaurant' | 'hotel' | 'airport' | 'railwayStation'
    >('attraction'),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [position, setPosition] = useState<PlanRow>()
  const mapRef = useRef<HTMLDivElement>(null)
  const places: Array<PlanRow & { number: number }> = [
    ...document.places
      .filter((row) => layer === 'all' || row.category === layer)
      .map((row) => ({ ...row, ref: 'place:' + text(row.ref) })),
    ...document.activities
      .filter(
        (row) =>
          row.bookingStatus !== 'cancelled' &&
          (layer === 'all' ||
            layer === 'planned' ||
            (layer === 'hotel' && row.kind === 'hotel')),
      )
      .flatMap((row) => {
        const at = point(row.location)
        return at
          ? [{ ...at, name: row.title, ref: 'activity:' + text(row.ref) }]
          : []
      }),
    ...(position ? [position] : []),
  ].map((row, index) => ({ ...row, number: index + 1 }))
  const active = places.find((row) => row.ref === selected) || places[0],
    center = point(active)
  const routes = records(document.connections)
    .filter((row) => Array.isArray(row.geometry))
    .map((row) => row.geometry as Array<[number, number]>)
  const navigation = center
    ? `https://www.google.com/maps/search/?api=1&query=${center.lat},${center.lng}`
    : undefined
  return (
    <section className="space-y-4">
      <div className="flex flex-wrap gap-3">
        <label className="text-sm">
          {r('map.layers')}
          <select
            className="planner-select"
            value={layer}
            onChange={(e) => setLayer(e.target.value)}
          >
            {[
              'all',
              'planned',
              'attraction',
              'restaurant',
              'hotel',
              'airport',
              'railwayStation',
            ].map((v) => (
              <option key={v} value={v}>
                {v === 'all'
                  ? r('c.all')
                  : v === 'planned'
                    ? r('nav.itinerary')
                    : p(
                        v === 'railwayStation'
                          ? 'placeRailwayStation'
                          : v === 'attraction'
                            ? 'placeAttraction'
                            : v === 'restaurant'
                              ? 'placeRestaurant'
                              : v === 'hotel'
                                ? 'placeHotel'
                                : 'placeAirport',
                      )}
              </option>
            ))}
          </select>
        </label>
        <label className="text-sm">
          {r('set.tiles')}
          <select
            className="planner-select"
            value={tile}
            onChange={(e) => setTile(e.target.value as typeof tile)}
          >
            <option value="osm">OpenStreetMap</option>
            <option value="carto">CARTO Voyager</option>
          </select>
        </label>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => {
            setBusy(true)
            setError('')
            navigator.geolocation.getCurrentPosition(
              (at) => {
                setPosition({
                  ref: 'current-position',
                  name: r('map.myLocation'),
                  lat: at.coords.latitude,
                  lng: at.coords.longitude,
                })
                setSelected('current-position')
                setBusy(false)
              },
              () => {
                setError(r('map.locFail'))
                setBusy(false)
              },
              { timeout: 10000 },
            )
          }}
        >
          {r('map.myLocation')}
        </Button>
        <Button
          variant="outline"
          onClick={async () => {
            try {
              const { captureMap } = await import('./reports')
              if (mapRef.current) await captureMap(mapRef.current)
            } catch {
              setError(r('c.saveError', { e: '' }))
            }
          }}
        >
          {r('ex.mapPng')}
        </Button>
      </div>
      <label className="hidden text-sm lg:block">
        {r('map.panel')}
        <input
          className="ml-3 align-middle"
          type="range"
          min={35}
          max={75}
          value={split}
          onChange={(e) => setSplit(Number(e.target.value))}
        />
      </label>
      <div
        className="reference-map-split"
        style={{ '--map-share': `${split}%` } as React.CSSProperties}
      >
        <div ref={mapRef}>
          <PlanMap
            key={tile}
            tileStyle={tile}
            places={places}
            routes={routes}
            selectedRef={selected}
            onSelect={setSelected}
            onPick={
              disabled
                ? undefined
                : (lat, lng) =>
                    void onSave(
                      upsert(document, 'places', {
                        ref: crypto.randomUUID(),
                        name: `${lat}, ${lng}`,
                        category: 'attraction',
                        lat,
                        lng,
                        verification: 'user',
                      }),
                    )
            }
          />
        </div>
        <ol className="max-h-[500px] space-y-2 overflow-auto">
          {places.map((row) => (
            <li key={text(row.ref)}>
              <button
                className={`w-full border-b border-border px-2 py-3 text-left text-sm ${selected === row.ref ? 'bg-brand-soft' : ''}`}
                onClick={() => setSelected(text(row.ref))}
              >
                {row.number}. {text(row.name)}
              </button>
            </li>
          ))}
        </ol>
      </div>
      {navigation && (
        <div className="flex flex-wrap gap-4 text-sm">
          <a
            className="underline"
            target="_blank"
            rel="noreferrer"
            href={navigation}
          >
            {p('openGoogleMaps')}
          </a>
          <a
            className="underline"
            target="_blank"
            rel="noreferrer"
            href={`https://www.openstreetmap.org/?mlat=${center!.lat}&mlon=${center!.lng}#map=16/${center!.lat}/${center!.lng}`}
          >
            OpenStreetMap
          </a>
          <a
            className="underline"
            target="_blank"
            rel="noreferrer"
            href={`https://uri.amap.com/marker?position=${center!.lng},${center!.lat}&name=${encodeURIComponent(text(active.name))}&coordinate=wgs84`}
          >
            Amap / 高德
          </a>
        </div>
      )}
      <div className="flex flex-wrap items-end gap-3">
        <label className="text-sm">
          {r('map.nearby')}
          <select
            className="planner-select"
            value={category}
            onChange={(e) => setCategory(e.target.value as typeof category)}
          >
            {[
              'attraction',
              'restaurant',
              'hotel',
              'airport',
              'railwayStation',
            ].map((v) => (
              <option key={v} value={v}>
                {p(
                  v === 'railwayStation'
                    ? 'placeRailwayStation'
                    : v === 'attraction'
                      ? 'placeAttraction'
                      : v === 'restaurant'
                        ? 'placeRestaurant'
                        : v === 'hotel'
                          ? 'placeHotel'
                          : 'placeAirport',
                )}
              </option>
            ))}
          </select>
        </label>
        <Button
          variant="outline"
          disabled={busy || !center}
          onClick={async () => {
            if (!center) return
            setBusy(true)
            setError('')
            try {
              const result = await nearbyPlaces({
                data: { tripId, center, category, radius: 1500 },
              })
              if (result.ok) setNearby(result.data)
              else setError(p('searchFailed'))
            } catch {
              setError(p('searchFailed'))
            } finally {
              setBusy(false)
            }
          }}
        >
          {busy ? p('routeLoading') : r('c.search')}
        </Button>
      </div>
      {nearby && (
        <ul className="planner-list">
          {nearby.map((row, i) => (
            <li key={i} className="planner-row">
              <span className="flex-1">{row.name}</span>
              <Button
                variant="outline"
                disabled={disabled}
                onClick={() =>
                  void onSave(upsert(document, 'places', { ...row, category }))
                }
              >
                {r('c.save')}
              </Button>
            </li>
          ))}
        </ul>
      )}
      {nearby && (
        <p className="text-xs text-ink-2">
          © OpenStreetMap contributors · Overpass
        </p>
      )}
      {error && (
        <p role="alert" className="text-sm text-warn">
          {error}
        </p>
      )}
      <Button
        variant="outline"
        disabled={disabled}
        onClick={() =>
          void onSave({
            ...document,
            mapSettings: {
              ...object(document.mapSettings),
              tileStyle: tile,
              split,
            },
          })
        }
      >
        {r('c.save')}
      </Button>
    </section>
  )
}
