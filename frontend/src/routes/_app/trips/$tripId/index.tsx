import {
  useQuery,
  useQueryClient,
  useSuspenseQuery,
} from '@tanstack/react-query'
import { Link, createFileRoute, useNavigate } from '@tanstack/react-router'
import {
  Archive,
  ArchiveRestore,
  CalendarDays,
  Clock,
  Globe2,
  Pencil,
  PiggyBank,
  Trash2,
  Users,
} from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'
import { RouteError } from '#/components/route-error'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '#/components/ui/alert-dialog'
import { Button } from '#/components/ui/button'
import { PlanWorkspace } from '#/features/trips/planner/workspace'
import { planQuery, parseDocument } from '#/features/trips/planner/model'
import type { PlanRow } from '#/features/trips/planner/model'
import { TripBanner } from '#/features/trips/components/trip-banner'
import {
  StatusPill,
  countdownText,
} from '#/features/trips/components/trip-status'
import { countdown, durationDays, tripStatus } from '#/features/trips/domain'
import { membersQuery, tripQuery } from '#/features/trips/queries'
import { tripToInput } from '#/features/trips/trip-schema'
import { deleteTrip, updateTrip } from '#/features/trips/trips.functions'
import { formatDateRange, formatMoney } from '#/lib/format'
import { useNow } from '#/lib/use-now'
import type { Role, Trip } from '#/lib/api/types'
import { m } from '#/paraglide/messages'

export const Route = createFileRoute('/_app/trips/$tripId/')({
  loader: async ({ context, params }) => {
    await Promise.all([
      context.queryClient.ensureQueryData(tripQuery(params.tripId)),
      context.queryClient.ensureQueryData(membersQuery(params.tripId)),
    ])
  },
  errorComponent: RouteError,
  component: TripPage,
})

const roleLabel: Record<Role, () => string> = {
  owner: m.role_owner,
  editor: m.role_editor,
  viewer: m.role_viewer,
}

function Kpi({
  icon: Icon,
  label,
  value,
  sub,
}: {
  icon: typeof Clock
  label: string
  value: string
  sub?: string
}) {
  return (
    <div className="atlas-kpi">
      <div className="flex items-center gap-1.5 text-xs font-semibold text-ink-3">
        <Icon className="size-3.5" aria-hidden /> {label}
      </div>
      <div className="atlas-kpi-value">{value}</div>
      {sub && <div className="truncate text-xs text-ink-2">{sub}</div>}
    </div>
  )
}

function TripPage() {
  const { tripId } = Route.useParams()
  const { user } = Route.useRouteContext()
  const { data: trip } = useSuspenseQuery(tripQuery(tripId))
  const { data: members } = useSuspenseQuery(membersQuery(tripId))
  const { data: plan } = useQuery(planQuery(tripId))
  const banner = plan
    ? (parseDocument(plan.documentJson).banner as PlanRow | undefined)
    : undefined
  const now = useNow()
  const status = tripStatus(trip, now)
  const cd = countdown(trip, now)
  const days = durationDays(trip)
  const travelers = trip.travelerCount ?? 1
  const canEdit = trip.role === 'owner' || trip.role === 'editor'

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Link to="/trips" className="text-sm text-ink-2 hover:text-brand">
          ← {m.back_to_trips()}
        </Link>
        {canEdit && <TripActions trip={trip} />}
      </div>
      {banner?.showTitle === false && (
        <h1 className="atlas-detail-title">{trip.title}</h1>
      )}
      <TripBanner
        tripId={trip.id}
        banner={banner}
        media={plan?.media}
        className="rounded-lg"
      >
        <div className="flex min-h-[264px] flex-col justify-between gap-8 p-6 sm:min-h-80 sm:p-8">
          <div className="flex items-center justify-between gap-3">
            <span className="atlas-trip-number">{m.atlas_journey()}</span>
            <StatusPill status={status} />
          </div>
          {banner?.showTitle !== false && (
            <h1 className="atlas-detail-title max-w-3xl">{trip.title}</h1>
          )}
        </div>
      </TripBanner>
      <div className="atlas-departure">
        <Clock className="size-6 shrink-0 text-brand" aria-hidden />
        <div>
          <p className="atlas-departure-value">{countdownText(cd)}</p>
          <p className="mt-1 text-xs text-ink-2">
            {formatDateRange(trip.startDate, trip.endDate) ??
              m.dates_undecided()}
          </p>
        </div>
      </div>

      <div className="atlas-kpis">
        <Kpi
          icon={CalendarDays}
          label={m.section_dates()}
          value={
            formatDateRange(trip.startDate, trip.endDate) ?? m.dates_undecided()
          }
          sub={
            trip.startDate && !trip.datesConfirmed
              ? m.dates_flexible()
              : undefined
          }
        />
        <Kpi
          icon={Clock}
          label={m.kpi_duration()}
          value={
            days == null
              ? '—'
              : days === 1
                ? m.one_day()
                : m.n_days({ count: days })
          }
        />
        <Kpi icon={Users} label={m.kpi_travelers()} value={String(travelers)} />
        <Kpi
          icon={PiggyBank}
          label={m.kpi_budget()}
          value={
            trip.totalBudget != null && trip.currency
              ? formatMoney(trip.totalBudget, trip.currency)
              : '—'
          }
          sub={
            trip.totalBudget != null && trip.currency && travelers > 1
              ? m.per_person({
                  amount: formatMoney(
                    trip.totalBudget / travelers,
                    trip.currency,
                  ),
                })
              : trip.totalBudget == null
                ? m.budget_not_set()
                : undefined
          }
        />
      </div>

      <PlanWorkspace trip={trip} />

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-[2fr_1fr]">
        <section className="min-w-0 space-y-4 rounded-lg border bg-surface p-6">
          <h2 className="font-bold">{m.overview()}</h2>
          <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm">
            <dt className="flex items-center gap-1.5 text-ink-3">
              <Globe2 className="size-4" aria-hidden /> {m.time_zone()}
            </dt>
            <dd>{trip.timeZone}</dd>
            {trip.departureTime && (
              <>
                <dt className="text-ink-3">{m.field_departure_time()}</dt>
                <dd>{trip.departureTime}</dd>
              </>
            )}
          </dl>
          {trip.description && (
            <p className="border-t pt-3 text-ink-2">{trip.description}</p>
          )}
        </section>

        <section className="min-w-0 space-y-4 rounded-lg border bg-surface p-6">
          <h2 className="font-bold">{m.members()}</h2>
          <ul className="space-y-2">
            {members.map((mem) => (
              <li
                key={mem.userId}
                className="flex items-center justify-between gap-2 text-sm"
              >
                <span className="truncate font-mono text-xs text-ink-2">
                  {mem.userId === user.id
                    ? `${user.displayName || user.email} (${m.you()})`
                    : mem.userId.slice(0, 8)}
                </span>
                <span className="rounded-full bg-brand-soft px-2 py-0.5 text-xs font-semibold text-brand-strong">
                  {roleLabel[mem.role]()}
                </span>
              </li>
            ))}
          </ul>
        </section>
      </div>
    </div>
  )
}

function TripActions({ trip }: { trip: Trip }) {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [busy, setBusy] = useState(false)

  async function refresh() {
    await queryClient.invalidateQueries({ queryKey: ['trip', trip.id] })
    await queryClient.invalidateQueries({ queryKey: ['trips'] })
  }

  async function toggleArchive() {
    setBusy(true)
    const result = await updateTrip({
      data: {
        tripId: trip.id,
        version: trip.version,
        input: { ...tripToInput(trip), archived: !trip.archived },
      },
    })
    setBusy(false)
    if (!result.ok) {
      toast.error(
        result.problem.status === 412 ? m.conflict_title() : m.generic_error(),
      )
      return refresh()
    }
    queryClient.setQueryData(['trip', trip.id], result.data)
    toast.success(m.toast_saved())
    await queryClient.invalidateQueries({ queryKey: ['trips'] })
  }

  async function remove() {
    setBusy(true)
    const result = await deleteTrip({
      data: { tripId: trip.id, version: trip.version },
    })
    setBusy(false)
    if (!result.ok) {
      toast.error(
        result.problem.status === 412 ? m.conflict_title() : m.generic_error(),
      )
      return refresh()
    }
    queryClient.removeQueries({ queryKey: ['trip', trip.id] })
    await queryClient.invalidateQueries({ queryKey: ['trips'] })
    toast.success(m.toast_deleted())
    await navigate({ to: '/trips' })
  }

  const glass =
    'border-border bg-surface text-ink hover:bg-brand-soft hover:text-brand-strong'
  return (
    <div className="flex flex-wrap justify-end gap-2">
      <Button asChild variant="outline" size="sm" className={glass}>
        <Link to="/trips/$tripId/edit" params={{ tripId: trip.id }}>
          <Pencil /> {m.edit()}
        </Link>
      </Button>
      <Button
        variant="outline"
        size="sm"
        className={glass}
        disabled={busy}
        onClick={toggleArchive}
      >
        {trip.archived ? <ArchiveRestore /> : <Archive />}
        {trip.archived ? m.unarchive() : m.archive()}
      </Button>
      {trip.role === 'owner' && (
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className={glass}
              disabled={busy}
            >
              <Trash2 /> {m.delete()}
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>{m.delete_confirm_title()}</AlertDialogTitle>
              <AlertDialogDescription>
                {m.delete_confirm_body({ title: trip.title })}
              </AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>{m.cancel()}</AlertDialogCancel>
              <AlertDialogAction
                className="bg-bad text-white hover:bg-bad/90"
                onClick={remove}
              >
                {m.delete()}
              </AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      )}
    </div>
  )
}
