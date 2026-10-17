import { useEffect, useRef, useState } from 'react'
import { p } from './copy'
import { text } from './model'
import type { PlanRow } from './model'

interface MapInstance {
  invalidateSize: (options: Record<string, unknown>) => MapInstance
  setView: (
    center: [number, number],
    zoom: number,
    options?: Record<string, unknown>,
  ) => MapInstance
  fitBounds: (
    points: Array<[number, number]>,
    options: Record<string, unknown>,
  ) => MapInstance
  on: (
    event: string,
    callback: (event: { latlng: { lat: number; lng: number } }) => void,
  ) => void
  remove: () => void
}
interface LayerGroup {
  addTo: (map: MapInstance) => LayerGroup
  clearLayers: () => void
}
interface Layer {
  addTo: (target: MapInstance | LayerGroup) => Layer
  bindPopup: (content: HTMLElement) => Layer
  on: (event: string, callback: () => void) => Layer
  getElement?: () => HTMLElement | undefined
  setZIndexOffset?: (offset: number) => Layer
}
interface Leaflet {
  map: (element: HTMLElement, options: Record<string, unknown>) => MapInstance
  layerGroup: () => LayerGroup
  tileLayer: (url: string, options: Record<string, unknown>) => Layer
  circleMarker: (
    point: [number, number],
    options: Record<string, unknown>,
  ) => Layer
  polyline: (
    points: Array<[number, number]>,
    options: Record<string, unknown>,
  ) => Layer
  marker: (point: [number, number], options: Record<string, unknown>) => Layer
  divIcon: (options: Record<string, unknown>) => unknown
}
declare global {
  interface Window {
    L?: Leaflet
  }
}
let loading: Promise<Leaflet> | undefined
function loadLeaflet() {
  if (window.L) return Promise.resolve(window.L)
  loading ??= new Promise<Leaflet>((resolve, reject) => {
    if (!document.querySelector('[data-plan-map-css]')) {
      const css = document.createElement('link')
      css.rel = 'stylesheet'
      css.href = '/vendor/leaflet.css'
      css.dataset.planMapCss = 'true'
      document.head.append(css)
    }
    const script = document.createElement('script')
    script.src = '/vendor/leaflet.js'
    script.onload = () =>
      window.L ? resolve(window.L) : reject(new Error('map'))
    script.onerror = () => {
      loading = undefined
      script.remove()
      reject(new Error('map'))
    }
    document.head.append(script)
  })
  return loading
}
function validLine(value: unknown): value is Array<[number, number]> {
  return (
    Array.isArray(value) &&
    value.length > 1 &&
    value.length <= 3000 &&
    value.every(
      (entry: unknown) =>
        Array.isArray(entry) &&
        entry.length === 2 &&
        typeof entry[0] === 'number' &&
        typeof entry[1] === 'number' &&
        Number.isFinite(entry[0]) &&
        Number.isFinite(entry[1]) &&
        Math.abs(entry[0]) <= 90 &&
        Math.abs(entry[1]) <= 180,
    )
  )
}
type MapPoint = [number, number, string, number | undefined, string | undefined]
export function PlanMap({
  places,
  routes = [],
  onPick,
  selectedRef,
  onSelect,
  tileStyle = 'osm',
}: {
  places: Array<PlanRow>
  routes?: Array<Array<[number, number]>>
  onPick?: (lat: number, lng: number) => void
  selectedRef?: string
  onSelect?: (ref: string) => void
  tileStyle?: 'osm' | 'carto'
}) {
  const element = useRef<HTMLDivElement>(null),
    map = useRef<MapInstance | undefined>(undefined),
    group = useRef<LayerGroup | undefined>(undefined),
    library = useRef<Leaflet | undefined>(undefined),
    markers = useRef<Array<{ row: MapPoint; layer: Layer }>>([])
  const pick = useRef(onPick),
    select = useRef(onSelect),
    active = useRef(selectedRef)
  pick.current = onPick
  select.current = onSelect
  active.current = selectedRef
  const [ready, setReady] = useState(false),
    [failed, setFailed] = useState(false),
    [tilesLoading, setTilesLoading] = useState(true),
    [tileError, setTileError] = useState(false)
  const signature = JSON.stringify(
    places
      .filter(
        (row) =>
          typeof row.lat === 'number' &&
          typeof row.lng === 'number' &&
          Math.abs(row.lat) <= 90 &&
          Math.abs(row.lng) <= 180,
      )
      .map((row) => [row.lat, row.lng, row.name, row.number, row.ref]),
  )
  const routeSignature = JSON.stringify(routes)
  const bounds = useRef<Array<[number, number]>>([])
  useEffect(() => {
    let disposed = false,
      instance: MapInstance | undefined,
      resize: ResizeObserver | undefined
    void loadLeaflet()
      .then((L) => {
        if (disposed || !element.current) return
        library.current = L
        instance = L.map(element.current, {
          scrollWheelZoom: false,
          zoomAnimation: false,
          fadeAnimation: false,
          markerZoomAnimation: false,
        }).setView([20, 0], 2)
        map.current = instance
        resize = new ResizeObserver(() => {
          if (
            !instance ||
            disposed ||
            !element.current?.clientWidth ||
            !element.current.clientHeight
          )
            return
          instance.invalidateSize({ pan: false })
          const positions = bounds.current
          if (positions.length)
            instance.fitBounds(positions, {
              padding: [30, 30],
              maxZoom: 16,
              animate: false,
            })
        })
        resize.observe(element.current)
        L.tileLayer(
          tileStyle === 'carto'
            ? 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          {
            maxZoom: 19,
            crossOrigin: 'anonymous',
            attribution:
              '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors' +
              (tileStyle === 'carto'
                ? ' · &copy; <a href="https://carto.com/attribution/">CARTO</a>'
                : ''),
          },
        )
          .on('loading', () => {
            if (!disposed) setTilesLoading(true)
          })
          .on('load', () => {
            if (!disposed) setTilesLoading(false)
          })
          .on('tileerror', () => {
            if (!disposed) setTileError(true)
          })
          .addTo(instance)
        group.current = L.layerGroup().addTo(instance)
        instance.on('click', (event) =>
          pick.current?.(
            Number(event.latlng.lat.toFixed(6)),
            Number(event.latlng.lng.toFixed(6)),
          ),
        )
        setReady(true)
      })
      .catch(() => {
        if (!disposed) setFailed(true)
      })
    return () => {
      disposed = true
      resize?.disconnect()
      instance?.remove()
      map.current = undefined
      group.current = undefined
    }
  }, [])
  useEffect(() => {
    const L = library.current,
      instance = map.current,
      layers = group.current
    if (!ready || !L || !instance || !layers) return
    layers.clearLayers()
    markers.current = []
    const positions: Array<[number, number]> = []
    for (const line of JSON.parse(routeSignature) as Array<unknown>)
      if (validLine(line)) {
        positions.push(...line)
        L.polyline(line, { color: '#245c46', weight: 4, opacity: 0.8 }).addTo(
          layers,
        )
      }
    for (const row of JSON.parse(signature) as Array<MapPoint>) {
      const position: [number, number] = [row[0], row[1]]
      positions.push(position)
      const label = document.createElement('span')
      label.textContent = text(row[2])
      let marker: Layer
      if (row[3] != null) {
        const badge = document.createElement('span')
        badge.textContent = String(row[3])
        marker = L.marker(position, {
          icon: L.divIcon({
            html: badge,
            className: `plan-stop-marker${row[4] === active.current ? ' is-selected' : ''}`,
            iconSize: [30, 30],
            iconAnchor: [15, 15],
          }),
          title: text(row[2]),
          alt: text(row[2]),
          keyboard: true,
          zIndexOffset: row[4] === active.current ? 1000 : 0,
        })
          .addTo(layers)
          .bindPopup(label)
        if (row[4]) marker.on('click', () => select.current?.(row[4]!))
      } else
        marker = L.circleMarker(position, {
          radius: 8,
          color: '#245c46',
          fillOpacity: 0.85,
          weight: 2,
          bubblingMouseEvents: false,
        })
          .addTo(layers)
          .bindPopup(label)
      markers.current.push({ row, layer: marker })
    }
    bounds.current = positions
    if (positions.length)
      instance.fitBounds(positions, {
        padding: [30, 30],
        maxZoom: 16,
        animate: false,
      })
  }, [ready, signature, routeSignature])
  useEffect(() => {
    if (!ready) return
    for (const marker of markers.current) {
      marker.layer
        .getElement?.()
        ?.classList.toggle('is-selected', marker.row[4] === selectedRef)
      marker.layer.setZIndexOffset?.(marker.row[4] === selectedRef ? 1000 : 0)
    }
    const selected = selectedRef
      ? markers.current.find((marker) => marker.row[4] === selectedRef)
      : undefined
    if (selected)
      map.current?.setView([selected.row[0], selected.row[1]], 14, {
        animate: false,
      })
  }, [ready, selectedRef, signature])
  return (
    <div className="space-y-2">
      <div
        ref={element}
        className="plan-map"
        role="region"
        aria-label={p('tabMap')}
      />
      {failed && (
        <p role="status" className="text-sm text-warn">
          {p('mapError')}
        </p>
      )}
      {!failed && tilesLoading && (
        <p role="status" className="text-xs text-ink-3">
          {p('loadingMap')}
        </p>
      )}
      {!failed && tileError && (
        <p role="status" className="text-xs text-warn">
          {p('mapTilesError')}
        </p>
      )}
      <p className="text-xs text-ink-3">
        {onPick ? p('mapHint') : p('routeHelp')}
      </p>
      {routes.length > 0 && (
        <p className="text-xs text-ink-3">
          <a
            className="underline"
            href="https://routing.openstreetmap.de/about.html"
            target="_blank"
            rel="noreferrer"
          >
            OSRM · FOSSGIS · OpenStreetMap
          </a>{' '}
          ·{' '}
          <a
            className="underline"
            href="https://www.openstreetmap.org/fixthemap"
            target="_blank"
            rel="noreferrer"
          >
            OpenStreetMap: report a map issue
          </a>
        </p>
      )}
    </div>
  )
}
