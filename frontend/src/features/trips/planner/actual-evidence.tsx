import { useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { p } from './copy'
import { imageSource, mediaFits, readPhoto, text } from './model'
import type { PlanRow } from './model'

export interface ActualEvidenceDraft {
  expense: PlanRow | null
  photos: Array<PlanRow>
}
export function ActualEvidence({
  value,
  onChange,
  media,
  onMedia,
  busy,
  onBusy,
}: {
  value: ActualEvidenceDraft
  onChange: (next: ActualEvidenceDraft) => void
  media: Record<string, string>
  onMedia: (media: Record<string, string>) => void
  busy: boolean
  onBusy: (busy: boolean) => void
}) {
  const [error, setError] = useState('')
  return (
    <section className="space-y-4 border-t pt-5">
      <p className="text-sm text-ink-2">{p('actualAttachmentsHelp')}</p>
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <label
            htmlFor="actual-cost"
            className="mb-2 block text-sm font-medium"
          >
            {p('actualCost')}
          </label>
          <Input
            id="actual-cost"
            type="number"
            min={0}
            step="any"
            value={text(value.expense?.amount)}
            disabled={busy}
            onChange={(event) =>
              onChange({
                ...value,
                expense: {
                  ...value.expense,
                  amount:
                    event.target.value === ''
                      ? undefined
                      : Number(event.target.value),
                },
              })
            }
          />
        </div>
        <div>
          <label
            htmlFor="actual-currency"
            className="mb-2 block text-sm font-medium"
          >
            {p('currency')}
          </label>
          <Input
            id="actual-currency"
            maxLength={3}
            pattern="[A-Za-z]{3}"
            required={value.expense?.amount != null}
            value={text(value.expense?.currency)}
            disabled={busy}
            onChange={(event) =>
              onChange({
                ...value,
                expense: {
                  ...value.expense,
                  currency: event.target.value.toUpperCase(),
                },
              })
            }
          />
        </div>
      </div>
      <div>
        <label
          htmlFor="actual-photos"
          className="mb-2 block text-sm font-medium"
        >
          {p('addPhoto')}
        </label>
        <Input
          id="actual-photos"
          type="file"
          accept="image/jpeg,image/png,image/webp,image/gif"
          multiple
          disabled={busy}
          onChange={async (event) => {
            const input = event.target,
              files = Array.from(input.files ?? [])
            if (!files.length) return
            setError('')
            if (!mediaFits(media, files)) {
              setError(p('mediaLimit'))
              input.value = ''
              return
            }
            onBusy(true)
            try {
              const added = await Promise.all(files.map(readPhoto))
              const next = { ...media }
              for (const photo of added) next[photo.name] = photo.bytes
              onMedia(next)
              onChange({
                ...value,
                photos: [
                  ...value.photos,
                  ...added.map((photo) => ({
                    file: photo.name,
                    caption: '',
                    isFavorite: false,
                  })),
                ],
              })
            } catch (cause) {
              setError(
                p(
                  cause instanceof Error && cause.message === 'photoTooLarge'
                    ? 'photoTooLarge'
                    : 'photoUnsupported',
                ),
              )
            } finally {
              input.value = ''
              onBusy(false)
            }
          }}
        />
      </div>
      {value.photos.map((photo, index) => (
        <div className="actual-photo" key={text(photo.file)}>
          <img
            src={imageSource(media[text(photo.file)])}
            alt={text(photo.caption) || p('photosTitle')}
          />
          <div className="min-w-0 flex-1">
            <label
              htmlFor={`actual-caption-${index}`}
              className="mb-2 block text-sm"
            >
              {p('actualPhotoCaption')} {index + 1}
            </label>
            <Input
              id={`actual-caption-${index}`}
              value={text(photo.caption)}
              disabled={busy}
              onChange={(event) =>
                onChange({
                  ...value,
                  photos: value.photos.map((row, i) =>
                    i === index ? { ...row, caption: event.target.value } : row,
                  ),
                })
              }
            />
            <Button
              variant="ghost"
              size="sm"
              type="button"
              disabled={busy}
              onClick={() =>
                onChange({
                  ...value,
                  photos: value.photos.filter((_, i) => i !== index),
                })
              }
            >
              {p('actionDelete')}
            </Button>
          </div>
        </div>
      ))}
      {error && (
        <p role="alert" className="text-sm text-bad">
          {error}
        </p>
      )}
    </section>
  )
}
