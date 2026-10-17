import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { emptyTripForm } from '../trip-schema'
import { TripForm } from './trip-form'

afterEach(cleanup)

describe('TripForm', () => {
  it('shows validation messages and does not submit invalid data', async () => {
    const onSubmit = vi.fn()
    render(
      <TripForm
        initialValues={emptyTripForm('UTC')}
        submitLabel="Create trip"
        onSubmit={onSubmit}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Create trip' }))
    expect(await screen.findByText('Enter a title')).toBeTruthy()
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it('submits valid values', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined)
    render(
      <TripForm
        initialValues={emptyTripForm('UTC')}
        submitLabel="Create trip"
        onSubmit={onSubmit}
      />,
    )
    fireEvent.change(screen.getByLabelText('Trip title'), {
      target: { value: 'Kyoto' },
    })
    fireEvent.click(screen.getByRole('button', { name: 'Create trip' }))
    await waitFor(() => expect(onSubmit).toHaveBeenCalledOnce())
    expect(onSubmit.mock.calls[0][0].title).toBe('Kyoto')
  })

  it('shows field errors returned by the API next to the field', () => {
    render(
      <TripForm
        initialValues={emptyTripForm('UTC')}
        submitLabel="Save"
        serverErrors={{
          timeZone: 'must be an IANA time zone such as Asia/Shanghai',
        }}
        onSubmit={vi.fn()}
      />,
    )
    expect(
      screen.getByText('must be an IANA time zone such as Asia/Shanghai'),
    ).toBeTruthy()
  })
})
