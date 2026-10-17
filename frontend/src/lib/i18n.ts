import { m } from '#/paraglide/messages'

type Messages = typeof m

/** Renders a message by key (used for validation messages stored as keys). */
export function t(key: string): string {
  const fn = (m as unknown as Record<string, (() => string) | undefined>)[key]
  return fn ? fn() : key
}

export const msg: Messages = m
