import { text } from './model'
import type { PlanDocument, PlanRow } from './model'
import type { ActualEvidenceDraft } from './actual-evidence'

// One save owns the log entry and its evidence. Re-editing replaces just that
// entry's expense/photos, while unrelated costs and gallery entries survive.
export function mergeActualEvidence(
  document: PlanDocument,
  actual: PlanRow,
  evidence: ActualEvidenceDraft,
): PlanDocument {
  const activity = document.activities.find(
    (row) => row.ref === actual.activityRef,
  )
  return {
    ...document,
    expenses: [
      ...document.expenses.filter((row) => row.actualRef !== actual.ref),
      ...(evidence.expense?.amount != null
        ? [
            {
              ...evidence.expense,
              kind: 'actual',
              title: text(evidence.expense.title) || text(activity?.title),
              category: evidence.expense.category || 'misc',
              currency:
                evidence.expense.currency ||
                (document.trip as PlanRow | undefined)?.currency,
              date: actual.date,
              activityRef: actual.activityRef,
              actualRef: actual.ref,
              isPaid: evidence.expense.isPaid !== false,
              isShared: evidence.expense.isShared !== false,
            },
          ]
        : []),
    ],
    photos: [
      ...document.photos.filter((row) => row.actualRef !== actual.ref),
      ...evidence.photos.map((photo) => ({
        ...photo,
        activityRef: actual.activityRef,
        actualRef: actual.ref,
        date: actual.date,
      })),
    ],
  }
}
