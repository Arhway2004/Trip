export interface LocalDraft {
  tripId: string
  version: number
  documentJson: string
  media: Record<string, string>
  savedAt: string
}
async function database() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    const request = indexedDB.open('wanderplan-web-drafts', 1)
    request.onupgradeneeded = () =>
      request.result.createObjectStore('drafts', { keyPath: 'tripId' })
    request.onerror = () => reject(request.error)
    request.onsuccess = () => resolve(request.result)
  })
}
export async function readDraft(
  tripId: string,
): Promise<LocalDraft | undefined> {
  const db = await database()
  try {
    return await new Promise((resolve, reject) => {
      const request = db
        .transaction('drafts', 'readonly')
        .objectStore('drafts')
        .get(tripId)
      request.onsuccess = () =>
        resolve(request.result as LocalDraft | undefined)
      request.onerror = () => reject(request.error)
    })
  } finally {
    db.close()
  }
}
export async function writeDraft(draft: LocalDraft) {
  const db = await database()
  try {
    await new Promise<void>((resolve, reject) => {
      const transaction = db.transaction('drafts', 'readwrite')
      transaction.objectStore('drafts').put(draft)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error)
    })
  } finally {
    db.close()
  }
}
export async function clearDraft(tripId: string) {
  const db = await database()
  try {
    await new Promise<void>((resolve, reject) => {
      const transaction = db.transaction('drafts', 'readwrite')
      transaction.objectStore('drafts').delete(tripId)
      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error)
    })
  } finally {
    db.close()
  }
}
