import server from './server'
import { describe, expect, it, vi } from 'vitest'

const mocks = vi.hoisted(() => ({ fetch: vi.fn() }))
vi.mock('@tanstack/react-start/server-entry', () => ({
  default: { fetch: mocks.fetch },
  createServerEntry: (entry: unknown) => entry,
}))
vi.mock('./paraglide/server', () => ({
  paraglideMiddleware: (
    request: Request,
    resolve: (args: { request: Request }) => unknown,
  ) => {
    // Model middleware that transfers the input stream into a replacement.
    return resolve({ request: new Request(request) })
  },
}))

describe('locale middleware request forwarding', () => {
  it('passes the replacement request so upload bodies can be consumed once', async () => {
    mocks.fetch.mockImplementation(
      async (request: Request) => new Response(await request.text()),
    )
    const original = new Request('http://localhost/_serverFn/import', {
      method: 'POST',
      body: 'trip upload',
    })
    const response = await server.fetch(original)
    expect(await response.text()).toBe('trip upload')
    expect(mocks.fetch.mock.calls[0][0]).not.toBe(original)
  })
})
