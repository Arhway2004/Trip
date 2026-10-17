import { useSuspenseQuery } from '@tanstack/react-query'
import { Link, createFileRoute } from '@tanstack/react-router'
import { Plus, Search, X } from 'lucide-react'
import { useState } from 'react'
import { Input } from '#/components/ui/input'
import { z } from 'zod'
import { RouteError } from '#/components/route-error'
import { Button } from '#/components/ui/button'
import { ImportTrip } from '#/features/trips/components/import-trip'
import { TripCard } from '#/features/trips/components/trip-card'
import { matchesFilter, tripFilters, tripStatus } from '#/features/trips/domain'
import type { TripFilter } from '#/features/trips/domain'
import { tripsQuery } from '#/features/trips/queries'
import { useNow } from '#/lib/use-now'
import { RouteArtwork } from '#/components/atlas-art'
import { m } from '#/paraglide/messages'

const search = z.object({
  filter: z.enum(tripFilters).optional().catch(undefined),
})

const filterLabel: Record<TripFilter, () => string> = {
  all: m.filter_all,
  upcoming: m.filter_upcoming,
  traveling: m.filter_traveling,
  completed: m.filter_completed,
  archived: m.filter_archived,
}

export const Route = createFileRoute('/_app/trips/')({
  validateSearch: (s) => search.parse(s),
  loaderDeps: ({ search: { filter } }) => ({
    includeArchived: filter === 'archived',
  }),
  loader: ({ context, deps }) =>
    context.queryClient.ensureQueryData(tripsQuery(deps.includeArchived)),
  head: () => ({ meta: [{ title: `${m.trips_title()} · WanderPlan` }] }),
  errorComponent: RouteError,
  component: TripsPage,
})

function TripsPage() {
  const filter = Route.useSearch().filter ?? 'all'
  const { data: trips } = useSuspenseQuery(tripsQuery(filter === 'archived'))
  const now = useNow()
  const [searchText, setSearchText] = useState('')
  const query = searchText.trim().toLocaleLowerCase()
  const visible = trips.filter(
    (t) =>
      matchesFilter(tripStatus(t, now), filter) &&
      t.title.toLocaleLowerCase().includes(query),
  )

  return (
    <div>
      <div className="atlas-heading">
        <div>
          <p className="atlas-eyebrow">{m.atlas_eyebrow()}</p>
          <h1 className="atlas-title">{m.trips_title()}</h1>
          <p className="text-sm text-ink-2">{m.atlas_subtitle()}</p>
        </div>
        <div className="atlas-heading-aside">
          <p className="atlas-collection">
            {m.atlas_collection({
              count: trips.filter((t) => !t.archived).length,
            })}
          </p>
          <div className="atlas-heading-actions flex gap-3">
            <ImportTrip />
            <Button asChild size="lg">
              <Link to="/trips/new">
                <Plus /> {m.create_trip()}
              </Link>
            </Button>
          </div>
        </div>
      </div>
      {trips.length > 0 && (
        <div className="trip-search">
          <Search aria-hidden />
          <Input
            aria-label={m.search_trips()}
            placeholder={m.search_trips()}
            value={searchText}
            onChange={(e) => setSearchText(e.target.value)}
          />
          {searchText && (
            <Button
              type="button"
              variant="ghost"
              size="icon"
              className="absolute right-0 top-0"
              aria-label={m.clear_search()}
              onClick={() => setSearchText('')}
            >
              <X />
            </Button>
          )}
        </div>
      )}
      <nav className="atlas-filters" aria-label={m.atlas_filters()}>
        {tripFilters.map((f) => (
          <Link
            key={f}
            to="/trips"
            search={f === 'all' ? {} : { filter: f }}
            className="atlas-filter"
            aria-current={f === filter ? 'page' : undefined}
          >
            {filterLabel[f]()}
            <span className="atlas-filter-count">
              {trips.filter((t) => matchesFilter(tripStatus(t, now), f)).length}
            </span>
          </Link>
        ))}
      </nav>

      {trips.length === 0 ? (
        <EmptyState />
      ) : visible.length === 0 ? (
        <div role="status" className="py-12 text-center text-ink-3">
          <p>{query ? m.search_no_results() : m.empty_filter()}</p>
          {query && (
            <Button
              className="mt-3"
              variant="outline"
              onClick={() => setSearchText('')}
            >
              {m.clear_search()}
            </Button>
          )}
        </div>
      ) : (
        <div className="atlas-trip-grid">
          {visible.map((t, i) => (
            <TripCard key={t.id} trip={t} now={now} index={i + 1} />
          ))}
        </div>
      )}
    </div>
  )
}

function EmptyState() {
  return (
    <div className="atlas-empty">
      <div className="atlas-empty-art">
        <RouteArtwork />
        <p className="atlas-trip-number">WANDERPLAN / 01</p>
      </div>
      <div className="atlas-empty-copy">
        <p className="atlas-eyebrow mb-3">{m.atlas_begin()}</p>
        <h2 className="atlas-empty-title">{m.empty_title()}</h2>
        <p className="mb-6 max-w-sm text-sm leading-relaxed text-ink-2">
          {m.empty_body()}
        </p>
        <Button asChild>
          <Link to="/trips/new">
            <Plus />
            {m.create_trip()}
          </Link>
        </Button>
      </div>
    </div>
  )
}
