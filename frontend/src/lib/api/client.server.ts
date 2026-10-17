import createClient from 'openapi-fetch'
import { serverEnv } from '#/lib/server/env.server'
import { toProblem, unavailable } from './problem'
import type { Result } from './problem'
import type { paths } from './schema'

/** Typed client for the Go API, generated from ../api/openapi.yaml. */
export function apiClient(token?: string) {
  const client = createClient<paths>({ baseUrl: serverEnv().API_BASE_URL })
  client.use({
    onRequest({ request }) {
      if (token) request.headers.set('Authorization', `Bearer ${token}`)
      request.headers.set(
        'X-Request-ID',
        crypto.randomUUID().replaceAll('-', '').slice(0, 16),
      )
      return request
    },
  })
  return client
}

export type ApiClient = ReturnType<typeof apiClient>

interface FetchOutcome<T> {
  data?: T
  error?: unknown
  response: Response
}

/**
 * Runs an API call and converts it into a Result. Network failures become a
 * 503 problem instead of an exception, so pages can show a friendly message.
 */
export async function call<T, TResult = T>(
  run: () => Promise<FetchOutcome<T>>,
  map: (data: T, response: Response) => TResult = (d) =>
    d as unknown as TResult,
): Promise<Result<TResult>> {
  let outcome: FetchOutcome<T>
  try {
    outcome = await run()
  } catch {
    return { ok: false, problem: unavailable }
  }
  const { data, error, response } = outcome
  if (!response.ok)
    return { ok: false, problem: toProblem(response.status, error) }
  return { ok: true, data: map(data as T, response) }
}

/** Parses a strong ETag like "3" into a version number. */
export function versionFromETag(response: Response): number | undefined {
  const tag = response.headers.get('ETag')
  const n = tag
    ? Number(tag.replace(/^W\//, '').replaceAll('"', ''))
    : Number.NaN
  return Number.isFinite(n) ? n : undefined
}
