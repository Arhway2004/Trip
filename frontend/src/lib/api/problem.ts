// Client-safe error model. The Go API returns RFC 9457 problem details; server
// functions pass them to the browser as plain data inside a Result.

export interface FieldError {
  field: string
  message: string
}

export interface Problem {
  status: number
  code: string
  detail?: string
  errors?: Array<FieldError>
  requestId?: string
}

export type Result<T> = { ok: true; data: T } | { ok: false; problem: Problem }

export class ApiError extends Error {
  readonly problem: Problem

  constructor(problem: Problem) {
    super(problem.detail ?? problem.code)
    this.name = 'ApiError'
    this.problem = problem
  }

  get status() {
    return this.problem.status
  }
}

/** Throws ApiError for failed results (lets TanStack Query handle errors). */
export function unwrap<T>(result: Result<T>): T {
  if (!result.ok) throw new ApiError(result.problem)
  return result.data
}

export const isApiError = (e: unknown): e is ApiError => e instanceof ApiError

export const isStatus = (e: unknown, status: number) =>
  isApiError(e) && e.status === status

/** Maps field errors to { field: message } for forms. */
export function fieldErrors(
  problem: Problem | undefined,
): Record<string, string> {
  const out: Record<string, string> = {}
  for (const e of problem?.errors ?? []) out[e.field] ??= e.message
  return out
}

/** Builds a Problem from an API response body, tolerating non-problem bodies. */
export function toProblem(status: number, body: unknown): Problem {
  if (body && typeof body === 'object' && 'code' in body) {
    const b = body as Partial<Problem> & { status?: number }
    return {
      status: b.status ?? status,
      code: String(b.code),
      detail: b.detail,
      errors: b.errors,
      requestId: b.requestId,
    }
  }
  return { status, code: status >= 500 ? 'internal' : 'request.failed' }
}

export const unavailable: Problem = { status: 503, code: 'api.unavailable' }
