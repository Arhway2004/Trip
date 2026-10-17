import { useEffect, useRef, useState } from 'react'
import { LoaderCircle, Save, X } from 'lucide-react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Label } from '#/components/ui/label'
import { Textarea } from '#/components/ui/textarea'
import { p } from './copy'
import { fields } from './fields'
import {
  color,
  fieldValue,
  imageSource,
  mediaFits,
  readPhoto,
  setField,
  text,
} from './model'
import type { PlanDocument, PlanRow, Section } from './model'
import { ActualEvidence } from './actual-evidence'
import type { ActualEvidenceDraft } from './actual-evidence'

export interface EditorState {
  section: Section | 'banner'
  index: number | null
  row: PlanRow
  title: string
  version?: number
}
export function RecordEditor({
  editor,
  document,
  media,
  busy,
  error,
  onSave,
  onClose,
  onReload,
}: {
  editor: EditorState
  document: PlanDocument
  media: Record<string, string>
  busy: boolean
  error: string
  onSave: (
    row: PlanRow,
    media: Record<string, string>,
    evidence?: ActualEvidenceDraft,
  ) => Promise<boolean>
  onClose: () => void
  onReload: () => void
}) {
  const [draft, setDraft] = useState(editor.row)
  const [draftMedia, setDraftMedia] = useState(media)
  const [evidence, setEvidence] = useState<ActualEvidenceDraft>(() => ({
    expense: document.expenses.find(
      (row) => editor.row.ref && row.actualRef === editor.row.ref,
    ) ?? { currency: (document.trip as PlanRow | undefined)?.currency },
    photos: document.photos.filter(
      (row) => editor.row.ref && row.actualRef === editor.row.ref,
    ),
  }))
  const [uploading, setUploading] = useState(false)
  const [localError, setLocalError] = useState('')
  const dialog = useRef<HTMLDialogElement>(null)
  const pending = busy || uploading
  useEffect(() => {
    const element = dialog.current
    const previous = window.document.activeElement
    element?.showModal()
    return () => {
      element?.close()
      if (previous instanceof HTMLElement) previous.focus()
    }
  }, [])
  function savedPlace(key: 'location' | 'destination') {
    return (
      <div className="mt-3">
        <Label
          htmlFor={`saved-${key}`}
          className="mb-2 block text-xs text-ink-2"
        >
          {p(key === 'location' ? 'useSavedPlace' : 'useSavedDestination')}
        </Label>
        <select
          id={`saved-${key}`}
          className="planner-select"
          value=""
          disabled={pending}
          onChange={(event) => {
            if (event.target.value === '') return
            const place = document.places[Number(event.target.value)]
            setDraft((row) => ({
              ...row,
              [key]: { name: place.name, lat: place.lat, lng: place.lng },
            }))
          }}
        >
          <option value="">{p('chooseLocation')}</option>
          {document.places.map((row, index) => (
            <option key={index} value={index}>
              {text(row.name)}
            </option>
          ))}
        </select>
      </div>
    )
  }
  function renderField(field: (typeof fields.activities)[number]) {
    const value = fieldValue(draft, field.key),
      id = `edit-${field.key.replaceAll('.', '-')}`
    const update = (next: unknown) =>
      setDraft((row) => setField(row, field.key, next))
    let options = field.options?.map(([v, k]) => [v, p(k)]) ?? []
    if (field.key === 'activityRef')
      options = document.activities.map((row) => [
        text(row.ref),
        text(row.title),
      ])
    if (field.key === 'image')
      options = Object.keys(draftMedia)
        .filter((name) => imageSource(draftMedia[name]))
        .map((name) => [
          name,
          text(document.photos.find((row) => row.file === name)?.caption) ||
            name.split('/').pop()!,
        ])
    const stringValue =
      field.type === 'color'
        ? color(value, field.key === 'textColor' ? '#ffffff' : '#245c46')
        : text(value)
    if (stringValue && !options.some(([v]) => v === stringValue))
      options.unshift([stringValue, stringValue])
    const linked = document.activities.find(
      (row) => row.ref === draft.activityRef,
    )
    const transport =
      editor.section === 'actuals' &&
      ['flight', 'train', 'bus', 'ferry', 'transfer', 'transport'].includes(
        text(linked?.kind),
      )
    const actualLabel = transport
      ? (
          {
            actualArrival: 'actualDeparture',
            actualDeparture: 'actualArrival',
            actualDate: 'actualEndDate',
            actualEndDate: 'actualDate',
          } as const
        )[
          field.label as
            'actualArrival' | 'actualDeparture' | 'actualDate' | 'actualEndDate'
        ]
      : undefined
    const coordinate = actualLabel
      ? p(actualLabel)
      : field.key.startsWith('destination.') && field.key !== 'destination.name'
        ? `${p(field.label)} (${p('fieldTo')})`
        : p(field.label)
    return (
      <div
        key={field.key}
        className={field.type === 'textarea' ? 'sm:col-span-2' : ''}
      >
        {field.type === 'checkbox' ? (
          <label
            className="flex min-h-11 cursor-pointer items-center gap-3"
            htmlFor={id}
          >
            <input
              id={id}
              type="checkbox"
              className="size-5 accent-[var(--brand)]"
              checked={value === true}
              disabled={pending}
              onChange={(event) => update(event.target.checked)}
            />
            {coordinate}
          </label>
        ) : (
          <>
            <Label htmlFor={id} className="mb-2 block">
              {coordinate}
              {field.required && <span aria-hidden> *</span>}
            </Label>
            {field.type === 'select' ? (
              <select
                id={id}
                className="planner-select"
                value={stringValue}
                required={field.required}
                disabled={pending}
                onChange={(event) => update(event.target.value)}
              >
                <option value="">{p('none')}</option>
                {options.map(([v, label]) => (
                  <option value={v} key={v}>
                    {label}
                  </option>
                ))}
              </select>
            ) : field.type === 'textarea' ? (
              <Textarea
                id={id}
                value={stringValue}
                rows={3}
                disabled={pending}
                onChange={(event) => update(event.target.value)}
              />
            ) : (
              <Input
                id={id}
                type={field.type === 'clock' ? 'text' : (field.type ?? 'text')}
                value={stringValue}
                required={field.required}
                min={field.min}
                max={field.max}
                step="any"
                disabled={pending}
                maxLength={field.key === 'currency' ? 3 : undefined}
                pattern={
                  field.type === 'clock'
                    ? field.key === 'end'
                      ? '([01][0-9]|2[0-3]):[0-5][0-9]|24:00'
                      : '([01][0-9]|2[0-3]):[0-5][0-9]'
                    : field.key === 'currency'
                      ? '[A-Za-z]{3}'
                      : undefined
                }
                placeholder={field.type === 'clock' ? 'HH:mm' : undefined}
                onChange={(event) =>
                  update(
                    field.type === 'number' && event.target.value !== ''
                      ? Number(event.target.value)
                      : field.key === 'currency'
                        ? event.target.value.toUpperCase()
                        : event.target.value,
                  )
                }
              />
            )}
            {editor.section === 'activities' &&
              document.places.length > 0 &&
              (field.key === 'location.name' ||
                field.key === 'destination.name') &&
              savedPlace(
                field.key === 'location.name' ? 'location' : 'destination',
              )}
          </>
        )}
      </div>
    )
  }
  async function uploadCover(file: File | undefined) {
    if (!file) return
    if (!mediaFits(draftMedia, [file])) {
      setLocalError(p('mediaLimit'))
      return
    }
    setUploading(true)
    setLocalError('')
    try {
      const photo = await readPhoto(file)
      setDraftMedia((old) => ({ ...old, [photo.name]: photo.bytes }))
      setDraft((old) => ({ ...old, image: photo.name, kind: 'photo' }))
    } catch (cause) {
      setLocalError(
        p(
          cause instanceof Error && cause.message === 'photoTooLarge'
            ? 'photoTooLarge'
            : 'photoUnsupported',
        ),
      )
    } finally {
      setUploading(false)
    }
  }
  const basic = fields[editor.section].filter((field) => !field.advanced)
  const advanced = fields[editor.section].filter((field) => field.advanced)
  return (
    <dialog
      ref={dialog}
      className="planner-dialog"
      aria-labelledby="plan-editor-title"
      onCancel={(event) => {
        event.preventDefault()
        if (!pending) onClose()
      }}
    >
      <form
        onSubmit={async (event) => {
          event.preventDefault()
          setLocalError('')
          if (
            editor.section === 'activities' &&
            Boolean(draft.start) !== Boolean(draft.end)
          ) {
            setLocalError(p('timesPair'))
            return
          }
          if (
            (editor.section === 'activities' || editor.section === 'actuals') &&
            draft.start &&
            draft.end &&
            `${text(draft.endDate || draft.date)}T${text(draft.end)}` <=
              `${text(draft.date)}T${text(draft.start)}`
          ) {
            setLocalError(p('scheduleInvalid'))
            return
          }
          await onSave(
            draft,
            draftMedia,
            editor.section === 'actuals' ? evidence : undefined,
          )
        }}
        aria-busy={pending}
      >
        <div className="planner-dialog-header">
          <h2 id="plan-editor-title" className="text-xl font-semibold">
            {editor.title}
          </h2>
          <Button
            type="button"
            variant="ghost"
            size="icon"
            aria-label={p('actionCancel')}
            disabled={pending}
            onClick={onClose}
          >
            <X />
          </Button>
        </div>
        <div className="planner-dialog-body space-y-5">
          {editor.section === 'activities' && (
            <p className="text-sm text-ink-2">{p('timesHelp')}</p>
          )}
          {editor.section === 'exchangeRates' && (
            <p className="text-sm text-ink-2">{p('rateHelp')}</p>
          )}
          {editor.section === 'places' && (
            <p className="text-sm text-ink-2">{p('coordinatesHelp')}</p>
          )}
          {editor.section === 'actuals' && (
            <p className="text-sm text-ink-2">{p('actualHelp')}</p>
          )}
          <div className="grid gap-5 sm:grid-cols-2">
            {basic.map(renderField)}
          </div>
          {editor.section === 'actuals' && (
            <ActualEvidence
              value={evidence}
              onChange={setEvidence}
              media={draftMedia}
              onMedia={setDraftMedia}
              busy={pending}
              onBusy={setUploading}
            />
          )}
          {advanced.length > 0 && (
            <details className="border-t pt-4">
              <summary className="cursor-pointer font-medium">
                {p('moreDetails')}
              </summary>
              <div className="mt-4 grid gap-5 sm:grid-cols-2">
                {advanced.map(renderField)}
              </div>
            </details>
          )}
          {editor.section === 'banner' && (
            <div className="space-y-3">
              <Label htmlFor="cover-upload">{p('bannerFromDevice')}</Label>
              <Input
                id="cover-upload"
                type="file"
                accept="image/jpeg,image/png,image/webp,image/gif"
                disabled={pending}
                onChange={(event) => void uploadCover(event.target.files?.[0])}
              />
              {imageSource(draftMedia[text(draft.image)]) && (
                <img
                  src={imageSource(draftMedia[text(draft.image)])}
                  alt={p('choosePhoto')}
                  className="max-h-52 w-full rounded object-contain"
                />
              )}
              <p className="text-xs text-ink-3">{p('photoTooLarge')}</p>
            </div>
          )}
          {(error || localError) && (
            <div
              role="alert"
              className="rounded border border-bad/30 bg-bad-bg p-3 text-sm text-bad"
            >
              {localError || error}
              {error === p('stale') && (
                <Button
                  type="button"
                  variant="outline"
                  className="mt-3"
                  disabled={pending}
                  onClick={onReload}
                >
                  {p('discardReload')}
                </Button>
              )}
            </div>
          )}
        </div>
        <div className="planner-dialog-footer">
          <Button
            type="button"
            variant="outline"
            disabled={pending}
            onClick={onClose}
          >
            {p('actionCancel')}
          </Button>
          <Button type="submit" disabled={pending}>
            {pending ? <LoaderCircle className="animate-spin" /> : <Save />}
            {pending ? p('saving') : p('actionSave')}
          </Button>
        </div>
      </form>
    </dialog>
  )
}
