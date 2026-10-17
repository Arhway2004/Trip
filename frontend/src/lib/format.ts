import { getLocale } from '#/paraglide/runtime'

const intlLocale: Record<string, string> = {
  en: 'en-GB',
  zh: 'zh-CN',
  th: 'th-TH',
}

export const currentIntlLocale = () => intlLocale[getLocale()] ?? 'en-GB'

/** Formats a calendar date ("YYYY-MM-DD") without any time-zone shift. */
export function formatDate(
  iso: string,
  style: 'medium' | 'short' = 'medium',
): string {
  const d = new Date(`${iso}T00:00:00Z`)
  return new Intl.DateTimeFormat(currentIntlLocale(), {
    timeZone: 'UTC',
    ...(style === 'medium'
      ? { day: 'numeric', month: 'short', year: 'numeric' }
      : { day: 'numeric', month: 'short' }),
  }).format(d)
}

export function formatDateRange(
  start?: string | null,
  end?: string | null,
): string | null {
  if (!start) return null
  if (!end || end === start) return formatDate(start)
  return `${formatDate(start, 'short')} – ${formatDate(end)}`
}

export function formatMoney(amount: number, currency: string): string {
  try {
    return new Intl.NumberFormat(currentIntlLocale(), {
      style: 'currency',
      currency,
      maximumFractionDigits: 2,
    }).format(amount)
  } catch {
    return `${amount.toLocaleString()} ${currency}`
  }
}
