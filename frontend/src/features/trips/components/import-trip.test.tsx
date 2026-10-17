import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react'
import {
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  vi,
} from 'vitest'
import { ImportTrip } from './import-trip'

const mocks = vi.hoisted(() => ({
  importTrip: vi.fn(),
  navigate: vi.fn(),
  invalidate: vi.fn(),
  setData: vi.fn(),
}))
vi.mock('../import.functions', () => ({
  importTrip: mocks.importTrip,
  MAX_IMPORT_BYTES: 20 * 1024 * 1024,
}))
vi.mock('@tanstack/react-query', () => ({
  useQueryClient: () => ({
    invalidateQueries: mocks.invalidate,
    setQueryData: mocks.setData,
  }),
}))
vi.mock('@tanstack/react-router', () => ({ useNavigate: () => mocks.navigate }))
beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute('open', '')
  }
  HTMLDialogElement.prototype.close = function () {
    this.removeAttribute('open')
  }
})
beforeEach(() => vi.clearAllMocks())
afterEach(cleanup)
const openImport = () => {
  render(<ImportTrip />)
  fireEvent.click(screen.getByRole('button', { name: 'Import trip' }))
}
const submit = () =>
  fireEvent.click(
    screen.getByRole('dialog').querySelector('button[type="submit"]')!,
  )

describe('web trip import', () => {
  it('uploads a mobile package, refreshes trips, and opens the new trip', async () => {
    mocks.importTrip.mockResolvedValue({
      ok: true,
      data: { id: 'new-trip', title: 'Imported' },
    })
    openImport()
    const file = new File(['package bytes'], 'friend.wanderplan')
    fireEvent.change(screen.getByLabelText('Choose a file'), {
      target: { files: [file] },
    })
    submit()
    await waitFor(() =>
      expect(mocks.navigate).toHaveBeenCalledWith({
        to: '/trips/$tripId',
        params: { tripId: 'new-trip' },
      }),
    )
    expect(mocks.importTrip.mock.calls[0][0].data.get('file')).toBe(file)
    expect(mocks.invalidate).toHaveBeenCalledWith({ queryKey: ['trips'] })
  })
  it('submits pasted JSON through the same import endpoint', async () => {
    mocks.importTrip.mockResolvedValue({ ok: true, data: { id: 'pasted' } })
    openImport()
    fireEvent.click(screen.getByRole('button', { name: 'Paste JSON' }))
    fireEvent.change(screen.getByLabelText('Paste JSON'), {
      target: { value: '{"format":"wanderplan.trip"}' },
    })
    submit()
    await waitFor(() => expect(mocks.importTrip).toHaveBeenCalledOnce())
    expect(mocks.importTrip.mock.calls[0][0].data.get('file').name).toBe(
      'trip.json',
    )
  })
  it('keeps the dialog open and shows the exact invalid activity', async () => {
    mocks.importTrip.mockResolvedValue({
      ok: false,
      problem: {
        status: 422,
        detail: 'activities[0] (Flight): give both start and end',
      },
    })
    openImport()
    fireEvent.change(screen.getByLabelText('Choose a file'), {
      target: { files: [new File(['{}'], 'bad.json')] },
    })
    submit()
    expect((await screen.findByRole('alert')).textContent).toContain('(Flight)')
    expect(mocks.navigate).not.toHaveBeenCalled()
    expect(screen.getByRole('dialog').hasAttribute('open')).toBe(true)
  })
  it('rejects oversized files before uploading', async () => {
    openImport()
    fireEvent.change(screen.getByLabelText('Choose a file'), {
      target: {
        files: [
          new File([new Uint8Array(20 * 1024 * 1024 + 1)], 'large.wanderplan'),
        ],
      },
    })
    submit()
    expect((await screen.findByRole('alert')).textContent).toContain('20 MB')
    expect(mocks.importTrip).not.toHaveBeenCalled()
  })
  it.each([
    {
      status: 405,
      code: 'route.method_not_allowed',
      detail: 'method not allowed',
    },
    { status: 404, code: 'route.not_found', detail: 'no such endpoint' },
  ])(
    'explains an outdated backend ($status) and allows retrying the same JSON',
    async (problem) => {
      mocks.importTrip.mockResolvedValueOnce({ ok: false, problem })
      openImport()
      fireEvent.click(screen.getByRole('button', { name: 'Paste JSON' }))
      const text = '{"format":"wanderplan.trip"}'
      fireEvent.change(screen.getByLabelText('Paste JSON'), {
        target: { value: text },
      })
      submit()
      const error = await screen.findByRole('alert')
      expect(error.textContent).toContain('Update and restart the backend')
      expect(error.textContent).toContain('clears its trips')
      expect(
        screen.getByLabelText<HTMLTextAreaElement>('Paste JSON').value,
      ).toBe(text)
      expect(mocks.navigate).not.toHaveBeenCalled()
      expect(screen.getByRole('dialog').hasAttribute('open')).toBe(true)

      mocks.importTrip.mockResolvedValueOnce({
        ok: true,
        data: { id: 'retried' },
      })
      submit()
      await waitFor(() =>
        expect(mocks.navigate).toHaveBeenCalledWith({
          to: '/trips/$tripId',
          params: { tripId: 'retried' },
        }),
      )
      expect(mocks.importTrip).toHaveBeenCalledTimes(2)
    },
  )
  it('shows recoverable network failures without losing the selected file', async () => {
    mocks.importTrip.mockRejectedValue(new Error('offline'))
    openImport()
    fireEvent.change(screen.getByLabelText('Choose a file'), {
      target: { files: [new File(['{}'], 'trip.json')] },
    })
    submit()
    expect((await screen.findByRole('alert')).textContent).toContain(
      'Could not import',
    )
    expect(
      screen
        .getByRole('dialog')
        .querySelector<HTMLButtonElement>('button[type="submit"]')!.disabled,
    ).toBe(false)
  })
})
