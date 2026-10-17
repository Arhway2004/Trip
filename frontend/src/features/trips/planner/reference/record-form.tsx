import { useEffect, useId, useRef, useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { text } from '../model'
import type { PlanRow } from '../model'
import { r } from './copy'

export interface Field {
  key: string
  label: string
  type?:
    | 'text'
    | 'number'
    | 'date'
    | 'time'
    | 'url'
    | 'textarea'
    | 'checkbox'
    | 'select'
  options?: Array<[string, string]>
  required?: boolean
  min?: number
  max?: number
}
export function RecordForm({
  title,
  row,
  fields,
  disabled,
  onSave,
  onClose,
  children,
  extra,
}: {
  title: string
  row: PlanRow
  fields: Array<Field>
  disabled: boolean
  onSave: (row: PlanRow) => Promise<boolean>
  onClose: () => void
  children?: React.ReactNode
  extra?: (draft: PlanRow, change: (patch: PlanRow) => void) => React.ReactNode
}) {
  const [draft, setDraft] = useState(row),
    [error, setError] = useState(''),
    [saving, setSaving] = useState(false),
    dialog = useRef<HTMLDialogElement>(null),
    id = useId()
  useEffect(() => {
    dialog.current?.showModal()
    return () => dialog.current?.close()
  }, [])
  return (
    <dialog
      ref={dialog}
      className="planner-dialog"
      aria-label={title}
      onCancel={(event) => {
        if (disabled || saving) event.preventDefault()
        else onClose()
      }}
    >
      <form
        onSubmit={async (event) => {
          event.preventDefault()
          setError('')
          setSaving(true)
          try {
            if (await onSave(draft)) onClose()
            else setError(r('c.saveError', { e: '' }))
          } catch {
            setError(r('c.saveError', { e: '' }))
          } finally {
            setSaving(false)
          }
        }}
      >
        <header className="planner-dialog-header">
          <h3 className="text-xl font-semibold">{title}</h3>
          <Button
            type="button"
            variant="ghost"
            disabled={disabled || saving}
            onClick={onClose}
            aria-label={r('c.close')}
          >
            ×
          </Button>
        </header>
        <div className="planner-dialog-body space-y-4">
          <div className="grid gap-4 sm:grid-cols-2">
            {fields.map((field) => {
              const value = draft[field.key],
                change = (next: unknown) =>
                  setDraft((old) => ({ ...old, [field.key]: next })),
                controlId = `${id}-${field.key}`
              return (
                <label
                  key={field.key}
                  htmlFor={controlId}
                  className={`space-y-2 text-sm ${field.type === 'textarea' ? 'sm:col-span-2' : ''}`}
                >
                  <span className="block font-medium">{r(field.label)}</span>
                  {field.type === 'checkbox' ? (
                    <input
                      id={controlId}
                      type="checkbox"
                      checked={value === true}
                      disabled={disabled || saving}
                      onChange={(event) => change(event.target.checked)}
                    />
                  ) : field.type === 'select' ? (
                    <select
                      id={controlId}
                      className="planner-select w-full"
                      value={text(value)}
                      disabled={disabled || saving}
                      required={field.required}
                      onChange={(event) => change(event.target.value)}
                    >
                      <option value="">—</option>
                      {field.options?.map(([key, label]) => (
                        <option key={key} value={key}>
                          {r(label)}
                        </option>
                      ))}
                    </select>
                  ) : field.type === 'textarea' ? (
                    <textarea
                      id={controlId}
                      className="planner-select min-h-24 w-full"
                      value={text(value)}
                      disabled={disabled || saving}
                      maxLength={20000}
                      onChange={(event) => change(event.target.value)}
                    />
                  ) : (
                    <Input
                      id={controlId}
                      type={field.type || 'text'}
                      step={field.type === 'number' ? 'any' : undefined}
                      min={field.min}
                      max={field.max}
                      required={field.required}
                      disabled={disabled || saving}
                      value={text(value)}
                      maxLength={field.type === 'url' ? 4096 : 2000}
                      onChange={(event) =>
                        change(
                          field.type === 'number'
                            ? event.target.value === ''
                              ? undefined
                              : Number(event.target.value)
                            : event.target.value,
                        )
                      }
                    />
                  )}
                </label>
              )
            })}
          </div>
          {children}
          {extra?.(draft, (patch) => setDraft((old) => ({ ...old, ...patch })))}
          {error && (
            <p role="alert" className="text-sm text-bad">
              {error}
            </p>
          )}
        </div>
        <footer className="planner-dialog-footer">
          <Button
            type="button"
            variant="outline"
            disabled={disabled || saving}
            onClick={onClose}
          >
            {r('c.cancel')}
          </Button>
          <Button type="submit" disabled={disabled || saving}>
            {saving ? r('c.saving') : r('c.save')}
          </Button>
        </footer>
      </form>
    </dialog>
  )
}
