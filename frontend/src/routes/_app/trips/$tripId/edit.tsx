import { useQueryClient, useSuspenseQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { RefreshCw } from 'lucide-react'
import { useState } from 'react'
import { toast } from 'sonner'
import { ProblemAlert } from '#/components/problem-alert'
import { RouteError } from '#/components/route-error'
import { Alert, AlertDescription, AlertTitle } from '#/components/ui/alert'
import { Button } from '#/components/ui/button'
import { TripForm } from '#/features/trips/components/trip-form'
import { tripQuery } from '#/features/trips/queries'
import { toTripInput, tripToForm } from '#/features/trips/trip-schema'
import { updateTrip } from '#/features/trips/trips.functions'
import { fieldErrors } from '#/lib/api/problem'
import type { Problem } from '#/lib/api/problem'
import { m } from '#/paraglide/messages'

export const Route = createFileRoute('/_app/trips/$tripId/edit')({
  loader: ({ context, params }) =>
    context.queryClient.ensureQueryData(tripQuery(params.tripId)),
  head: () => ({ meta: [{ title: `${m.edit_trip()} · WanderPlan` }] }),
  errorComponent: RouteError,
  component: EditTrip,
})

function EditTrip() {
  const { tripId } = Route.useParams()
  const { data: trip, refetch } = useSuspenseQuery(tripQuery(tripId))
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [problem, setProblem] = useState<Problem>()
  const conflict = problem?.status === 412

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <h1 className="atlas-title !text-5xl">{m.edit_trip()}</h1>
      {conflict && (
        <Alert className="border-warn/40 bg-warn-bg text-warn" role="alert">
          <AlertTitle>{m.conflict_title()}</AlertTitle>
          <AlertDescription className="text-warn">
            <p>{m.conflict_body()}</p>
            <Button
              variant="outline"
              size="sm"
              className="mt-2"
              onClick={async () => {
                await refetch()
                setProblem(undefined)
              }}
            >
              <RefreshCw /> {m.reload_latest()}
            </Button>
          </AlertDescription>
        </Alert>
      )}
      {problem && !conflict && problem.status !== 422 && (
        <ProblemAlert problem={problem} />
      )}
      <TripForm
        // Remount on a new version so "load latest" replaces the form values.
        key={trip.version}
        initialValues={tripToForm(trip)}
        submitLabel={m.save_changes()}
        showArchived
        serverErrors={fieldErrors(problem)}
        onSubmit={async (values) => {
          setProblem(undefined)
          const result = await updateTrip({
            data: { tripId, version: trip.version, input: toTripInput(values) },
          })
          if (!result.ok) return setProblem(result.problem)
          queryClient.setQueryData(['trip', tripId], result.data)
          await queryClient.invalidateQueries({ queryKey: ['trips'] })
          toast.success(m.toast_saved())
          await navigate({ to: '/trips/$tripId', params: { tripId } })
        }}
      />
    </div>
  )
}
