import { useQuery } from '@tanstack/react-query'
import { m } from '#/paraglide/messages'
import { formatDate, formatMoney } from '#/lib/format'
import { unwrap } from '#/lib/api/problem'
import { getImportedPackage } from '../import.functions'
import { p } from '../planner/copy'

const rows = (value: unknown): Array<Record<string, unknown>> =>
  Array.isArray(value)
    ? value.filter(
        (r): r is Record<string, unknown> =>
          r !== null && typeof r === 'object' && !Array.isArray(r),
      )
    : []
function display(value: unknown, depth = 0): string {
  if (depth > 5) return '…'
  if (value == null || value === '') return '—'
  if (typeof value === 'boolean') return value ? '✓' : '—'
  if (Array.isArray(value))
    return value.map((v) => display(v, depth + 1)).join(', ')
  if (typeof value === 'object')
    return Object.values(value)
      .filter((v) => v != null)
      .map((v) => display(v, depth + 1))
      .join(' · ')
  return String(value)
}
function preview(section: string, row: Record<string, unknown>): string {
  const end =
    typeof row.end === 'string' &&
    typeof row.endDate === 'string' &&
    row.endDate !== row.date
      ? `${formatDate(row.endDate, 'short')} ${row.end}`
      : row.end
  const time =
    typeof row.start === 'string'
      ? [row.start, end].filter(Boolean).join(' – ')
      : null
  if (section === 'activities')
    return [
      time ?? m.import_untimed(),
      row.location ? display(row.location) : null,
    ]
      .filter(Boolean)
      .join(' · ')
  if (
    section === 'expenses' &&
    typeof row.amount === 'number' &&
    typeof row.currency === 'string'
  )
    return formatMoney(row.amount, row.currency)
  if (
    section === 'todos' &&
    typeof row.dueDate === 'string' &&
    /^\d{4}-\d{2}-\d{2}$/.test(row.dueDate)
  )
    return `${m.import_due()}: ${formatDate(row.dueDate)}`
  if (section === 'destinations') return display(row.country)
  if (section === 'exchangeRates')
    return `${m.import_rate()}: ${display(row.rate)}`
  return row.address ? display(row.address) : ''
}
// Only display raster images; archive names and MIME labels are untrusted.
function imageSource(bytes: string | undefined) {
  if (!bytes) return undefined
  const mime = bytes.startsWith('/9j/')
    ? 'image/jpeg'
    : bytes.startsWith('iVBORw0KGgo')
      ? 'image/png'
      : bytes.startsWith('UklGR')
        ? 'image/webp'
        : bytes.startsWith('R0lGOD')
          ? 'image/gif'
          : undefined
  return mime ? `data:${mime};base64,${bytes}` : undefined
}

export function ImportedPlan({ tripId }: { tripId: string }) {
  const query = useQuery({
    queryKey: ['trip', tripId, 'import'],
    queryFn: async () => unwrap(await getImportedPackage({ data: { tripId } })),
    staleTime: Infinity,
  })
  if (query.isPending)
    return (
      <p role="status" className="text-sm text-ink-3">
        {m.import_loading()}
      </p>
    )
  if (query.isError)
    return (
      <div role="alert" className="rounded-xl border p-4">
        <p>{m.import_load_error()}</p>
        <button className="mt-2 underline" onClick={() => void query.refetch()}>
          {m.import_retry()}
        </button>
      </div>
    )
  if (!query.data) return null
  const { documentJson, media } = query.data
  const d = JSON.parse(documentJson) as Record<string, unknown>
  const sections: Array<[string, string]> = [
    ['activities', m.import_activities()],
    ['todos', m.import_todos()],
    ['destinations', m.import_destinations()],
    ['expenses', m.import_expenses()],
    ['exchangeRates', m.import_rates()],
    ['places', m.import_places()],
  ]
  const labels: Record<string, string> = {
    title: m.field_title(),
    name: m.field_title(),
    date: m.import_date(),
    start: m.import_start(),
    end: m.import_end(),
    endDate: m.field_end_date(),
    kind: m.import_kind(),
    category: m.import_category(),
    location: m.import_location(),
    destination: m.import_destination(),
    cost: m.import_cost(),
    amount: m.import_cost(),
    currency: m.field_currency(),
    notes: m.import_notes(),
    dueDate: m.import_due(),
    isDone: m.import_done(),
    rate: m.import_rate(),
    source: m.import_rate_source(),
    city: m.import_city(),
    country: m.import_country(),
    address: m.import_address(),
    lat: m.import_lat(),
    lng: m.import_lng(),
    bookingStatus: m.import_booking(),
    provider: m.import_provider(),
    serviceNumber: m.import_service(),
    bookingReference: m.import_reference(),
    bookingUrl: m.import_booking_url(),
    isLocked: m.import_locked(),
    isOptional: m.import_optional(),
    isPaid: m.import_paid(),
    isShared: m.import_shared(),
    activityRef: m.import_activity_ref(),
    ref: m.import_activity_ref(),
  }
  const banner =
    d.banner && typeof d.banner === 'object'
      ? (d.banner as Record<string, unknown>)
      : null
  const photos = rows(d.photos)
  const cover =
    banner && typeof banner.image === 'string'
      ? imageSource(media[banner.image])
      : undefined
  const renderItems = (items: Array<Record<string, unknown>>, key: string) =>
    items.map((row, index) => (
      <details
        key={index}
        className="import-item min-w-0 rounded border border-border bg-surface"
      >
        <summary>
          <h3>
            {display(
              row.title ?? row.name ?? row.city ?? row.currency ?? index + 1,
            )}
          </h3>
          <span className="import-preview">{preview(key, row)}</span>
        </summary>
        <dl className="import-item-fields space-y-1 text-sm">
          {Object.entries(row)
            .filter(
              ([field, value]) =>
                field !== 'title' &&
                field !== 'name' &&
                value != null &&
                value !== '',
            )
            .map(([field, value]) => (
              <div
                key={field}
                className="grid grid-cols-[minmax(6rem,1fr)_2fr] gap-3"
              >
                <dt className="text-ink-3">
                  {labels[field] ?? field.replace(/([a-z])([A-Z])/g, '$1 $2')}
                </dt>
                <dd className="break-words whitespace-pre-wrap">
                  {field === 'source' && key === 'exchangeRates'
                    ? m.import_manual_rate()
                    : display(value)}
                </dd>
              </div>
            ))}
        </dl>
        {key === 'activities' && row.start == null && (
          <p className="px-4 pb-4 text-sm text-ink-3">{m.import_untimed()}</p>
        )}
      </details>
    ))
  function activityDays(items: Array<Record<string, unknown>>) {
    const days = new Map<string, Array<Record<string, unknown>>>()
    for (const row of items) {
      const day = typeof row.date === 'string' ? row.date : ''
      const activities = days.get(day) ?? []
      activities.push(row)
      days.set(day, activities)
    }
    return [...days]
      .sort(([a], [b]) => (a || '9999').localeCompare(b || '9999'))
      .map(([day, activities], index) => (
        <details key={day} className="import-day" open={index === 0}>
          <summary className="cursor-pointer py-3 text-sm font-semibold">
            {day ? formatDate(day) : m.dates_undecided()}
            <span className="ml-2 text-xs font-normal text-ink-3">
              ({activities.length})
            </span>
          </summary>
          <div className="space-y-2 pb-3">
            {renderItems(activities, 'activities')}
          </div>
        </details>
      ))
  }
  return (
    <section
      className="space-y-5 rounded-lg border bg-surface p-6"
      aria-labelledby="imported-plan-title"
    >
      <h2 id="imported-plan-title" className="text-xl font-bold">
        {m.import_plan()}
      </h2>
      <p className="text-sm text-ink-2">{p('originalScope')}</p>
      {cover && (
        <img
          src={cover}
          alt={m.import_cover()}
          className="max-h-80 w-full rounded-xl object-contain"
        />
      )}
      {sections.map(([key, title]) => {
        const items = rows(d[key])
        if (!items.length) return null
        return (
          <details
            key={key}
            className="rounded-lg border p-4"
            open={key === 'activities'}
          >
            <summary className="cursor-pointer font-semibold">
              {title} <span className="text-ink-3">({items.length})</span>
            </summary>
            <div
              className={
                key === 'activities'
                  ? 'mt-3 space-y-2'
                  : 'mt-3 grid gap-3 md:grid-cols-2'
              }
            >
              {key === 'activities'
                ? activityDays(items)
                : renderItems(items, key)}
            </div>
          </details>
        )
      })}
      {photos.length > 0 && (
        <details className="rounded-lg border p-4" open>
          <summary className="cursor-pointer font-semibold">
            {m.import_photos()} ({photos.length})
          </summary>
          <div className="mt-3 grid grid-cols-2 gap-3 md:grid-cols-3">
            {photos.map((photo, i) => {
              const src =
                typeof photo.file === 'string'
                  ? imageSource(media[photo.file])
                  : undefined
              return (
                <figure key={i} className="rounded-lg border p-2">
                  {src ? (
                    <img
                      src={src}
                      alt={
                        typeof photo.caption === 'string'
                          ? photo.caption
                          : m.import_photos()
                      }
                      loading="lazy"
                      className="h-40 w-full rounded object-contain"
                    />
                  ) : (
                    <p className="p-4 text-sm text-ink-3">
                      {m.import_image_unavailable()}
                    </p>
                  )}
                  {typeof photo.caption === 'string' && (
                    <figcaption className="mt-1 text-sm">
                      {photo.caption}
                    </figcaption>
                  )}
                </figure>
              )
            })}
          </div>
        </details>
      )}
    </section>
  )
}
