import { describe, expect, it, vi } from 'vitest'
import { parseMapLink } from './maps-link'
import { resolveMapLink } from './maps-link.server'

describe('Google Maps pin links', () => {
  it('reads exact query pins and place data instead of the viewport center', () => {
    expect(
      parseMapLink(
        'https://www.google.com/maps/search/?api=1&query=13.7467,100.5302',
      ),
    ).toMatchObject({ kind: 'pin', lat: 13.7467, lng: 100.5302 })
    expect(
      parseMapLink(
        'https://www.google.com/maps/place/Museum/@14,101,12z/data=!4m2!3d13.7467!4d100.5302',
      ),
    ).toMatchObject({
      kind: 'pin',
      name: 'Museum',
      lat: 13.7467,
      lng: 100.5302,
    })
  })
  it('searches a place name when the link has no exact pin, without inventing coordinates', () => {
    expect(
      parseMapLink('https://www.google.com/maps/place/Wat+Arun/@14,101,12z'),
    ).toMatchObject({ kind: 'search', query: 'Wat Arun' })
    expect(() =>
      parseMapLink('https://www.google.com/maps/@14,101,12z'),
    ).toThrow()
    expect(() =>
      parseMapLink('https://www.google.com/maps/dir/13,100/14,101'),
    ).toThrow()
  })
  it('rejects invalid coordinates and unrelated or credential-bearing URLs', () => {
    for (const value of [
      'https://www.google.com/maps?q=91,100',
      'https://google.com.evil.test/maps?q=13,100',
      'https://127.0.0.1/maps',
      'http://www.google.com/maps?q=13,100',
      'https://user@www.google.com/maps?q=13,100',
      'https://www.google.com:8443/maps?q=13,100',
    ])
      expect(() => parseMapLink(value)).toThrow()
  })
  it('resolves a share-link redirect with manual redirect handling', async () => {
    const request = vi
      .fn<typeof fetch>()
      .mockResolvedValue(
        new Response(null, {
          status: 302,
          headers: { location: 'https://www.google.com/maps?q=13.7,100.5' },
        }),
      )
    expect(
      await resolveMapLink('https://maps.app.goo.gl/example', request),
    ).toMatchObject({ kind: 'pin', lat: 13.7, lng: 100.5 })
    expect(request).toHaveBeenCalledWith(
      'https://maps.app.goo.gl/example',
      expect.objectContaining({ redirect: 'manual' }),
    )
  })
  it('never follows redirects to other hosts and bounds redirect loops', async () => {
    const request = vi
      .fn<typeof fetch>()
      .mockResolvedValue(
        new Response(null, {
          status: 302,
          headers: { location: 'https://127.0.0.1/private' },
        }),
      )
    await expect(
      resolveMapLink('https://maps.app.goo.gl/example', request),
    ).rejects.toThrow()
    expect(request).toHaveBeenCalledTimes(1)
    request
      .mockClear()
      .mockResolvedValue(
        new Response(null, {
          status: 302,
          headers: { location: 'https://maps.app.goo.gl/loop' },
        }),
      )
    await expect(
      resolveMapLink('https://maps.app.goo.gl/example', request),
    ).rejects.toThrow('too many redirects')
    expect(request).toHaveBeenCalledTimes(4)
  })
})
