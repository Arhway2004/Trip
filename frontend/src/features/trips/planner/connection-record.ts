import { records, text } from './model'
import type { PlanDocument, PlanRow } from './model'

export function mergeConnection(
  document: PlanDocument,
  from: PlanRow,
  to: PlanRow,
  connection: PlanRow,
): PlanDocument {
  const existing = document.expenses.find(
    (row) => row.connectionRef === connection.key && row.kind === 'planned',
  )
  const expenses = document.expenses.filter(
    (row) => !(row.connectionRef === connection.key && row.kind === 'planned'),
  )
  if (
    typeof connection.amount === 'number' &&
    Number.isFinite(connection.amount) &&
    connection.amount >= 0 &&
    /^[A-Z]{3}$/.test(text(connection.currency))
  )
    expenses.push({
      ...existing,
      title: `${text(from.title)} → ${text(to.title)}`,
      kind: 'planned',
      amount: connection.amount,
      currency: connection.currency,
      date: from.endDate || from.date,
      category:
        connection.mode === 'flight'
          ? 'flights'
          : connection.mode === 'train'
            ? 'trains'
            : connection.mode === 'bus'
              ? 'buses'
              : 'transport',
      isPaid: existing?.isPaid === true,
      isShared: existing?.isShared !== false,
      connectionRef: connection.key,
    })
  return {
    ...document,
    connections: [
      ...records(document.connections).filter(
        (row) => row.key !== connection.key,
      ),
      connection,
    ],
    expenses,
  }
}
