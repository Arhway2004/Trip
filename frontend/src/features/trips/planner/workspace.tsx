import { useEffect, useMemo, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import {
  ArrowDown,
  ArrowUp,
  CalendarDays,
  Clock,
  Check,
  CheckSquare,
  Copy,
  Download,
  Image,
  MapPin,
  Palette,
  Pencil,
  Plane,
  Plus,
  Trash2,
  Wallet,
} from 'lucide-react'
import { Button } from '#/components/ui/button'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '#/components/ui/alert-dialog'
import { isApiError } from '#/lib/api/problem'
import { formatDate, formatMoney } from '#/lib/format'
import type { Trip } from '#/lib/api/types'
import { m } from '#/paraglide/messages'
import { todayIn } from '../domain'
import { exportPlan, savePlan } from '../plan.functions'
import type { SavedPlan } from '../plan.functions'
import { TripBanner } from '../components/trip-banner'
import { p } from './copy'
import type { PlanText } from './copy'
import { activityKinds, bookingStatuses } from './fields'
import {
  budgetTotals,
  imageSource,
  parseDocument,
  planQuery,
  mediaFits,
  readPhoto,
  text,
} from './model'
import type { PlanDocument, PlanRow, Section } from './model'
import { RecordEditor } from './record-editor'
import type { EditorState } from './record-editor'
import type { ActualEvidenceDraft } from './actual-evidence'
import { mergeActualEvidence } from './actual-record'
import { PlanMap } from './plan-map'
import { DayPlanner } from './day-planner'
import { PlaceSearch } from './place-search'
import { ReferenceTools } from './reference/tools'
import { r as refText } from './reference/copy'
import { readDraft, writeDraft, clearDraft } from './reference/drafts'
import type { LocalDraft } from './reference/drafts'

const tabs = [
  ['day', 'dayPlan', CalendarDays],
  ['activities', 'tabTimeline', Plane],
  ['bookings', 'bookingsTitle', Plane],
  ['todos', 'todosTitle', CheckSquare],
  ['expenses', 'budgetTitle', Wallet],
  ['places', 'savedPlaces', MapPin],
  ['photos', 'photosTitle', Image],
  ['actuals', 'tripLog', Clock],
  ['banner', 'cover', Palette],
  ['tools', 'moreTools', CheckSquare],
] as const
type Tab = (typeof tabs)[number][0]
const titles: Record<Section | 'banner', PlanText> = {
  activities: 'addActivity',
  todos: 'todoAdd',
  expenses: 'addExpense',
  exchangeRates: 'addRate',
  places: 'addPlace',
  destinations: 'addDestination',
  photos: 'editPhoto',
  actuals: 'addActual',
  banner: 'bannerEditorTitle',
}
const rowTitle = (row: PlanRow) =>
  text(
    row.title ||
      row.name ||
      row.city ||
      row.country ||
      row.currency ||
      row.caption,
  ) || '—'
const position = (value: unknown) =>
  typeof value === 'string'
    ? value
    : value && typeof value === 'object'
      ? text((value as PlanRow).name)
      : ''
function rowSubtitle(row: PlanRow) {
  const end =
    row.endDate && row.endDate !== row.date
      ? `${formatDate(text(row.endDate), 'short')} ${text(row.end)}`
      : text(row.end)
  const clock = row.start
    ? `${text(row.start)} – ${end}`
    : row.date
      ? p('timeTbd')
      : ''
  return [
    row.date ? formatDate(text(row.date)) : '',
    clock,
    position(row.location),
    row.country,
    row.dueDate ? `${p('todoDueDate')}: ${formatDate(text(row.dueDate))}` : '',
  ]
    .filter(Boolean)
    .join(' · ')
}
function defaultRow(section: Section | 'banner', trip: Trip): PlanRow {
  switch (section) {
    case 'activities':
      return {
        title: '',
        date: trip.startDate || todayIn(trip.timeZone ?? 'UTC', new Date()),
        kind: 'sightseeing',
        bookingStatus: 'notBooked',
        currency: trip.currency ?? '',
        ref: crypto.randomUUID(),
      }
    case 'actuals':
      return {
        ref: crypto.randomUUID(),
        date: todayIn(trip.timeZone ?? 'UTC', new Date()),
      }
    case 'todos':
      return { title: '', category: 'other', isDone: false }
    case 'expenses':
      return {
        title: '',
        amount: 0,
        currency: trip.currency ?? '',
        kind: 'actual',
        category: 'misc',
        isPaid: true,
        isShared: true,
      }
    case 'exchangeRates':
      return { currency: '', rate: 1, source: 'manual' }
    case 'places':
      return { name: '', category: 'attraction' }
    case 'banner':
      return {
        kind: 'gradient',
        colorA: '#245c46',
        colorB: '#35624c',
        textColor: '#ffffff',
        showTitle: true,
        titlePlacement: 'bottomLeft',
        style: 'classic',
        scale: 1,
        alignX: 0,
        alignY: 0,
      }
    default:
      return {}
  }
}

export function PlanWorkspace({ trip }: { trip: Trip }) {
  const query = useQuery(planQuery(trip.id))
  if (query.isPending)
    return (
      <p role="status" className="text-sm text-ink-3">
        {m.import_loading()}
      </p>
    )
  if (query.isError)
    return (
      <section role="alert" className="rounded-lg border bg-surface p-5">
        <p>
          {isApiError(query.error) && [404, 405].includes(query.error.status)
            ? m.import_backend_update()
            : m.import_load_error()}
        </p>
        <Button
          variant="outline"
          className="mt-3"
          onClick={() => void query.refetch()}
        >
          {p('reload')}
        </Button>
      </section>
    )
  return (
    <Workspace
      key={trip.id}
      trip={trip}
      plan={query.data}
      reload={() => void query.refetch()}
    />
  )
}

function Workspace({
  trip,
  plan,
  reload,
}: {
  trip: Trip
  plan: SavedPlan
  reload: () => void
}) {
  const client = useQueryClient()
  const document = useMemo(
    () => parseDocument(plan.documentJson),
    [plan.documentJson],
  )
  const [tab, setTab] = useState<Tab>('day'),
    [busy, setBusy] = useState(false),
    [error, setError] = useState('')
  const [editor, setEditor] = useState<EditorState | null>(null)
  const [remove, setRemove] = useState<{
    section: Section
    index: number
    row: PlanRow
    version: number
  } | null>(null)
  const [activityFilter, setActivityFilter] = useState(''),
    [expenseFilter, setExpenseFilter] = useState(''),
    [hideDone, setHideDone] = useState(false),
    [favorites, setFavorites] = useState(false)
  const fileInput = useRef<HTMLInputElement>(null)
  const [pendingTodo, setPendingTodo] = useState<number | null>(null)
  const canEdit = trip.role === 'owner' || trip.role === 'editor'
  type HistoryEntry = Pick<SavedPlan, 'documentJson' | 'media'>
  const [undo, setUndo] = useState<Array<HistoryEntry>>([]),
    [redo, setRedo] = useState<Array<HistoryEntry>>([]),
    [draft, setDraft] = useState<LocalDraft>()
  const historyVersion = useRef(plan.version)
  useEffect(() => {
    if (historyVersion.current !== plan.version) {
      setUndo([])
      setRedo([])
      historyVersion.current = plan.version
    }
  }, [plan.version])
  useEffect(() => {
    let active = true
    void readDraft(trip.id)
      .then((value) => {
        if (active) setDraft(value)
      })
      .catch(() => undefined)
    return () => {
      active = false
    }
  }, [trip.id])
  function capHistory(entries: Array<HistoryEntry>) {
    let bytes = 0
    const files = new Set<string>()
    return entries
      .slice(-50)
      .reverse()
      .filter((entry) => {
        bytes += entry.documentJson.length * 2
        for (const [name, value] of Object.entries(entry.media))
          if (!files.has(name)) {
            bytes += value.length * 2
            files.add(name)
          }
        return bytes < 48 * 1024 * 1024
      })
      .reverse()
  }
  const totals = budgetTotals(
    document,
    trip.currency ?? '',
    trip.travelerCount ?? 1,
  )
  async function save(
    next: PlanDocument,
    media = plan.media,
    version = plan.version,
    history = true,
  ) {
    if (busy || !canEdit) return false
    setBusy(true)
    setError('')
    try {
      const result = await savePlan({
        data: {
          tripId: trip.id,
          version,
          documentJson: JSON.stringify(next),
          media,
        },
      })
      if (!result.ok) {
        const local = {
          tripId: trip.id,
          version,
          documentJson: JSON.stringify(next),
          media,
          savedAt: new Date().toISOString(),
        }
        try {
          await writeDraft(local)
          setDraft(local)
        } catch {
          /* Keep the in-memory editor if browser storage is unavailable. */
        }
        setError(
          result.problem.status === 412
            ? p('stale')
            : result.problem.detail || p('saveFailed'),
        )
        return false
      }
      if (history) {
        setUndo((old) =>
          capHistory([
            ...old,
            { documentJson: plan.documentJson, media: plan.media },
          ]),
        )
        setRedo([])
      }
      historyVersion.current = result.data.version
      void clearDraft(trip.id).catch(() => undefined)
      setDraft(undefined)
      client.setQueryData(planQuery(trip.id).queryKey, result.data)
      return true
    } catch {
      const local = {
        tripId: trip.id,
        version,
        documentJson: JSON.stringify(next),
        media,
        savedAt: new Date().toISOString(),
      }
      try {
        await writeDraft(local)
        setDraft(local)
      } catch {
        /* The existing save error remains visible. */
      }
      setError(p('saveFailed'))
      return false
    } finally {
      setBusy(false)
    }
  }
  async function restoreHistory(direction: 'undo' | 'redo') {
    const entries = direction === 'undo' ? undo : redo,
      entry = entries.at(-1)
    if (!entry) return
    if (
      await save(
        parseDocument(entry.documentJson),
        entry.media,
        plan.version,
        false,
      )
    ) {
      if (direction === 'undo') {
        setUndo((old) => old.slice(0, -1))
        setRedo((old) =>
          capHistory([
            ...old,
            { documentJson: plan.documentJson, media: plan.media },
          ]),
        )
      } else {
        setRedo((old) => old.slice(0, -1))
        setUndo((old) =>
          capHistory([
            ...old,
            { documentJson: plan.documentJson, media: plan.media },
          ]),
        )
      }
    }
  }
  function open(
    section: Section | 'banner',
    index: number | null,
    row?: PlanRow,
  ) {
    setError('')
    setEditor({
      version: plan.version,
      section,
      index,
      row: {
        ...defaultRow(section, trip),
        ...(row ??
          (section === 'banner'
            ? (document.banner as PlanRow)
            : index != null
              ? document[section][index]
              : {})),
      },
      title: index == null ? p(titles[section]) : p('editItem'),
    })
  }
  async function saveRow(
    row: PlanRow,
    media: Record<string, string>,
    evidence?: ActualEvidenceDraft,
  ) {
    if (!editor) return false
    let next = { ...document }
    if (editor.section === 'banner') next = { ...next, banner: row }
    else {
      const section = editor.section,
        items = [...document[section]]
      if (editor.index == null) items.push(row)
      else items[editor.index] = row
      next = { ...next, [section]: items }
    }
    if (editor.section === 'actuals' && evidence)
      next = mergeActualEvidence(next, row, evidence)
    const saved = await save(next, media, editor.version)
    if (saved) setEditor(null)
    return saved
  }
  async function confirmRemove() {
    if (!remove) return
    const { section, index, row: old } = remove
    let next = {
      ...document,
      [section]: document[section].filter((_, i) => i !== index),
    }
    const media = { ...plan.media }
    if (section === 'activities' && old.ref)
      next = {
        ...next,
        actuals: next.actuals.filter((row) => row.activityRef !== old.ref),
        connections: (Array.isArray(next.connections)
          ? next.connections
          : []
        ).filter(
          (row: PlanRow) => row.fromRef !== old.ref && row.toRef !== old.ref,
        ),
        expenses: next.expenses.map((row) =>
          row.activityRef === old.ref
            ? Object.fromEntries(
                Object.entries(row).filter(([key]) => key !== 'activityRef'),
              )
            : row,
        ),
      }
    if (
      section === 'photos' &&
      (next.banner as PlanRow | undefined)?.image !== old.file &&
      !next.photos.some((row) => row.file === old.file)
    )
      delete media[text(old.file)]
    if (await save(next, media, remove.version)) setRemove(null)
  }
  async function move(section: Section, index: number, direction: number) {
    if (document[section][index].isLocked) return
    const items = [...document[section]],
      target = index + direction
    if (target < 0 || target >= items.length || items[target].isLocked) return
    ;[items[index], items[target]] = [items[target], items[index]]
    await save({ ...document, [section]: items })
  }
  async function duplicate(index: number) {
    const row: PlanRow = {
      ...document.activities[index],
      title: rowTitle(document.activities[index]) + p('duplicateSuffix'),
      ref: crypto.randomUUID(),
      bookingStatus: 'notBooked',
    }
    delete row.bookingReference
    const items = [...document.activities]
    items.splice(index + 1, 0, row)
    await save({ ...document, activities: items })
  }
  async function uploadPhotos(files: FileList | null) {
    if (!files?.length) return
    if (!mediaFits(plan.media, Array.from(files))) {
      setError(p('mediaLimit'))
      return
    }
    setBusy(true)
    setError('')
    let next: PlanDocument | undefined,
      media: Record<string, string> | undefined
    try {
      const additions = await Promise.all(Array.from(files).map(readPhoto))
      media = { ...plan.media }
      const photos = [...document.photos]
      for (const photo of additions) {
        media[photo.name] = photo.bytes
        photos.push({ file: photo.name, caption: '', isFavorite: false })
      }
      next = { ...document, photos }
    } catch (cause) {
      setError(
        p(
          cause instanceof Error && cause.message === 'photoTooLarge'
            ? 'photoTooLarge'
            : 'photoUnsupported',
        ),
      )
    } finally {
      setBusy(false)
      if (fileInput.current) fileInput.current.value = ''
    }
    if (next && media) await save(next, media)
  }
  async function download() {
    setBusy(true)
    setError('')
    try {
      const result = await exportPlan({ data: { tripId: trip.id } })
      if (!result.ok) {
        setError(p('exportFailed'))
        return
      }
      const data = Uint8Array.from(atob(result.data.base64), (c) =>
        c.charCodeAt(0),
      )
      const url = URL.createObjectURL(
          new Blob([data], { type: 'application/zip' }),
        ),
        link = window.document.createElement('a')
      link.href = url
      link.download =
        trip.title.replace(/[^\p{L}\p{N}\s_-]/gu, '').slice(0, 100) +
        '.wanderplan'
      link.click()
      setTimeout(() => URL.revokeObjectURL(url), 1000)
    } catch {
      setError(p('exportFailed'))
    } finally {
      setBusy(false)
    }
  }
  function actions(section: Section, index: number) {
    if (!canEdit) return null
    const row = document[section][index]
    return (
      <div className="planner-row-actions">
        <Button
          variant="ghost"
          size="icon"
          disabled={busy}
          aria-label={`${p('actionEdit')}: ${rowTitle(row)}`}
          onClick={() => open(section, index)}
        >
          <Pencil />
        </Button>
        {section !== 'photos' && section !== 'exchangeRates' && (
          <>
            <Button
              variant="ghost"
              size="icon"
              disabled={
                busy ||
                index === 0 ||
                row.isLocked === true ||
                document[section][index - 1]?.isLocked === true
              }
              aria-label={`${p('moveUp')}: ${rowTitle(row)}`}
              onClick={() => void move(section, index, -1)}
            >
              <ArrowUp />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              disabled={
                busy ||
                index === document[section].length - 1 ||
                row.isLocked === true ||
                document[section][index + 1]?.isLocked === true
              }
              aria-label={`${p('moveDown')}: ${rowTitle(row)}`}
              onClick={() => void move(section, index, 1)}
            >
              <ArrowDown />
            </Button>
          </>
        )}
        {section === 'activities' && (
          <Button
            variant="ghost"
            size="icon"
            disabled={busy}
            aria-label={`${p('actionDuplicate')}: ${rowTitle(row)}`}
            onClick={() => void duplicate(index)}
          >
            <Copy />
          </Button>
        )}
        <Button
          variant="ghost"
          size="icon"
          disabled={busy}
          aria-label={`${p('actionDelete')}: ${rowTitle(row)}`}
          onClick={() => {
            setError('')
            setRemove({ section, index, row, version: plan.version })
          }}
        >
          <Trash2 />
        </Button>
      </div>
    )
  }
  function add(section: Section | 'banner') {
    return (
      canEdit && (
        <Button disabled={busy} onClick={() => open(section, null)}>
          <Plus />
          {p(titles[section])}
        </Button>
      )
    )
  }
  function list(
    section: Section,
    filter: (row: PlanRow) => boolean = () => true,
  ) {
    const items = document[section]
      .map((row, index) => ({ row, index }))
      .filter(({ row }) => filter(row))
    if (!items.length) return <p className="planner-empty">{p('empty')}</p>
    return (
      <div className="planner-list">
        {items.map(({ row, index }) => (
          <div key={index} className="planner-row">
            {section === 'todos' && (
              <input
                type="checkbox"
                className="mt-1 size-5 shrink-0 accent-[var(--brand)]"
                aria-label={rowTitle(row)}
                checked={
                  pendingTodo === index
                    ? row.isDone !== true
                    : row.isDone === true
                }
                disabled={busy || !canEdit}
                onChange={async () => {
                  setPendingTodo(index)
                  await save({
                    ...document,
                    todos: document.todos.map((r, i) =>
                      i === index ? { ...r, isDone: !r.isDone } : r,
                    ),
                  })
                  setPendingTodo(null)
                }}
              />
            )}
            <div className="min-w-0 flex-1">
              <h3
                className={`font-medium ${row.isDone ? 'text-ink-3 line-through' : ''}`}
              >
                {rowTitle(row)}
              </h3>
              <p className="mt-1 text-sm text-ink-2">
                {section === 'expenses'
                  ? `${formatMoney(Number(row.amount), text(row.currency) || trip.currency || '')} · ${row.kind === 'planned' ? p('expensePlanned') : p('expenseActual')} · ${row.isPaid === false ? p('expenseUnpaid') : p('expensePaid')}`
                  : section === 'exchangeRates'
                    ? `1 ${text(row.currency)} = ${text(row.rate)} ${trip.currency ?? ''} · ${p('rateManual')}`
                    : section === 'places'
                      ? `${text(row.address)} · ${text(row.lat)}, ${text(row.lng)}`
                      : rowSubtitle(row)}
              </p>
              {row.notes ? (
                <p className="mt-2 whitespace-pre-wrap text-sm text-ink-2">
                  {text(row.notes)}
                </p>
              ) : null}
              {section === 'places' && canEdit && (
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-3"
                  disabled={busy}
                  onClick={() =>
                    open('activities', null, {
                      ...defaultRow('activities', trip),
                      title: row.name,
                      location: { name: row.name, lat: row.lat, lng: row.lng },
                    })
                  }
                >
                  {p('addToDay')}
                </Button>
              )}
            </div>
            {actions(section, index)}
          </div>
        ))}
      </div>
    )
  }
  const activityRows = document.activities
    .map((row, index) => ({ row, index }))
    .filter(
      ({ row }) =>
        (tab !== 'bookings' ||
          [
            'flight',
            'train',
            'bus',
            'ferry',
            'transfer',
            'transport',
            'hotel',
          ].includes(text(row.kind))) &&
        (!activityFilter || row.kind === activityFilter),
    )
  const days = new Map<string, Array<{ row: PlanRow; index: number }>>()
  for (const item of activityRows) {
    const day = text(item.row.date)
    const values = days.get(day) ?? []
    values.push(item)
    days.set(day, values)
  }
  const mapPlaces = [
    ...document.places,
    ...document.activities.flatMap(
      (row) =>
        [row.location, row.destination].filter(
          (value) => value && typeof value === 'object',
        ) as Array<PlanRow>,
    ),
  ]
  const banner = (document.banner ?? defaultRow('banner', trip)) as PlanRow
  return (
    <section className="planner" aria-labelledby="plan-title" aria-busy={busy}>
      <div className="planner-heading">
        <div>
          <h2 id="plan-title" className="text-xl font-semibold">
            {p('planTitle')}
          </h2>
          <p className="mt-1 text-xs text-ink-3" role="status">
            {busy ? p('saving') : canEdit ? p('saved') : p('viewOnly')}
          </p>
        </div>
        <Button
          variant="outline"
          disabled={busy}
          onClick={() => void download()}
        >
          <Download />
          {p('exportMobile')}
        </Button>
      </div>
      <div className="mt-3 flex flex-wrap gap-2">
        <Button
          size="sm"
          variant="ghost"
          disabled={busy || !canEdit || !undo.length}
          onClick={() => void restoreHistory('undo')}
        >
          {refText('c.undo')}
        </Button>
        <Button
          size="sm"
          variant="ghost"
          disabled={busy || !canEdit || !redo.length}
          onClick={() => void restoreHistory('redo')}
        >
          {refText('c.redo')}
        </Button>
      </div>
      {draft && (
        <div className="my-4 border border-border p-4">
          <strong className="text-sm">{refText('localDraft')}</strong>
          <p className="mt-2 text-sm text-ink-2">
            {refText('localDraftHelp')} ·{' '}
            {new Date(draft.savedAt).toLocaleString()}
          </p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Button
              variant="outline"
              disabled={busy || !canEdit || draft.version !== plan.version}
              onClick={() =>
                void save(
                  parseDocument(draft.documentJson),
                  draft.media,
                  draft.version,
                )
              }
            >
              {refText('restoreDraft')}
            </Button>
            <Button
              variant="ghost"
              onClick={async () => {
                const { download: downloadRecovery } =
                  await import('./reference/reports')
                downloadRecovery(
                  'wanderplan-recovery.json',
                  JSON.stringify(
                    {
                      format: 'wanderplan.backup',
                      schemaVersion: 1,
                      trips: [
                        {
                          document: JSON.parse(draft.documentJson) as PlanRow,
                          media: draft.media,
                        },
                      ],
                    },
                    null,
                    2,
                  ),
                  'application/json',
                )
              }}
            >
              {refText('ex.backup')}
            </Button>
            <Button
              variant="ghost"
              disabled={busy}
              onClick={() => {
                void clearDraft(trip.id).catch(() => undefined)
                setDraft(undefined)
              }}
            >
              {refText('c.close')}
            </Button>
          </div>
        </div>
      )}
      <label className="planner-module mt-5 text-sm">
        {p('planNav')}
        <select
          className="planner-select mt-2"
          value={tab}
          onChange={(event) => setTab(event.target.value as Tab)}
        >
          {tabs.map(([value, label]) => (
            <option key={value} value={value}>
              {p(label)}
            </option>
          ))}
        </select>
      </label>
      <nav className="planner-tabs" role="tablist" aria-label={p('planNav')}>
        {tabs.map(([value, label, Icon], index) => (
          <button
            key={value}
            type="button"
            role="tab"
            id={`plan-tab-${value}`}
            aria-selected={tab === value}
            aria-controls="plan-panel"
            tabIndex={tab === value ? 0 : -1}
            onClick={() => setTab(value)}
            onKeyDown={(event) => {
              if (
                ['ArrowRight', 'ArrowLeft', 'Home', 'End'].includes(event.key)
              ) {
                event.preventDefault()
                const next =
                  event.key === 'Home'
                    ? 0
                    : event.key === 'End'
                      ? tabs.length - 1
                      : (index +
                          (event.key === 'ArrowRight' ? 1 : -1) +
                          tabs.length) %
                        tabs.length
                setTab(tabs[next][0])
                window.document
                  .getElementById(`plan-tab-${tabs[next][0]}`)
                  ?.focus()
              }
            }}
          >
            <Icon className="size-4" aria-hidden />
            {p(label)}
          </button>
        ))}
      </nav>
      {error && !editor && (
        <div
          role="alert"
          className="mt-4 rounded border border-bad/30 bg-bad-bg p-4 text-sm text-bad"
        >
          {error}
          <Button
            variant="outline"
            className="ml-3"
            disabled={busy}
            onClick={() => {
              setError('')
              reload()
            }}
          >
            {p('reload')}
          </Button>
        </div>
      )}
      <div
        role="tabpanel"
        id="plan-panel"
        aria-labelledby={`plan-tab-${tab}`}
        tabIndex={0}
        className="planner-panel"
      >
        {tab === 'tools' && (
          <ReferenceTools
            trip={trip}
            document={document}
            disabled={busy || !canEdit}
            onSave={save}
            onEdit={(index) => open('activities', index)}
            onAdd={(date) =>
              open('activities', null, {
                ...defaultRow('activities', trip),
                date,
              })
            }
          />
        )}
        {tab === 'day' && (
          <DayPlanner
            trip={trip}
            document={document}
            busy={busy}
            canEdit={canEdit}
            save={save}
            onEdit={(index) => open('activities', index)}
            onAdd={(date) =>
              open('activities', null, {
                ...defaultRow('activities', trip),
                date,
              })
            }
            onActual={(row) => {
              const index = document.actuals.findIndex(
                (actual) => actual.activityRef === row.ref,
              )
              open(
                'actuals',
                index >= 0 ? index : null,
                index >= 0
                  ? undefined
                  : {
                      ...defaultRow('actuals', trip),
                      date: row.date,
                      activityRef: row.ref,
                    },
              )
            }}
          />
        )}
        {(tab === 'activities' || tab === 'bookings') && (
          <>
            <div className="planner-toolbar">
              <h3 className="font-semibold">
                {tab === 'bookings' ? p('bookingsTitle') : p('tabTimeline')}
              </h3>
              <div className="flex flex-wrap items-center gap-3">
                <select
                  className="planner-select !w-auto"
                  aria-label={p('filter')}
                  value={activityFilter}
                  onChange={(event) => setActivityFilter(event.target.value)}
                >
                  <option value="">{p('allActivities')}</option>
                  {activityKinds.map(([value, label]) => (
                    <option key={value} value={value}>
                      {p(label)}
                    </option>
                  ))}
                </select>
                {add('activities')}
              </div>
            </div>
            {days.size === 0 ? (
              <p className="planner-empty">{p('noActivitiesYet')}</p>
            ) : (
              [...days]
                .sort(([a], [b]) => a.localeCompare(b))
                .map(([day, items]) => (
                  <section key={day} className="planner-day">
                    <h4>{day ? formatDate(day) : m.dates_undecided()}</h4>
                    <div className="planner-list">
                      {items.map(({ row, index }) => (
                        <article
                          key={index}
                          className={`planner-row ${row.bookingStatus === 'cancelled' ? 'opacity-60' : ''}`}
                        >
                          <div className="planner-time">
                            {row.start ? (
                              <>
                                {text(row.start)}
                                <span>
                                  {row.endDate && row.endDate !== row.date
                                    ? `${formatDate(text(row.endDate), 'short')} `
                                    : ''}
                                  {text(row.end)}
                                </span>
                              </>
                            ) : (
                              p('timeTbd')
                            )}
                          </div>
                          <div className="min-w-0 flex-1">
                            <h5 className="font-semibold">{rowTitle(row)}</h5>
                            <p className="mt-1 text-sm text-ink-2">
                              {position(row.location)}
                              {position(row.destination)
                                ? ` → ${position(row.destination)}`
                                : ''}
                            </p>
                            <div className="mt-2 flex flex-wrap gap-2 text-xs text-ink-2">
                              <span>
                                {p(
                                  activityKinds.find(
                                    ([value]) => value === row.kind,
                                  )?.[1] ?? 'kindOther',
                                )}
                              </span>
                              <span>
                                ·{' '}
                                {p(
                                  bookingStatuses.find(
                                    ([value]) => value === row.bookingStatus,
                                  )?.[1] ?? 'bookingNotBooked',
                                )}
                              </span>
                              {row.cost != null && (
                                <span>
                                  ·{' '}
                                  {formatMoney(
                                    Number(row.cost),
                                    text(row.currency) || trip.currency || '',
                                  )}
                                </span>
                              )}
                              {row.isLocked === true && (
                                <span>· {p('fieldLocked')}</span>
                              )}
                            </div>
                            {row.notes ||
                            row.bookingReference ||
                            row.provider ||
                            row.serviceNumber ||
                            row.bookingUrl ? (
                              <details className="mt-3 text-sm">
                                <summary className="cursor-pointer text-ink-2">
                                  {p('moreDetails')}
                                </summary>
                                <div className="mt-2 space-y-2 whitespace-pre-wrap break-words text-ink-2">
                                  {[
                                    row.provider,
                                    row.serviceNumber,
                                    row.bookingReference,
                                    row.bookingUrl,
                                    row.notes,
                                  ]
                                    .filter(Boolean)
                                    .map((value, i) => (
                                      <p key={i}>{text(value)}</p>
                                    ))}
                                </div>
                              </details>
                            ) : null}
                          </div>
                          {actions('activities', index)}
                        </article>
                      ))}
                    </div>
                  </section>
                ))
            )}
          </>
        )}
        {tab === 'todos' && (
          <>
            <div className="planner-toolbar">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={hideDone}
                  onChange={(event) => setHideDone(event.target.checked)}
                />
                {p('todoHideDone')}
              </label>
              {add('todos')}
            </div>
            {list('todos', (row) => !hideDone || !row.isDone)}
          </>
        )}
        {tab === 'expenses' && (
          <>
            {!trip.currency ? (
              <p className="mb-5 text-sm text-warn">{p('noCurrency')}</p>
            ) : (
              <div className="planner-budget">
                <Metric
                  label={p('budgetPlanned')}
                  value={formatMoney(totals.planned, trip.currency)}
                />
                <Metric
                  label={p('budgetSpent')}
                  value={formatMoney(totals.spent, trip.currency)}
                />
                <Metric
                  label={p('budgetRemaining')}
                  value={
                    trip.totalBudget != null
                      ? formatMoney(
                          trip.totalBudget - totals.spent,
                          trip.currency,
                        )
                      : '—'
                  }
                />
              </div>
            )}
            {trip.currency && (
              <p className="mb-5 text-sm text-ink-2">
                {p('expensePaid')}: {formatMoney(totals.paid, trip.currency)} ·{' '}
                {p('actualPerPerson')}:{' '}
                {formatMoney(totals.perPerson, trip.currency)}
              </p>
            )}
            {totals.missing.length > 0 && (
              <p
                role="status"
                className="mb-5 rounded bg-warn-bg p-3 text-sm text-warn"
              >
                {p('missingRates')} {totals.missing.join(', ')}
              </p>
            )}
            <div className="planner-toolbar">
              <select
                className="planner-select !w-auto"
                aria-label={p('filter')}
                value={expenseFilter}
                onChange={(event) => setExpenseFilter(event.target.value)}
              >
                <option value="">{p('allExpenses')}</option>
                <option value="actual">{p('expenseActual')}</option>
                <option value="planned">{p('expensePlanned')}</option>
              </select>
              {add('expenses')}
            </div>
            {list(
              'expenses',
              (row) =>
                !expenseFilter || (row.kind || 'actual') === expenseFilter,
            )}
            <div className="planner-toolbar mt-8">
              <h3 className="font-semibold">{p('budgetRates')}</h3>
              {add('exchangeRates')}
            </div>
            <p className="mb-4 text-sm text-ink-2">{p('rateHelp')}</p>
            {list('exchangeRates')}
          </>
        )}
        {tab === 'places' && (
          <>
            <div className="planner-toolbar">
              <h3 className="font-semibold">{p('destinations')}</h3>
              {add('destinations')}
            </div>
            {list('destinations')}
            <div className="planner-toolbar mt-8">
              <h3 className="font-semibold">{p('savedPlaces')}</h3>
              {add('places')}
            </div>
            {canEdit && (
              <PlaceSearch
                tripId={trip.id}
                disabled={busy}
                onChoose={(place) =>
                  open('places', null, {
                    ...defaultRow('places', trip),
                    ...place,
                  })
                }
              />
            )}
            <PlanMap
              places={mapPlaces}
              onPick={
                canEdit
                  ? (lat, lng) =>
                      open('places', null, {
                        ...defaultRow('places', trip),
                        lat,
                        lng,
                      })
                  : undefined
              }
            />
            <div className="mt-5">{list('places')}</div>
          </>
        )}
        {tab === 'photos' && (
          <>
            <div className="planner-toolbar">
              <label className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={favorites}
                  onChange={(event) => setFavorites(event.target.checked)}
                />
                {p('favoritesOnly')}
              </label>
              {canEdit && (
                <Button
                  disabled={busy}
                  onClick={() => fileInput.current?.click()}
                >
                  <Plus />
                  {p('addPhoto')}
                </Button>
              )}
              <input
                ref={fileInput}
                type="file"
                multiple
                accept="image/jpeg,image/png,image/webp,image/gif"
                className="hidden"
                aria-label={p('addPhoto')}
                onChange={(event) => void uploadPhotos(event.target.files)}
              />
            </div>
            {!document.photos.length ? (
              <p className="planner-empty">{p('galleryEmpty')}</p>
            ) : (
              <div className="planner-gallery">
                {document.photos.map((row, index) =>
                  favorites && !row.isFavorite ? null : (
                    <figure
                      key={index}
                      className="min-w-0 overflow-hidden rounded-lg border bg-surface"
                    >
                      {imageSource(plan.media[text(row.file)]) ? (
                        <img
                          src={imageSource(plan.media[text(row.file)])}
                          alt={text(row.caption) || p('photosTitle')}
                          loading="lazy"
                          className="h-48 w-full object-cover"
                        />
                      ) : (
                        <p className="p-6 text-sm text-ink-3">
                          {p('photoMissing')}
                        </p>
                      )}
                      <figcaption className="p-4">
                        <p className="mb-2 text-sm">{text(row.caption)}</p>
                        {canEdit && (
                          <div className="flex flex-wrap gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              disabled={busy}
                              aria-pressed={row.isFavorite === true}
                              onClick={() =>
                                void save({
                                  ...document,
                                  photos: document.photos.map((r, i) =>
                                    i === index
                                      ? { ...r, isFavorite: !r.isFavorite }
                                      : r,
                                  ),
                                })
                              }
                            >
                              {row.isFavorite ? <Check /> : <Plus />}
                              {p('photoFavorite')}
                            </Button>
                            <Button
                              variant="outline"
                              size="sm"
                              disabled={
                                busy || !imageSource(plan.media[text(row.file)])
                              }
                              onClick={() =>
                                void save({
                                  ...document,
                                  banner: {
                                    ...defaultRow('banner', trip),
                                    ...banner,
                                    image: row.file,
                                    kind: 'photo',
                                  },
                                })
                              }
                            >
                              {p('setAsCover')}
                            </Button>
                          </div>
                        )}
                        {actions('photos', index)}
                      </figcaption>
                    </figure>
                  ),
                )}
              </div>
            )}
          </>
        )}
        {tab === 'actuals' && (
          <>
            <div className="planner-toolbar">
              <h3 className="font-semibold">{p('tripLog')}</h3>
              {add('actuals')}
            </div>
            <p className="mb-5 text-sm leading-relaxed text-ink-2">
              {p('actualHelp')}
            </p>
            {document.actuals.length === 0 ? (
              <p className="planner-empty">{p('noActuals')}</p>
            ) : (
              <div className="planner-list">
                {document.actuals.map((row, index) => {
                  const activity = document.activities.find(
                    (item) => item.ref === row.activityRef,
                  )
                  return (
                    <article key={index} className="planner-row">
                      <div className="min-w-0 flex-1">
                        <h4 className="font-semibold">
                          {text(activity?.title) || p('kindActivity')}
                        </h4>
                        <p className="mt-2 text-sm text-ink-2">
                          {p('plannedTimes')}:{' '}
                          {activity ? rowSubtitle(activity) : '—'}
                        </p>
                        <p className="mt-2 text-sm">
                          {p('actualTimes')}: {rowSubtitle(row)}
                        </p>
                        {row.notes ? (
                          <p className="mt-3 whitespace-pre-wrap text-sm text-ink-2">
                            {text(row.notes)}
                          </p>
                        ) : null}
                        {document.expenses
                          .filter((expense) => expense.actualRef === row.ref)
                          .map((expense, i) => (
                            <p className="mt-3 text-sm" key={i}>
                              {p('actualCost')}:{' '}
                              {formatMoney(
                                Number(expense.amount),
                                text(expense.currency) || trip.currency || '',
                              )}
                            </p>
                          ))}
                        <div className="mt-3 flex flex-wrap gap-3">
                          {document.photos
                            .filter((photo) => photo.actualRef === row.ref)
                            .map((photo) =>
                              imageSource(plan.media[text(photo.file)]) ? (
                                <figure key={text(photo.file)}>
                                  <img
                                    className="h-20 w-20 rounded object-cover"
                                    src={imageSource(
                                      plan.media[text(photo.file)],
                                    )}
                                    alt={
                                      text(photo.caption) || p('photosTitle')
                                    }
                                  />
                                  <figcaption className="mt-1 max-w-20 text-xs text-ink-2">
                                    {text(photo.caption)}
                                  </figcaption>
                                </figure>
                              ) : null,
                            )}
                        </div>
                      </div>
                      {actions('actuals', index)}
                    </article>
                  )
                })}
              </div>
            )}
          </>
        )}
        {tab === 'banner' && (
          <>
            <div className="planner-toolbar">
              <h3 className="font-semibold">{p('cover')}</h3>
              {add('banner')}
            </div>
            <TripBanner
              tripId={trip.id}
              banner={banner}
              media={plan.media}
              className="rounded-lg"
            >
              <div className="flex min-h-60 items-end p-6">
                <h3 className="atlas-detail-title">
                  {banner.showTitle === false ? '' : trip.title}
                </h3>
              </div>
            </TripBanner>
          </>
        )}
      </div>
      <p className="mt-5 text-xs leading-relaxed text-ink-3">{p('noSync')}</p>
      {editor && (
        <RecordEditor
          key={`${editor.section}-${editor.index}`}
          editor={editor}
          document={document}
          media={plan.media}
          busy={busy}
          error={error}
          onSave={saveRow}
          onClose={() => {
            setEditor(null)
            setError('')
          }}
          onReload={() => {
            setEditor(null)
            setError('')
            reload()
          }}
        />
      )}
      <AlertDialog
        open={remove != null}
        onOpenChange={(value) => {
          if (!value && !busy) setRemove(null)
        }}
      >
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{p('removeTitle')}</AlertDialogTitle>
            <AlertDialogDescription>
              {p('removeBody')} {remove && rowTitle(remove.row)}
            </AlertDialogDescription>
          </AlertDialogHeader>
          {error && (
            <p role="alert" className="text-sm text-bad">
              {error}
            </p>
          )}
          <AlertDialogFooter>
            <AlertDialogCancel disabled={busy}>
              {p('actionCancel')}
            </AlertDialogCancel>
            <AlertDialogAction
              disabled={busy}
              className="bg-bad-bg text-bad hover:bg-bad-bg/90"
              onClick={(event) => {
                event.preventDefault()
                void confirmRemove()
              }}
            >
              {p('actionDelete')}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  )
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-ink-3">{label}</p>
      <p className="mt-2 text-xl font-semibold">{value}</p>
    </div>
  )
}
