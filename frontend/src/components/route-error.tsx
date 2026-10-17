import { Link, useRouter } from '@tanstack/react-router'
import { useQueryErrorResetBoundary } from '@tanstack/react-query'
import { useEffect } from 'react'
import type { ErrorComponentProps } from '@tanstack/react-router'
import { Button } from '#/components/ui/button'
import { isApiError } from '#/lib/api/problem'
import { m } from '#/paraglide/messages'
import { ProblemAlert } from './problem-alert'

/** Error boundary for routes: API problems get a friendly message and a retry. */
export function RouteError({ error }: ErrorComponentProps) {
  const router = useRouter()
  const reset = useQueryErrorResetBoundary()
  useEffect(() => reset.reset(), [reset])

  if (isApiError(error) && error.status === 404) {
    return (
      <div className="mx-auto max-w-md py-16 text-center">
        <p className="text-lg font-semibold">{m.trip_not_found()}</p>
        <Button asChild className="mt-6">
          <Link to="/trips">{m.back_to_trips()}</Link>
        </Button>
      </div>
    )
  }
  return (
    <div className="space-y-4">
      <ProblemAlert
        problem={
          isApiError(error) ? error.problem : { status: 500, code: 'internal' }
        }
      />
      <Button variant="outline" onClick={() => router.invalidate()}>
        {m.try_again()}
      </Button>
    </div>
  )
}
