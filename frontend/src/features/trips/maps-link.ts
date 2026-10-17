export type MapLink =
  | { kind: 'pin'; lat: number; lng: number; name: string; url: string }
  | { kind: 'search'; query: string; url: string }
  | { kind: 'short'; url: string }

export function googleMapsUrl(value: string): URL {
  const url = new URL(value.trim())
  const host = url.hostname.toLowerCase()
  const google =
    /^(?:www\.|maps\.)?google\.(?:com|cn|co\.th|com\.hk|co\.jp|co\.uk)$/.test(
      host,
    )
  const short =
    host === 'maps.app.goo.gl' ||
    (host === 'goo.gl' && url.pathname.startsWith('/maps/'))
  if (
    url.protocol !== 'https:' ||
    url.username ||
    url.password ||
    url.port ||
    (!short &&
      !(
        google &&
        (url.pathname.startsWith('/maps') || host.startsWith('maps.'))
      ))
  )
    throw new Error('unsupported map link')
  return url
}

/** A viewport's @lat,lng is not necessarily the place pin. Never use it as one. */
export function parseMapLink(value: string): MapLink {
  const url = googleMapsUrl(value)
  if (url.pathname.startsWith('/maps/dir'))
    throw new Error('share a place, not directions')
  if (url.hostname === 'maps.app.goo.gl' || url.hostname === 'goo.gl')
    return { kind: 'short', url: url.href }
  const label = /\/place\/([^/]+)/.exec(url.pathname)?.[1]
  const name = label ? decodeURIComponent(label.replace(/\+/g, ' ')) : ''
  const data = decodeURIComponent(url.pathname + url.search)
  const pin = /!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/.exec(data)
  const query =
    url.searchParams.get('query') ||
    url.searchParams.get('q') ||
    url.searchParams.get('destination') ||
    ''
  const pair =
    /^\s*(?:loc:)?(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/.exec(query)
  const match = pin || pair
  if (match) {
    const lat = Number(match[1]),
      lng = Number(match[2])
    if (
      !Number.isFinite(lat) ||
      !Number.isFinite(lng) ||
      Math.abs(lat) > 90 ||
      Math.abs(lng) > 180
    )
      throw new Error('invalid coordinates')
    return {
      kind: 'pin',
      lat,
      lng,
      name: name || `${lat}, ${lng}`,
      url: url.href,
    }
  }
  if (name || (query && !query.startsWith('place_id:')))
    return {
      kind: 'search',
      query: (name || query).slice(0, 200),
      url: url.href,
    }
  throw new Error('link has no place pin')
}
