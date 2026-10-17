import { useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useNavigate } from '@tanstack/react-router'
import { FileUp, LoaderCircle, X } from 'lucide-react'
import { Button } from '#/components/ui/button'
import { Label } from '#/components/ui/label'
import { Input } from '#/components/ui/input'
import { Textarea } from '#/components/ui/textarea'
import { m } from '#/paraglide/messages'
import { importTrip, MAX_IMPORT_BYTES } from '../import.functions'

export function ImportTrip() {
  const [open, setOpen] = useState(false)
  const [mode, setMode] = useState<'file' | 'text'>('file')
  const [file, setFile] = useState<File | null>(null)
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const dialog = useRef<HTMLDialogElement>(null)
  function show() {
    setOpen(true)
    dialog.current?.showModal()
  }
  function close() {
    dialog.current?.close()
    setOpen(false)
    setError('')
    setFile(null)
    setText('')
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    setError('')
    const body =
      mode === 'file'
        ? file
        : new File([text], 'trip.json', { type: 'application/json' })
    if (!body || body.size === 0) {
      setError(m.import_empty())
      return
    }
    if (body.size > MAX_IMPORT_BYTES) {
      setError(m.import_size())
      return
    }
    setBusy(true)
    try {
      const form = new FormData()
      form.set('file', body)
      const result = await importTrip({ data: form })
      if (!result.ok) {
        const p = result.problem
        setError(
          p.status === 413
            ? m.import_size()
            : p.status === 405 || p.code === 'route.not_found'
              ? m.import_backend_update()
              : p.status === 503
                ? m.import_unavailable()
                : p.code === 'import.too_new'
                  ? m.import_newer()
                  : (p.detail ?? m.import_failed()),
        )
        return
      }
      queryClient.setQueryData(['trip', result.data.id], result.data)
      await queryClient.invalidateQueries({ queryKey: ['trips'] })
      close()
      setText('')
      setFile(null)
      await navigate({
        to: '/trips/$tripId',
        params: { tripId: result.data.id },
      })
    } catch {
      setError(m.import_failed())
    } finally {
      setBusy(false)
    }
  }
  return (
    <>
      <Button variant="outline" size="lg" onClick={show}>
        <FileUp />
        {m.import_trip()}
      </Button>
      <dialog
        ref={dialog}
        onCancel={(event) => {
          if (busy) event.preventDefault()
          else close()
        }}
        onClose={() => setOpen(false)}
        aria-labelledby="import-title"
        className="fixed inset-0 m-auto max-h-[90dvh] w-[calc(100%-2rem)] max-w-xl overflow-y-auto rounded-lg border bg-surface p-6 text-ink shadow-xl backdrop:bg-black/60"
      >
        {open && (
          <form onSubmit={submit} className="space-y-5" aria-busy={busy}>
            <div className="flex items-center justify-between gap-4">
              <h2 id="import-title" className="text-xl font-bold">
                {m.import_trip()}
              </h2>
              <Button
                type="button"
                size="icon"
                variant="ghost"
                disabled={busy}
                aria-label={m.import_close()}
                onClick={close}
              >
                <X />
              </Button>
            </div>
            <p className="text-sm text-ink-2">{m.import_description()}</p>
            <div
              className="flex gap-2"
              role="group"
              aria-label={m.import_source()}
            >
              <Button
                type="button"
                variant={mode === 'file' ? 'default' : 'outline'}
                aria-pressed={mode === 'file'}
                disabled={busy}
                onClick={() => {
                  setMode('file')
                  setError('')
                }}
              >
                {m.import_file()}
              </Button>
              <Button
                type="button"
                variant={mode === 'text' ? 'default' : 'outline'}
                aria-pressed={mode === 'text'}
                disabled={busy}
                onClick={() => {
                  setMode('text')
                  setError('')
                }}
              >
                {m.import_text()}
              </Button>
            </div>
            {mode === 'file' ? (
              <div className="space-y-2">
                <Label htmlFor="trip-import-file">{m.import_file()}</Label>
                <Input
                  id="trip-import-file"
                  type="file"
                  accept=".json,.wanderplan,.zip,application/json,application/zip"
                  disabled={busy}
                  onChange={(e) => {
                    setFile(e.target.files?.[0] ?? null)
                    setError('')
                  }}
                />
                <p className="text-xs text-ink-3">{m.import_formats()}</p>
              </div>
            ) : (
              <div className="space-y-2">
                <Label htmlFor="trip-import-text">{m.import_text()}</Label>
                <Textarea
                  id="trip-import-text"
                  rows={10}
                  className="font-mono text-xs"
                  value={text}
                  disabled={busy}
                  onChange={(e) => {
                    setText(e.target.value)
                    setError('')
                  }}
                  placeholder={
                    '{ "format": "wanderplan.trip", "schemaVersion": 3, "trip": { "title": "…" } }'
                  }
                />
              </div>
            )}
            <p className="rounded-lg bg-brand-soft p-3 text-sm">
              {m.import_scope()}
            </p>
            {error && (
              <p
                role="alert"
                className="whitespace-pre-wrap rounded-lg border border-bad/30 bg-bad/10 p-3 text-sm text-bad"
              >
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="outline"
                disabled={busy}
                onClick={close}
              >
                {m.import_close()}
              </Button>
              <Button
                type="submit"
                disabled={busy || (mode === 'file' ? !file : !text.trim())}
              >
                {busy && <LoaderCircle className="animate-spin" />}
                {busy ? m.import_busy() : m.import_trip()}
              </Button>
            </div>
          </form>
        )}
      </dialog>
    </>
  )
}
