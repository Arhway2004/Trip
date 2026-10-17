import { googleMapsUrl, parseMapLink } from './maps-link'

/** Resolve only approved Google map redirect hosts, with a bound on every hop. */
export async function resolveMapLink(
  value: string,
  request: typeof fetch = fetch,
) {
  let url = googleMapsUrl(value)
  for (let hop = 0; hop < 4; hop++) {
    const parsed = parseMapLink(url.href)
    if (parsed.kind !== 'short') return parsed
    const response = await request(url.href, {
      redirect: 'manual',
      signal: AbortSignal.timeout(8000),
      headers: { 'User-Agent': 'WanderPlan/1.0', Accept: 'text/html' },
    })
    await response.body?.cancel()
    const location = response.headers.get('location')
    if (response.status < 300 || response.status >= 400 || !location)
      throw new Error('short link did not redirect')
    url = googleMapsUrl(new URL(location, url).href)
  }
  throw new Error('too many redirects')
}
