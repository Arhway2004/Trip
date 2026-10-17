import { useState } from 'react'
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
import { r } from './copy'

export function Confirm({
  title,
  description,
  disabled,
  onConfirm,
  onClose,
}: {
  title: string
  description: string
  disabled: boolean
  onConfirm: () => Promise<boolean>
  onClose: () => void
}) {
  const [error, setError] = useState(''),
    [saving, setSaving] = useState(false)
  return (
    <AlertDialog
      open
      onOpenChange={(open) => {
        if (!open && !saving && !disabled) onClose()
      }}
    >
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{title}</AlertDialogTitle>
          <AlertDialogDescription>{description}</AlertDialogDescription>
        </AlertDialogHeader>
        {error && (
          <p role="alert" className="text-sm text-bad">
            {error}
          </p>
        )}
        <AlertDialogFooter>
          <AlertDialogCancel disabled={disabled || saving}>
            {r('c.cancel')}
          </AlertDialogCancel>
          <AlertDialogAction
            disabled={disabled || saving}
            onClick={async (event) => {
              event.preventDefault()
              setSaving(true)
              try {
                if (await onConfirm()) onClose()
                else setError(r('c.saveError', { e: '' }))
              } finally {
                setSaving(false)
              }
            }}
          >
            {r('c.confirm')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
