import { Link, useRouter } from '@tanstack/react-router'
import { useQueryClient } from '@tanstack/react-query'
import { LogOut, UserRound } from 'lucide-react'
import { Button } from '#/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '#/components/ui/dropdown-menu'
import { signOut } from '#/features/auth/auth.functions'
import { m } from '#/paraglide/messages'
import type { User } from '#/lib/api/types'
import { AtlasMark } from './atlas-art'
import { LocaleSwitcher } from './locale-switcher'

export function AppHeader({ user }: { user: User | null }) {
  const router = useRouter()
  const queryClient = useQueryClient()

  async function handleSignOut() {
    await signOut()
    queryClient.clear()
    await router.invalidate()
    await router.navigate({ to: '/sign-in' })
  }

  return (
    <header className="atlas-header">
      <div className="atlas-header-inner">
        <Link to="/" className="atlas-brand">
          <AtlasMark />
          {m.app_name()}
        </Link>
        {user && (
          <nav className="hidden sm:block">
            <Link
              to="/trips"
              className="border-b-2 border-brand py-2 text-sm font-medium text-ink"
            >
              {m.nav_trips()}
            </Link>
          </nav>
        )}
        <div className="ml-auto flex items-center gap-2">
          <LocaleSwitcher />
          {user && (
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label={user.displayName || user.email || 'Account'}
                >
                  <UserRound />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuLabel>
                  <div className="font-semibold">{user.displayName || '—'}</div>
                  <div className="text-xs font-normal text-ink-3">
                    {user.email}
                  </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator />
                <DropdownMenuItem onSelect={handleSignOut}>
                  <LogOut /> {m.sign_out()}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          )}
        </div>
      </div>
    </header>
  )
}
