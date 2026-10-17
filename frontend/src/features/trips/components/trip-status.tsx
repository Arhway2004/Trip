import {
  CalendarClock,
  CheckCircle2,
  Compass,
  Archive,
  PlaneTakeoff,
  Sparkles,
} from 'lucide-react'
import { cn } from '#/lib/utils'
import { m } from '#/paraglide/messages'
import type { Countdown, TripStatus } from '../domain'

const meta: Record<TripStatus, { label: () => string; icon: typeof Compass }> =
  {
    dreaming: { label: m.status_dreaming, icon: Sparkles },
    planning: { label: m.status_planning, icon: CalendarClock },
    upcoming: { label: m.status_upcoming, icon: PlaneTakeoff },
    traveling: { label: m.status_traveling, icon: Compass },
    completed: { label: m.status_completed, icon: CheckCircle2 },
    archived: { label: m.status_archived, icon: Archive },
  }

export const statusLabel = (s: TripStatus) => meta[s].label()

/** Compact, high-contrast status stamp for journey covers. */
export function StatusPill({
  status,
  className,
}: {
  status: TripStatus
  className?: string
}) {
  const { icon: Icon } = meta[status]
  return (
    <span className={cn('atlas-status', className)}>
      <Icon className="size-3.5" aria-hidden />
      {meta[status].label()}
    </span>
  )
}

export function countdownText(c: Countdown): string {
  switch (c.kind) {
    case 'none':
      return m.countdown_no_date()
    case 'completed':
      return m.countdown_completed()
    case 'during':
      return m.countdown_day_of({ day: c.day, total: c.total })
    case 'before':
      if (c.days === 0) return m.countdown_today()
      if (c.days === 1) return m.countdown_one_day()
      return m.countdown_days({ days: c.days })
  }
}
