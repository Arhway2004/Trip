import { Link } from '@tanstack/react-router'
import {
  ArrowUpRight,
  CalendarDays,
  Clock,
  PiggyBank,
  Users,
} from 'lucide-react'
import { formatDateRange, formatMoney } from '#/lib/format'
import { m } from '#/paraglide/messages'
import type { Trip } from '#/lib/api/types'
import { countdown, durationDays, tripStatus } from '../domain'
import { TripBanner } from './trip-banner'
import { StatusPill, countdownText } from './trip-status'

function Fact({
  icon: Icon,
  children,
}: {
  icon: typeof Clock
  children: React.ReactNode
}) {
  return (
    <span className="atlas-trip-fact">
      <Icon className="size-3.5" aria-hidden />
      {children}
    </span>
  )
}
export function TripCard({
  trip,
  now,
  index = 1,
}: {
  trip: Trip
  now: Date
  index?: number
}) {
  const status = tripStatus(trip, now),
    cd = countdown(trip, now),
    days = durationDays(trip)
  const travelers = trip.travelerCount ?? 1
  return (
    <Link
      to="/trips/$tripId"
      params={{ tripId: trip.id }}
      className="atlas-trip group"
    >
      <TripBanner tripId={trip.id}>
        <div className="atlas-trip-cover flex flex-col justify-between">
          <div className="flex items-center justify-between gap-3">
            <span className="atlas-trip-number">
              {m.atlas_journey()} / {String(index).padStart(2, '0')}
            </span>
            <StatusPill status={status} />
          </div>
          <h2 className="atlas-trip-title line-clamp-2">{trip.title}</h2>
        </div>
      </TripBanner>
      <div className="atlas-trip-body">
        <div className="flex items-center justify-between gap-4">
          <p className="text-sm font-semibold text-brand-strong">
            {countdownText(cd)}
          </p>
          <span className="atlas-arrow">
            <ArrowUpRight className="size-4" aria-hidden />
          </span>
        </div>
        <div className="atlas-trip-facts">
          <Fact icon={CalendarDays}>
            {formatDateRange(trip.startDate, trip.endDate) ??
              m.dates_undecided()}
          </Fact>
          {days != null && (
            <Fact icon={Clock}>
              {days === 1 ? m.one_day() : m.n_days({ count: days })}
            </Fact>
          )}
          <Fact icon={Users}>
            {travelers === 1
              ? m.one_traveler()
              : m.n_travelers({ count: travelers })}
          </Fact>
          {trip.totalBudget != null && trip.currency && (
            <Fact icon={PiggyBank}>
              {formatMoney(trip.totalBudget, trip.currency)}
            </Fact>
          )}
        </div>
      </div>
    </Link>
  )
}
