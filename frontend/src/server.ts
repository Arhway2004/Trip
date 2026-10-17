// Custom server entry: resolves the request's locale (cookie / Accept-Language)
// before rendering, so server-rendered HTML is already in the right language.
import handler, { createServerEntry } from '@tanstack/react-start/server-entry'
import { paraglideMiddleware } from './paraglide/server'

export default createServerEntry({
  fetch(request) {
    // Paraglide constructs a replacement Request and transfers the body to it.
    // Forward that request so multipart uploads are read exactly once.
    return paraglideMiddleware(request, ({ request: localizedRequest }) =>
      handler.fetch(localizedRequest),
    )
  },
})
