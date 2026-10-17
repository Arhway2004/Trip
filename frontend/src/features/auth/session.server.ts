import {
  deleteCookie,
  getCookie,
  setCookie,
} from '@tanstack/react-start/server'
import { SignJWT } from 'jose'
import { serverEnv } from '#/lib/server/env.server'

/**
 * The API bearer token lives in an httpOnly cookie: browser JavaScript never
 * sees it (backend-for-frontend pattern). Server functions attach it to API calls.
 */
const COOKIE = 'wp_session'
const MAX_AGE_SECONDS = 12 * 60 * 60

export function getSessionToken(): string | undefined {
  return getCookie(COOKIE) || undefined
}

export function setSessionToken(token: string) {
  setCookie(COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: serverEnv().NODE_ENV === 'production',
    path: '/',
    maxAge: MAX_AGE_SECONDS,
  })
}

export function clearSession() {
  deleteCookie(COOKIE, { path: '/' })
}

/**
 * Development sign-in: mints the same HS256 token the backend's AUTH_MODE=dev
 * accepts (issuer "wanderplan-dev"). Refused when AUTH_MODE is not "dev".
 */
export async function mintDevToken(identity: {
  email: string
  name: string
}): Promise<string> {
  const env = serverEnv()
  if (env.AUTH_MODE !== 'dev' || !env.DEV_JWT_SECRET)
    throw new Error('dev sign-in is disabled')
  const email = identity.email.trim().toLowerCase()
  return new SignJWT({ email, name: identity.name.trim() })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuer('wanderplan-dev')
    .setSubject(`dev:${email}`)
    .setIssuedAt()
    .setExpirationTime(`${MAX_AGE_SECONDS}s`)
    .sign(new TextEncoder().encode(env.DEV_JWT_SECRET))
}
