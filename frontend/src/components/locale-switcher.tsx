import { Languages } from 'lucide-react'
import { getLocale, locales, setLocale } from '#/paraglide/runtime'
import { m } from '#/paraglide/messages'

const names: Record<string, string> = {
  en: 'English',
  zh: '简体中文',
  th: 'ไทย',
}

/** Changing the locale sets a cookie and reloads, so server-rendered pages match. */
export function LocaleSwitcher() {
  return (
    <label className="flex items-center gap-1.5 text-sm text-ink-2">
      <Languages className="size-4" aria-hidden />
      <span className="sr-only">{m.language()}</span>
      <select
        className="rounded-md border bg-surface px-2 py-1 text-sm"
        value={getLocale()}
        onChange={(e) => setLocale(e.target.value as (typeof locales)[number])}
      >
        {locales.map((l) => (
          <option key={l} value={l}>
            {names[l] ?? l}
          </option>
        ))}
      </select>
    </label>
  )
}
