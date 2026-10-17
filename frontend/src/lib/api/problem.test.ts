import { describe, expect, it } from 'vitest'
import { ApiError, fieldErrors, isStatus, toProblem, unwrap } from './problem'

describe('problem details', () => {
  it('reads RFC 9457 bodies from the API', () => {
    const p = toProblem(422, {
      status: 422,
      code: 'trip.invalid',
      detail: 'the trip has invalid fields',
      errors: [{ field: 'title', message: 'is required' }],
      requestId: 'abc',
    })
    expect(p.code).toBe('trip.invalid')
    expect(fieldErrors(p)).toEqual({ title: 'is required' })
  })

  it('tolerates non-problem bodies', () => {
    expect(toProblem(502, 'Bad gateway')).toEqual({
      status: 502,
      code: 'internal',
    })
  })

  it('unwrap throws ApiError for failures', () => {
    expect(unwrap({ ok: true, data: 1 })).toBe(1)
    try {
      unwrap({
        ok: false,
        problem: { status: 412, code: 'trip.version_mismatch' },
      })
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError)
      expect(isStatus(e, 412)).toBe(true)
      return
    }
    throw new Error('expected unwrap to throw')
  })
})
