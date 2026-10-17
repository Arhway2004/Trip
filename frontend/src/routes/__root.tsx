import {
  HeadContent,
  Link,
  Outlet,
  Scripts,
  createRootRouteWithContext,
} from '@tanstack/react-router'
import { TanStackRouterDevtoolsPanel } from '@tanstack/react-router-devtools'
import { TanStackDevtools } from '@tanstack/react-devtools'
import { Toaster } from 'sonner'
import type { QueryClient } from '@tanstack/react-query'
import { AppHeader } from '#/components/app-header'
import { ProblemAlert } from '#/components/problem-alert'
import { Button } from '#/components/ui/button'
import { sessionQuery } from '#/features/trips/queries'
import { getLocale } from '#/paraglide/runtime'
import { m } from '#/paraglide/messages'
import TanStackQueryDevtools from '../integrations/tanstack-query/devtools'
import appCss from '../styles.css?url'

interface RouterContext {
  queryClient: QueryClient
}

export const Route = createRootRouteWithContext<RouterContext>()({
  beforeLoad: async ({ context }) => {
    if (typeof document !== 'undefined')
      document.documentElement.lang = getLocale()
    const session = await context.queryClient.ensureQueryData(sessionQuery)
    return { session }
  },
  head: () => ({
    meta: [
      { charSet: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { title: 'WanderPlan' },
      {
        name: 'description',
        content: 'Plan trips anywhere: dates, budget, bookings and more.',
      },
    ],
    links: [{ rel: 'stylesheet', href: appCss }],
  }),
  shellComponent: RootDocument,
  component: RootLayout,
  notFoundComponent: NotFound,
})

function RootLayout() {
  const { session } = Route.useRouteContext()
  return (
    <>
      <AppHeader user={session.user} />
      <main className="atlas-shell">
        {session.problem && (
          <div className="mb-6">
            <ProblemAlert problem={session.problem} />
          </div>
        )}
        <Outlet />
        <footer className="atlas-footer">
          <span>{m.atlas_footer()}</span>
          <span>WanderPlan · {m.atlas_edition()}</span>
        </footer>
      </main>
      <Toaster position="bottom-center" richColors />
    </>
  )
}

function NotFound() {
  return (
    <div className="mx-auto max-w-md py-16 text-center">
      <h1 className="text-2xl font-extrabold">{m.not_found_title()}</h1>
      <Button asChild className="mt-6">
        <Link to="/trips">{m.back_to_trips()}</Link>
      </Button>
    </div>
  )
}

function RootDocument({ children }: { children: React.ReactNode }) {
  return (
    <html lang={getLocale()}>
      <head>
        <HeadContent />
      </head>
      <body>
        {children}
        {import.meta.env.DEV &&
          import.meta.env.VITE_SHOW_DEVTOOLS === 'true' && (
            <TanStackDevtools
              config={{ position: 'bottom-right' }}
              plugins={[
                {
                  name: 'TanStack Router',
                  render: <TanStackRouterDevtoolsPanel />,
                },
                TanStackQueryDevtools,
              ]}
            />
          )}
        <Scripts />
      </body>
    </html>
  )
}
