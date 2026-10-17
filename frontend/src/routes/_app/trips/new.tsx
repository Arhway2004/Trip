import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { toast } from 'sonner'
import { ProblemAlert } from '#/components/problem-alert'
import { TripForm } from '#/features/trips/components/trip-form'
import { emptyTripForm, toTripInput } from '#/features/trips/trip-schema'
import { createTrip } from '#/features/trips/trips.functions'
import { fieldErrors } from '#/lib/api/problem'
import type { Problem } from '#/lib/api/problem'
import { m } from '#/paraglide/messages'

export const Route = createFileRoute('/_app/trips/new')({
  // The default time zone comes from the browser, so this page renders on the client.
  ssr: false,
  head: () => ({ meta: [{ title: `${m.new_trip()} · WanderPlan` }] }),
  component: NewTrip,
})

function NewTrip() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [problem, setProblem] = useState<Problem>()
  const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <h1 className="atlas-title !text-5xl">{m.new_trip()}</h1>
      {problem && problem.status !== 422 && <ProblemAlert problem={problem} />}
      <TripForm
        initialValues={emptyTripForm(timeZone)}
        submitLabel={m.create()}
        serverErrors={fieldErrors(problem)}
        onSubmit={async (values) => {
          setProblem(undefined)
          const result = await createTrip({ data: toTripInput(values) })
          if (!result.ok) return setProblem(result.problem)
          queryClient.setQueryData(['trip', result.data.id], result.data)
          await queryClient.invalidateQueries({ queryKey: ['trips'] })
          toast.success(m.toast_created())
          await navigate({
            to: '/trips/$tripId',
            params: { tripId: result.data.id },
          })
        }}
      />
    </div>
  )
}
