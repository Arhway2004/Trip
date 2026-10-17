import { createServerFn } from '@tanstack/react-start'
import { z } from 'zod'
import { getSessionToken } from '#/features/auth/session.server'
import { apiClient, call } from '#/lib/api/client.server'
import type { Result } from '#/lib/api/problem'
import type { PlanDocument } from './planner/model'
import type { Trip } from '#/lib/api/types'
import { convertReference } from './planner/reference/import'

export const MAX_IMPORT_BYTES = 20 * 1024 * 1024
const signedOut = {
  ok: false as const,
  problem: { status: 401, code: 'auth.missing_token' },
}

export interface ImportedPackage {
  documentJson: string
  media: Record<string, string>
}

export const importTrip = createServerFn({ method: 'POST' })
  .validator((data: FormData) => data)
  .handler(async ({ data }): Promise<Result<Trip>> => {
    const token = getSessionToken()
    if (!token) return signedOut
    const file = data.get('file')
    if (!(file instanceof Blob) || file.size === 0)
      return { ok: false, problem: { status: 422, code: 'import.empty' } }
    if (file.size > 100 * 1024 * 1024)
      return { ok: false, problem: { status: 413, code: 'import.too_large' } }
    // Recognize the earlier Reference app's JSON before handing mobile ZIPs
    // and ordinary WanderPlan JSON to the existing Go importer.
    let converted
    try {
      const prefix = await file.slice(0, 32).text()
      if (prefix.trimStart().startsWith('{')) {
        const raw = JSON.parse(await file.text()) as Record<string, unknown>
        if (raw.format === 'wanderplan.backup') {
          if (
            raw.schemaVersion !== 1 ||
            !Array.isArray(raw.trips) ||
            !raw.trips.length ||
            raw.trips.length > 100
          )
            throw new Error('Invalid backup: use 1–100 trips')
          converted = raw.trips.map((value: unknown) => {
            if (!value || typeof value !== 'object')
              throw new Error('Invalid backup entry')
            const entry = value as { document?: unknown; media?: unknown }
            if (
              !entry.document ||
              typeof entry.document !== 'object' ||
              Array.isArray(entry.document)
            )
              throw new Error('Invalid backup document')
            const media = entry.media || {}
            if (
              typeof media !== 'object' ||
              Array.isArray(media) ||
              Object.values(media).some(
                (v) =>
                  typeof v !== 'string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(v),
              )
            )
              throw new Error('Invalid backup media')
            return {
              document:
                entry.document as PlanDocument,
              media: media as Record<string, string>,
            }
          })
        } else converted = convertReference(raw)
      }
    } catch (error) {
      return {
        ok: false,
        problem: {
          status: 422,
          code: 'import.invalid_reference',
          detail: error instanceof Error ? error.message : 'Invalid JSON',
        },
      }
    }
    if (converted) {
      const created: Array<Trip> = []
      try {
        for (const entry of converted) {
          const original = entry.document,
            banner = original.banner as Record<string, unknown> | undefined
          const initial = Object.keys(entry.media).length
            ? {
                ...original,
                photos: [],
                banner: banner
                  ? {
                      ...banner,
                      image: undefined,
                      kind: banner.kind === 'photo' ? 'solid' : banner.kind,
                    }
                  : undefined,
              }
            : original
          const result = await call(() =>
            apiClient(token).POST('/v1/trips/import', {
              body: '',
              bodySerializer: () => JSON.stringify(initial),
              headers: { 'Content-Type': 'application/json' },
            }),
          )
          if (!result.ok)
            throw new Error(result.problem.detail || 'Reference import failed')
          created.push(result.data)
          if (Object.keys(entry.media).length) {
            const restored = await call(() =>
              apiClient(token).PUT('/v1/trips/{tripId}/plan', {
                params: {
                  path: { tripId: result.data.id },
                  header: { 'If-Match': '"0"' },
                },
                body: { document: original, media: entry.media },
              }),
            )
            if (!restored.ok)
              throw new Error(
                restored.problem.detail || 'Backup restore failed',
              )
          }
        }
        return { ok: true, data: created[0] }
      } catch (error) {
        // Roll back only trips created by this import, never pre-existing data.
        const cleanup = await Promise.allSettled(
          created.map((trip) =>
            apiClient(token).DELETE('/v1/trips/{tripId}', {
              params: { path: { tripId: trip.id } },
            }),
          ),
        )
        const incomplete = cleanup.some(
          (item) => item.status === 'rejected' || item.value.error,
        )
        return {
          ok: false,
          problem: {
            status: 422,
            code: 'import.reference_failed',
            detail:
              (error instanceof Error
                ? error.message
                : 'Reference import failed') +
              (incomplete
                ? ' · Some newly imported copies could not be removed; check My Trips.'
                : ''),
          },
        }
      }
    }
    if (file.size > MAX_IMPORT_BYTES)
      return { ok: false, problem: { status: 413, code: 'import.too_large' } }
    return call(() =>
      apiClient(token).POST('/v1/trips/import', {
        // The contract represents binary as string; serialize the validated Blob directly.
        body: '',
        bodySerializer: () => file,
        headers: { 'Content-Type': 'application/octet-stream' },
      }),
    )
  })

export const getImportedPackage = createServerFn({ method: 'GET' })
  .validator(z.object({ tripId: z.uuid() }))
  .handler(async ({ data }): Promise<Result<ImportedPackage | null>> => {
    const token = getSessionToken()
    if (!token) return signedOut
    return call(
      () =>
        apiClient(token).GET('/v1/trips/{tripId}/import', {
          params: { path: { tripId: data.tripId } },
        }),
      (value) =>
        value
          ? { documentJson: JSON.stringify(value.document), media: value.media }
          : null,
    )
  })
