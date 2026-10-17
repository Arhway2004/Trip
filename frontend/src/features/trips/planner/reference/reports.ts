import { records, text } from '../model'
import type { PlanDocument, PlanRow } from '../model'
import { budgetReport } from './budget'
import { planMetrics, object } from './domain'

export interface Privacy {
  excludeRefs: boolean
  excludeNotes: boolean
}
export function scrub<T>(value: T, privacy: Privacy): T {
  return JSON.parse(
    JSON.stringify(value, (key, entry: unknown) =>
      (privacy.excludeRefs &&
        /^(bookingReference|bookingRef|confirmationCode)$/i.test(key)) ||
      (privacy.excludeNotes &&
        /notes|caption|description|cancellation/i.test(key))
        ? undefined
        : entry,
    ),
  ) as T
}
export function csv(rows: Array<Array<unknown>>) {
  return (
    '\uFEFF' +
    rows
      .map((row) =>
        row
          .map((value) => {
            let cell =
              value == null
                ? ''
                : typeof value === 'object'
                  ? JSON.stringify(value)
                  : String(value)
            if (typeof value !== 'number' && /^[\s\t\r]*[=+@-]/.test(cell))
              cell = "'" + cell
            return '"' + cell.replaceAll('"', '""') + '"'
          })
          .join(','),
      )
      .join('\r\n')
  )
}
export function datasets(
  doc: PlanDocument,
  currency: string,
  limit: number,
  dates: Array<string>,
  travelers: number,
) {
  const fields = [
    'title',
    'date',
    'start',
    'endDate',
    'end',
    'kind',
    'city',
    'cost',
    'currency',
    'bookingStatus',
    'provider',
    'serviceNumber',
    'bookingReference',
    'notes',
  ]
  const table = (rows: Array<PlanRow>, keys = fields) => [
    keys,
    ...rows.map((row) => keys.map((key) => row[key] ?? '')),
  ]
  const budget = budgetReport(doc, currency, limit),
    metrics = planMetrics(doc, dates, currency, travelers)
  return {
    Overview: [
      ['Metric', 'Value'],
      ['Currency', currency],
      ['Budget', limit],
      ['Projected', budget.forecast],
      ['Actual', budget.actual],
      ['Remaining', budget.remaining],
    ],
    Itinerary: table(doc.activities),
    Flights: table(
      doc.activities.filter((a) => a.kind === 'flight'),
      [
        ...fields,
        'journeyRef',
        'departureAirport',
        'arrivalAirport',
        'departureTimeZone',
        'arrivalTimeZone',
        'unitPrice',
        'passengers',
        'baggageFee',
        'seatFee',
        'otherFees',
      ],
    ),
    Trains: table(doc.activities.filter((a) => a.kind === 'train')),
    'Ground Transport': table(
      doc.activities.filter((a) =>
        ['bus', 'ferry', 'transfer', 'transport'].includes(text(a.kind)),
      ),
    ),
    Accommodation: table(
      doc.activities.filter((a) => a.kind === 'hotel'),
      [...fields, 'rooms', 'pricePerNight', 'heating', 'cancellation'],
    ),
    Attractions: table(doc.places, [
      'name',
      'city',
      'category',
      'priority',
      'lat',
      'lng',
      'ticketPrice',
      'ticketCurrency',
      'transportCost',
      'durationMinutes',
      'openingHours',
      'reservation',
      'seasonalClosures',
      'notes',
    ]),
    'Budget Items': [
      [
        'title',
        'kind',
        'date',
        'city',
        'category',
        'amount',
        'currency',
        'value',
        'paid',
        'line',
      ],
      ...budget.items.map((item) => [
        item.title,
        item.kind,
        item.date,
        item.city,
        item.category,
        item.amount,
        item.currency,
        item.value,
        item.paid,
        item.line,
      ]),
    ],
    'Actual Expenses': table(
      doc.expenses.filter((e) => e.kind !== 'planned'),
      [
        'title',
        'date',
        'category',
        'amount',
        'currency',
        'activityRef',
        'isPaid',
        'notes',
      ],
    ),
    'Trip Log': table(doc.actuals, [
      'activityRef',
      'date',
      'start',
      'endDate',
      'end',
      'notes',
    ]),
    Scenarios: [
      ['name', 'cost', 'travelHours', 'highFatigueDays', 'freeHours', 'issues'],
      ...records(doc.scenarios).map((row) => {
        const candidate =
          row.ref === doc.activeScenarioRef
            ? doc
            : ({ ...doc, ...object(row.snapshot) } as PlanDocument)
        const m = planMetrics(candidate, dates, currency, travelers)
        return [
          row.name,
          m.planned,
          m.transportHours,
          m.highFatigueDays,
          m.freeHours,
          m.issues,
        ]
      }),
    ],
    Checks: [
      ['Date', 'Fatigue', 'Free hours', 'Travel minutes', 'Overlaps'],
      ...metrics.days.map((day) => [
        day.date,
        day.score,
        day.free / 60,
        day.travel,
        day.check.overlaps.length,
      ]),
    ],
  }
}
export function download(
  name: string,
  data: Blob | string,
  type = 'application/octet-stream',
) {
  const blob = data instanceof Blob ? data : new Blob([data], { type })
  const url = URL.createObjectURL(blob),
    link = document.createElement('a')
  link.href = url
  link.download = name
  link.click()
  setTimeout(() => URL.revokeObjectURL(url), 30000)
}
const loading = new Map<string, Promise<void>>()
function library(name: string) {
  let pending = loading.get(name)
  if (!pending) {
    pending = new Promise<void>((resolve, reject) => {
      const script = document.createElement('script')
      script.src = `/vendor/${name}`
      script.onload = () => resolve()
      script.onerror = () => {
        script.remove()
        loading.delete(name)
        reject(new Error('export library unavailable'))
      }
      document.head.append(script)
    })
    loading.set(name, pending)
  }
  return pending
}
interface SheetApi {
  utils: {
    book_new: () => unknown
    aoa_to_sheet: (rows: Array<Array<unknown>>) => unknown
    book_append_sheet: (book: unknown, sheet: unknown, name: string) => void
  }
  writeFile: (
    book: unknown,
    name: string,
    options: Record<string, unknown>,
  ) => void
}
export async function excel(data: ReturnType<typeof datasets>, name: string) {
  await library('xlsx.full.min.js')
  const api = (window as unknown as { XLSX: SheetApi }).XLSX,
    book = api.utils.book_new()
  for (const [title, rows] of Object.entries(data))
    api.utils.book_append_sheet(book, api.utils.aoa_to_sheet(rows), title)
  api.writeFile(book, name, { compression: true })
}
interface Zip {
  file: (name: string, data: string) => void
  generateAsync: (options: { type: 'blob' }) => Promise<Blob>
}
export async function csvZip(data: ReturnType<typeof datasets>, name: string) {
  await library('jszip.min.js')
  const ZipClass = (window as unknown as { JSZip: new () => Zip }).JSZip,
    zip = new ZipClass()
  for (const [title, rows] of Object.entries(data))
    zip.file(title + '.csv', csv(rows))
  download(name, await zip.generateAsync({ type: 'blob' }))
}
export const escapeHtml = (value: unknown) =>
  text(value).replace(
    /[&<>"']/g,
    (c) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        c
      ]!,
  )
export function reportHtml(title: string, data: ReturnType<typeof datasets>) {
  return (
    `<h1>${escapeHtml(title)}</h1>` +
    Object.entries(data)
      .map(
        ([name, rows]) =>
          `<section><h2>${escapeHtml(name)}</h2><table><thead><tr>${rows[0].map((v) => `<th>${escapeHtml(v)}</th>`).join('')}</tr></thead><tbody>${rows
            .slice(1)
            .map(
              (row) =>
                `<tr>${row.map((v) => `<td>${escapeHtml(typeof v === 'object' ? JSON.stringify(v) : v)}</td>`).join('')}</tr>`,
            )
            .join('')}</tbody></table></section>`,
      )
      .join('')
  )
}
const reportCss =
  'body{font:14px system-ui;color:#1f2923;padding:24px;background:white}h1{font-size:24px}h2{font-size:18px;border-bottom:1px solid #ccc;padding-bottom:6px}section{margin-top:24px}table{width:100%;border-collapse:collapse;font-size:10px;table-layout:auto}th,td{text-align:left;border-bottom:1px solid #ddd;padding:5px;overflow-wrap:anywhere;vertical-align:top}thead{display:table-header-group}tr{break-inside:avoid}@media print{body{padding:0}@page{size:A4 landscape;margin:12mm}}'
export function printReport(title: string, data: ReturnType<typeof datasets>) {
  const popup = window.open('', '_blank')
  if (!popup) throw new Error('popup blocked')
  popup.opener = null
  popup.document.write(
    `<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(title)}</title><style>${reportCss}</style></head><body>${reportHtml(title, data)}</body></html>`,
  )
  popup.document.close()
  popup.addEventListener('load', () => popup.print(), { once: true })
  return popup
}
type CanvasCapture = (
  element: HTMLElement,
  options: Record<string, unknown>,
) => Promise<HTMLCanvasElement>
async function capture(element: HTMLElement) {
  await library('html2canvas.min.js')
  await document.fonts.ready
  return (window as unknown as { html2canvas: CanvasCapture }).html2canvas(
    element,
    {
      useCORS: true,
      backgroundColor: '#ffffff',
      scale: 1.5,
      logging: false,
      ignoreElements: (node: Element) =>
        node.hasAttribute('data-html2canvas-ignore'),
    },
  )
}
export async function captureMap(element: HTMLElement) {
  const canvas = await capture(element)
  const blob = await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob((value) =>
      value ? resolve(value) : reject(new Error('map image unavailable')),
    ),
  )
  download('wanderplan-map.png', blob)
}
interface Pdf {
  addPage: () => void
  addImage: (
    image: string,
    format: string,
    x: number,
    y: number,
    width: number,
    height: number,
  ) => void
  save: (name: string) => void
}
export async function pdfReport(
  title: string,
  data: ReturnType<typeof datasets>,
) {
  await library('jspdf.umd.min.js')
  const frame = document.createElement('iframe')
  frame.style.cssText = 'position:fixed;left:-12000px;width:1120px;height:900px'
  document.body.append(frame)
  try {
    const content = frame.contentDocument!
    content.open()
    content.write(
      `<!doctype html><html><head><style>${reportCss}</style></head><body>${reportHtml(title, data)}</body></html>`,
    )
    content.close()
    const pdf = new (
      window as unknown as {
        jspdf: { jsPDF: new (options: Record<string, unknown>) => Pdf }
      }
    ).jspdf.jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' })
    let count = 0
    for (const section of Array.from(
      content.body.querySelectorAll('section'),
    )) {
      const canvas = await capture(section)
      const pageHeight = Math.floor((canvas.width * 190) / 277)
      for (let y = 0; y < canvas.height; y += pageHeight) {
        if (count++) pdf.addPage()
        const piece = document.createElement('canvas')
        piece.width = canvas.width
        piece.height = Math.min(pageHeight, canvas.height - y)
        piece
          .getContext('2d')!
          .drawImage(
            canvas,
            0,
            y,
            piece.width,
            piece.height,
            0,
            0,
            piece.width,
            piece.height,
          )
        pdf.addImage(
          piece.toDataURL('image/png'),
          'PNG',
          10,
          10,
          277,
          (piece.height / piece.width) * 277,
        )
      }
    }
    pdf.save('wanderplan-report.pdf')
  } finally {
    frame.remove()
  }
}
export function aiMarkdown(title: string, doc: PlanDocument) {
  return (
    `# ${title}\n\nReview this itinerary. Treat entered prices and transport schedules as unverified unless explicitly marked verified. Do not move confirmed bookings without asking.\n\n` +
    doc.activities
      .map(
        (row) =>
          `- ${text(row.date)} ${text(row.start)}–${text(row.end)}: ${text(row.title)} (${text(row.kind)})${row.notes ? '\n  ' + text(row.notes) : ''}`,
      )
      .join('\n') +
    '\n\n```json\n' +
    JSON.stringify(doc, null, 2) +
    '\n```\n'
  )
}
