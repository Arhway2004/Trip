import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, redirect, useRouter } from '@tanstack/react-router'
import { useState } from 'react'
import { z } from 'zod'
import { ProblemAlert } from '#/components/problem-alert'
import { Button } from '#/components/ui/button'
import { RouteArtwork } from '#/components/atlas-art'
import { Input } from '#/components/ui/input'
import { Label } from '#/components/ui/label'
import { signInDev } from '#/features/auth/auth.functions'
import type { Problem } from '#/lib/api/problem'
import { m } from '#/paraglide/messages'

const search = z.object({ redirect: z.string().optional() })

/** Only same-site paths are allowed as post-sign-in targets (no open redirects). */
function safeRedirect(target?: string): string {
  return target && target.startsWith('/') && !target.startsWith('//')
    ? target
    : '/trips'
}

export const Route = createFileRoute('/sign-in')({
  validateSearch: (s) => search.parse(s),
  beforeLoad: ({ context, search: s }) => {
    if (context.session.user) throw redirect({ to: safeRedirect(s.redirect) })
  },
  head: () => ({ meta: [{ title: `${m.sign_in()} · WanderPlan` }] }),
  component: SignIn,
})

function SignIn() {
  const { session } = Route.useRouteContext()
  const { redirect: target } = Route.useSearch()
  const router = useRouter()
  const queryClient = useQueryClient()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [busy, setBusy] = useState(false)
  const [problem, setProblem] = useState<Problem>()

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setProblem(undefined)
    const result = await signInDev({ data: { name, email } }).catch(
      () => undefined,
    )
    setBusy(false)
    if (!result)
      return setProblem({
        status: 400,
        code: 'request.invalid',
        detail: m.field_email(),
      })
    if (!result.ok) return setProblem(result.problem)
    queryClient.setQueryData(['session'], {
      user: result.data,
      authMode: session.authMode,
    })
    await router.invalidate()
    await router.navigate({ to: safeRedirect(target) })
  }

  return (
    <div className="atlas-sign-in">
      <div className="atlas-sign-in-art">
        <RouteArtwork />
        <p className="atlas-trip-number">{m.atlas_eyebrow()}</p>
        <h2>{m.atlas_signin_headline()}</h2>
        <p className="relative mt-8 text-sm text-white/80">
          {m.atlas_subtitle()}
        </p>
      </div>
      <div className="atlas-sign-in-form">
        <div className="mb-7 space-y-3">
          <p className="atlas-eyebrow">{m.atlas_begin()}</p>
          <h1 className="font-editorial text-4xl leading-tight tracking-tight">
            {m.sign_in_title()}
          </h1>
          <p className="text-sm leading-relaxed text-ink-2">
            {m.sign_in_subtitle()}
          </p>
        </div>
        <div className="space-y-4">
          {problem && <ProblemAlert problem={problem} />}
          {session.authMode === 'oidc' ? (
            <p className="text-sm text-ink-2">{m.oidc_not_ready()}</p>
          ) : (
            <form className="space-y-4" onSubmit={submit}>
              <div className="space-y-1.5">
                <Label htmlFor="name">{m.field_name()}</Label>
                <Input
                  id="name"
                  required
                  autoComplete="name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
              <div className="space-y-1.5">
                <Label htmlFor="email">{m.field_email()}</Label>
                <Input
                  id="email"
                  type="email"
                  required
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
              <Button type="submit" className="w-full" disabled={busy}>
                {m.continue()}
              </Button>
              <p className="text-xs text-ink-3">{m.dev_sign_in_note()}</p>
            </form>
          )}
        </div>
      </div>
    </div>
  )
}
