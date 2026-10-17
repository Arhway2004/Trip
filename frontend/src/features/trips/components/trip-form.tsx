import { useForm } from '@tanstack/react-form'
import { useMemo, useState } from 'react'
import { Button } from '#/components/ui/button'
import { Input } from '#/components/ui/input'
import { Label } from '#/components/ui/label'
import { Switch } from '#/components/ui/switch'
import { Textarea } from '#/components/ui/textarea'
import { t } from '#/lib/i18n'
import { m } from '#/paraglide/messages'
import { travelStyles, tripFormSchema } from '../trip-schema'
import type { TripFormValues } from '../trip-schema'

const styleLabels: Record<(typeof travelStyles)[number], () => string> = {
  relaxed: m.style_relaxed,
  balanced: m.style_balanced,
  packed: m.style_packed,
  budget: m.style_budget,
  comfort: m.style_comfort,
  luxury: m.style_luxury,
  adventure: m.style_adventure,
  family: m.style_family,
}

function errorText(errors: ReadonlyArray<unknown>): string | undefined {
  const first = errors.find(Boolean)
  if (!first) return undefined
  const key =
    typeof first === 'string' ? first : (first as { message?: string }).message
  return key ? t(key) : undefined
}

function Section({
  title,
  children,
}: {
  title: string
  children: React.ReactNode
}) {
  return (
    <section className="space-y-5 rounded-lg border bg-surface p-6">
      <h2 className="atlas-eyebrow">{title}</h2>
      {children}
    </section>
  )
}

function FieldMessage({
  id,
  error,
  help,
}: {
  id: string
  error?: string
  help?: string
}) {
  if (error) {
    return (
      <p id={id} className="text-sm text-bad">
        {error}
      </p>
    )
  }
  return help ? (
    <p id={id} className="text-sm text-ink-3">
      {help}
    </p>
  ) : null
}

/**
 * Create/edit form. Client validation mirrors the API; field errors returned
 * by the API (422) are shown next to the matching fields via `serverErrors`.
 */
export function TripForm({
  initialValues,
  submitLabel,
  serverErrors,
  onSubmit,
  showArchived = false,
}: {
  initialValues: TripFormValues
  submitLabel: string
  serverErrors?: Record<string, string>
  onSubmit: (values: TripFormValues) => Promise<void>
  showArchived?: boolean
}) {
  const [dismissed, setDismissed] = useState<Record<string, boolean>>({})
  const form = useForm({
    defaultValues: initialValues,
    validators: { onSubmit: tripFormSchema },
    onSubmit: async ({ value }) => {
      setDismissed({})
      await onSubmit(value)
    },
  })
  const timeZones = useMemo(() => {
    try {
      return Intl.supportedValuesOf('timeZone')
    } catch {
      return ['UTC']
    }
  }, [])

  const serverError = (name: string) =>
    dismissed[name] ? undefined : serverErrors?.[name]

  function text(
    name:
      | 'title'
      | 'description'
      | 'startDate'
      | 'endDate'
      | 'departureTime'
      | 'timeZone'
      | 'currency'
      | 'totalBudget',
    label: string,
    opts: {
      type?: string
      placeholder?: string
      help?: string
      optional?: boolean
      list?: string
      multiline?: boolean
    } = {},
  ) {
    return (
      <form.Field name={name}>
        {(field) => {
          const id = `trip-${name}`
          const error = errorText(field.state.meta.errors) ?? serverError(name)
          const common = {
            id,
            name,
            value: field.state.value,
            onBlur: field.handleBlur,
            'aria-invalid': Boolean(error),
            'aria-describedby': `${id}-msg`,
          }
          return (
            <div className="space-y-1.5">
              <Label htmlFor={id}>
                {label}
                {opts.optional && (
                  <span className="ml-1 font-normal text-ink-3">
                    · {m.optional()}
                  </span>
                )}
              </Label>
              {opts.multiline ? (
                <Textarea
                  {...common}
                  rows={3}
                  onChange={(e) => {
                    field.handleChange(e.target.value)
                    setDismissed((d) => ({ ...d, [name]: true }))
                  }}
                />
              ) : (
                <Input
                  {...common}
                  type={opts.type ?? 'text'}
                  placeholder={opts.placeholder}
                  list={opts.list}
                  onChange={(e) => {
                    field.handleChange(e.target.value)
                    setDismissed((d) => ({ ...d, [name]: true }))
                  }}
                />
              )}
              <FieldMessage id={`${id}-msg`} error={error} help={opts.help} />
            </div>
          )
        }}
      </form.Field>
    )
  }

  return (
    <form
      className="space-y-5"
      noValidate
      onSubmit={(e) => {
        e.preventDefault()
        void form.handleSubmit()
      }}
    >
      <Section title={m.section_basics()}>
        {text('title', m.field_title(), { placeholder: m.field_title_hint() })}
        {text('description', m.field_description(), {
          optional: true,
          multiline: true,
        })}
      </Section>

      <Section title={m.section_dates()}>
        <div className="grid gap-4 sm:grid-cols-2">
          {text('startDate', m.field_start_date(), {
            type: 'date',
            optional: true,
          })}
          {text('endDate', m.field_end_date(), {
            type: 'date',
            optional: true,
          })}
          {text('departureTime', m.field_departure_time(), {
            type: 'time',
            optional: true,
          })}
          {text('timeZone', m.field_time_zone(), {
            list: 'time-zones',
            help: m.field_time_zone_help(),
          })}
        </div>
        <datalist id="time-zones">
          {timeZones.map((z) => (
            <option key={z} value={z} />
          ))}
        </datalist>
        <form.Field name="datesConfirmed">
          {(field) => (
            <div className="flex items-start gap-3">
              <Switch
                id="trip-datesConfirmed"
                checked={field.state.value}
                onCheckedChange={(v) => field.handleChange(v)}
              />
              <div>
                <Label htmlFor="trip-datesConfirmed">
                  {m.field_dates_confirmed()}
                </Label>
                <p className="text-sm text-ink-3">
                  {m.field_dates_confirmed_help()}
                </p>
              </div>
            </div>
          )}
        </form.Field>
      </Section>

      <Section title={m.section_details()}>
        <div className="grid gap-4 sm:grid-cols-3">
          <form.Field name="travelerCount">
            {(field) => {
              const error =
                errorText(field.state.meta.errors) ??
                serverError('travelerCount')
              return (
                <div className="space-y-1.5">
                  <Label htmlFor="trip-travelers">{m.field_travelers()}</Label>
                  <Input
                    id="trip-travelers"
                    type="number"
                    min={1}
                    max={999}
                    value={
                      Number.isNaN(field.state.value) ? '' : field.state.value
                    }
                    aria-invalid={Boolean(error)}
                    onChange={(e) => field.handleChange(e.target.valueAsNumber)}
                  />
                  <FieldMessage id="trip-travelers-msg" error={error} />
                </div>
              )
            }}
          </form.Field>
          {text('currency', m.field_currency(), {
            placeholder: 'THB',
            optional: true,
          })}
          {text('totalBudget', m.field_budget(), {
            type: 'number',
            optional: true,
          })}
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <form.Field name="travelStyle">
            {(field) => (
              <div className="space-y-1.5">
                <Label htmlFor="trip-style">{m.field_travel_style()}</Label>
                <select
                  id="trip-style"
                  className="h-9 w-full rounded-md border bg-surface px-3 text-sm"
                  value={field.state.value}
                  onChange={(e) =>
                    field.handleChange(
                      e.target.value as typeof field.state.value,
                    )
                  }
                >
                  <option value="">{m.style_none()}</option>
                  {travelStyles.map((s) => (
                    <option key={s} value={s}>
                      {styleLabels[s]()}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </form.Field>
          <form.Field name="stage">
            {(field) => (
              <fieldset className="space-y-1.5">
                <legend className="text-sm font-medium">
                  {m.field_stage()}
                </legend>
                <div className="inline-flex rounded-lg border bg-surface-2 p-0.5">
                  {(['dreaming', 'planning'] as const).map((s) => (
                    <label
                      key={s}
                      className="cursor-pointer rounded-md px-3 py-1.5 text-sm font-medium text-ink-2 has-[:checked]:bg-surface has-[:checked]:text-ink has-[:checked]:shadow-soft"
                    >
                      <input
                        type="radio"
                        className="sr-only"
                        name="stage"
                        checked={field.state.value === s}
                        onChange={() => field.handleChange(s)}
                      />
                      {s === 'dreaming'
                        ? m.status_dreaming()
                        : m.status_planning()}
                    </label>
                  ))}
                </div>
                <p className="text-sm text-ink-3">{m.field_stage_help()}</p>
              </fieldset>
            )}
          </form.Field>
        </div>
        {showArchived && (
          <form.Field name="archived">
            {(field) => (
              <div className="flex items-center gap-3">
                <Switch
                  id="trip-archived"
                  checked={field.state.value}
                  onCheckedChange={(v) => field.handleChange(v)}
                />
                <Label htmlFor="trip-archived">{m.status_archived()}</Label>
              </div>
            )}
          </form.Field>
        )}
      </Section>

      <form.Subscribe selector={(s) => s.isSubmitting}>
        {(isSubmitting) => (
          <div className="flex justify-end">
            <Button type="submit" size="lg" disabled={isSubmitting}>
              {isSubmitting ? m.saving() : submitLabel}
            </Button>
          </div>
        )}
      </form.Subscribe>
    </form>
  )
}
