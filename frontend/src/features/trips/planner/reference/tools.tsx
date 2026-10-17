import { useState } from 'react'
import type { Trip } from '#/lib/api/types'
import type { PlanDocument } from '../model'
import { text } from '../model'
import { r } from './copy'
import { dateRange } from './domain'
import { AttractionLibrary } from './library'
import { PlanningCalendar } from './calendar'
import { BookingTools } from './bookings'
import { BudgetAnalysis, Insights } from './analysis'
import { Scenarios } from './scenarios'
import { ReportTools } from './report-tools'
import { MapTools } from './map-tools'
import { PlanningSettings } from './settings'

const views = [
  ['insights', 'nav.dashboard'],
  ['library', 'nav.attractions'],
  ['calendar', 'nav.itinerary'],
  ['bookings', 'nav.flights'],
  ['budget', 'nav.budget'],
  ['scenarios', 'nav.scenarios'],
  ['map', 'nav.map'],
  ['reports', 'nav.export'],
  ['settings', 'nav.settings'],
] as const
export function ReferenceTools({
  trip,
  document,
  disabled,
  onSave,
  onEdit,
  onAdd,
}: {
  trip: Trip
  document: PlanDocument
  disabled: boolean
  onSave: (doc: PlanDocument) => Promise<boolean>
  onEdit: (index: number) => void
  onAdd: (date: string) => void
}) {
  const [view, setView] = useState<(typeof views)[number][0]>('insights')
  const start =
    text(document.planningStartDate) ||
    trip.startDate ||
    text(document.activities.find((a) => a.date)?.date) ||
    new Date().toISOString().slice(0, 10)
  const end = text(document.planningEndDate) || trip.endDate || start,
    dates = dateRange(start, end),
    currency = trip.currency || 'THB',
    travelers = trip.travelerCount || 1
  return (
    <div className="reference-tools space-y-6">
      <label className="block max-w-sm text-sm font-medium">
        {r('nav.more')}
        <select
          className="planner-select mt-2 w-full"
          value={view}
          onChange={(e) => setView(e.target.value as typeof view)}
        >
          {views.map(([key, label]) => (
            <option value={key} key={key}>
              {r(label)}
            </option>
          ))}
        </select>
      </label>
      {view === 'insights' && (
        <Insights
          document={document}
          dates={dates}
          currency={currency}
          travelers={travelers}
        />
      )}
      {view === 'library' && (
        <AttractionLibrary
          tripId={trip.id}
          document={document}
          disabled={disabled}
          currency={currency}
          travelers={travelers}
          date={start}
          onSave={onSave}
        />
      )}
      {view === 'calendar' && (
        <PlanningCalendar
          document={document}
          dates={dates}
          disabled={disabled}
          currency={currency}
          onSave={onSave}
          onEdit={onEdit}
          onAdd={onAdd}
        />
      )}
      {view === 'bookings' && (
        <BookingTools
          document={document}
          dates={dates}
          currency={currency}
          travelers={travelers}
          zone={trip.timeZone || 'UTC'}
          disabled={disabled}
          onSave={onSave}
          onEdit={onEdit}
        />
      )}
      {view === 'budget' && (
        <BudgetAnalysis
          document={document}
          currency={currency}
          limit={trip.totalBudget || 0}
          disabled={disabled}
          onSave={onSave}
        />
      )}
      {view === 'scenarios' && (
        <Scenarios
          document={document}
          dates={dates}
          currency={currency}
          travelers={travelers}
          disabled={disabled}
          onSave={onSave}
        />
      )}
      {view === 'map' && (
        <MapTools
          tripId={trip.id}
          document={document}
          disabled={disabled}
          onSave={onSave}
        />
      )}
      {view === 'reports' && (
        <ReportTools
          tripId={trip.id}
          title={trip.title}
          document={document}
          dates={dates}
          currency={currency}
          limit={trip.totalBudget || 0}
          travelers={travelers}
        />
      )}
      {view === 'settings' && (
        <PlanningSettings
          tripId={trip.id}
          document={document}
          currency={currency}
          disabled={disabled}
          onSave={onSave}
        />
      )}
    </div>
  )
}
