import { CircleAlert, CloudOff } from 'lucide-react'
import { Alert, AlertDescription, AlertTitle } from '#/components/ui/alert'
import { m } from '#/paraglide/messages'
import type { Problem } from '#/lib/api/problem'

export function ProblemAlert({
  problem,
  title,
}: {
  problem: Problem
  title?: string
}) {
  const offline = problem.code === 'api.unavailable'
  return (
    <Alert variant="destructive" role="alert">
      {offline ? <CloudOff /> : <CircleAlert />}
      <AlertTitle>
        {title ?? (offline ? m.api_unavailable() : m.generic_error())}
      </AlertTitle>
      {(problem.detail || problem.requestId) && !offline && (
        <AlertDescription>
          {problem.detail && <p>{problem.detail}</p>}
          {problem.requestId && (
            <p className="text-xs opacity-80">
              {m.reference_id({ id: problem.requestId })}
            </p>
          )}
        </AlertDescription>
      )}
    </Alert>
  )
}
