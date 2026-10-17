import { text } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { num } from './domain'

export interface CostItem {
  ref: string
  title: string
  amount: number
  currency: string
  value: number
  kind: 'planned' | 'actual'
  date: string
  city: string
  category: string
  activityRef: string
  line: string
  paid: boolean
  allowance: boolean
}
export function budgetReport(doc: PlanDocument, base: string, limit: number) {
  const rates = new Map(
    doc.exchangeRates.map((row) => [text(row.currency), num(row.rate)]),
  )
  rates.set(base, 1)
  const missing = new Set<string>(),
    lines = Array.isArray(doc.budgetLines)
      ? (doc.budgetLines as Array<PlanRow>)
      : []
  function item(
    row: PlanRow,
    kind: 'planned' | 'actual',
    amount: number,
  ): CostItem {
    const currency = text(row.currency) || base,
      rate = rates.get(currency)
    if (amount && (!rate || rate < 0)) missing.add(currency)
    const category = text(row.category) || 'misc',
      city =
        text(row.city) ||
        text(doc.activities.find((a) => a.ref === row.activityRef)?.city)
    const line =
      lines.find((l) => l.ref === row.budgetLineRef) ||
      lines.find(
        (l) =>
          text(l.categories)
            .split(',')
            .map((s) => s.trim())
            .includes(category) &&
          (!l.cities ||
            text(l.cities)
              .split(',')
              .map((s) => s.trim())
              .includes(city)),
      )
    return {
      ref: text(row.ref),
      title: text(row.title),
      amount,
      currency,
      value: amount * (rate || 0),
      kind,
      date: text(row.date),
      city,
      category,
      activityRef: text(row.activityRef),
      line: text(line?.ref),
      paid: row.isPaid === true || (kind === 'actual' && row.isPaid !== false),
      allowance: row.isAllowance === true,
    }
  }
  const items: Array<CostItem> = [
    ...doc.activities
      .filter((a) => a.bookingStatus !== 'cancelled' && num(a.cost) > 0)
      .map((a) =>
        item(
          {
            ...a,
            activityRef: a.ref,
            category:
              a.kind === 'hotel'
                ? 'hotels'
                : a.kind === 'flight'
                  ? 'flights'
                  : a.kind === 'train'
                    ? 'trains'
                    : a.kind === 'food'
                      ? 'food'
                      : a.kind === 'sightseeing'
                        ? 'attractions'
                        : a.category,
          },
          'planned',
          num(a.cost),
        ),
      ),
    ...doc.expenses.map((e) =>
      item(e, e.kind === 'planned' ? 'planned' : 'actual', num(e.amount)),
    ),
  ]
  const planned = items.filter((i) => i.kind === 'planned'),
    actual = items.filter((i) => i.kind === 'actual'),
    matched = new Set<CostItem>(),
    projected = new Map<CostItem, number>()
  for (const entry of planned) projected.set(entry, entry.value)
  const groups = new Set(planned.map((i) => i.activityRef).filter(Boolean))
  for (const ref of groups) {
    const costs = planned.filter((i) => i.activityRef === ref),
      spent = actual.filter((i) => i.activityRef === ref)
    if (!spent.length) continue
    const total = costs.reduce((sum, i) => sum + i.value, 0),
      amount = spent.reduce((sum, i) => sum + i.value, 0)
    for (const cost of costs)
      projected.set(
        cost,
        total ? (amount * cost.value) / total : amount / costs.length,
      )
    spent.forEach((i) => matched.add(i))
  }
  for (const allowance of planned.filter((i) => i.allowance)) {
    const spent = actual.filter(
      (i) =>
        !matched.has(i) &&
        i.category === allowance.category &&
        (!allowance.date || allowance.date === i.date),
    )
    projected.set(
      allowance,
      Math.max(
        projected.get(allowance) || 0,
        spent.reduce((sum, i) => sum + i.value, 0),
      ),
    )
    spent.forEach((i) => matched.add(i))
  }
  const forecast =
    planned.reduce((sum, i) => sum + (projected.get(i) || 0), 0) +
    actual.filter((i) => !matched.has(i)).reduce((sum, i) => sum + i.value, 0)
  const paid =
    actual.filter((i) => i.paid).reduce((sum, i) => sum + i.value, 0) +
    planned
      .filter(
        (i) =>
          i.paid &&
          !actual.some((a) => i.activityRef && a.activityRef === i.activityRef),
      )
      .reduce((sum, i) => sum + (projected.get(i) || 0), 0)
  function group(key: 'category' | 'city' | 'date' | 'line') {
    const keys = [...new Set(items.map((i) => i[key]))].sort()
    return keys.map((value) => ({
      label: value || '—',
      planned: planned
        .filter((i) => i[key] === value)
        .reduce((sum, i) => sum + i.value, 0),
      actual: actual
        .filter((i) => i[key] === value)
        .reduce((sum, i) => sum + i.value, 0),
      forecast:
        planned
          .filter((i) => i[key] === value)
          .reduce((sum, i) => sum + (projected.get(i) || 0), 0) +
        actual
          .filter((i) => i[key] === value && !matched.has(i))
          .reduce((sum, i) => sum + i.value, 0),
    }))
  }
  return {
    items,
    planned: planned.reduce((sum, i) => sum + i.value, 0),
    actual: actual.reduce((sum, i) => sum + i.value, 0),
    forecast,
    paid,
    unpaid: Math.max(0, forecast - paid),
    remaining: limit - forecast,
    missing: [...missing],
    group,
  }
}
