import { Outlet, createFileRoute, redirect } from '@tanstack/react-router'

/** Layout for signed-in pages: unauthenticated visitors go to /sign-in. */
export const Route = createFileRoute('/_app')({
  beforeLoad: ({ context, location }) => {
    if (!context.session.user) {
      throw redirect({ to: '/sign-in', search: { redirect: location.href } })
    }
    return { user: context.session.user }
  },
  component: Outlet,
})
