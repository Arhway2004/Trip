import {
  cleanup,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react'
import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { parseDocument } from './model'
import { RecordEditor } from './record-editor'
import { p } from './copy'

vi.mock('../plan.functions', () => ({ getPlan: vi.fn() }))

beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function () {
    this.setAttribute('open', '')
  }
  HTMLDialogElement.prototype.close = function () {
    this.removeAttribute('open')
  }
})
afterEach(cleanup)
describe('plan editing recovery', () => {
  it('keeps the draft when saving fails and only offers discarding it for a stale plan', async () => {
    const props = {
      editor: {
        section: 'activities' as const,
        index: 0,
        row: {
          title: 'Museum',
          date: '2026-12-03',
          start: '09:00',
          end: '10:00',
        },
        title: 'Edit',
      },
      document: parseDocument('{}'),
      media: {},
      busy: false,
      error: '',
      onSave: vi.fn(async () => false),
      onClose: vi.fn(),
      onReload: vi.fn(),
    }
    const view = render(<RecordEditor {...props} />)
    fireEvent.change(screen.getByRole('textbox', { name: 'Title' }), {
      target: { value: 'New museum' },
    })
    fireEvent.submit(
      screen.getByRole('button', { name: 'Save' }).closest('form')!,
    )
    await waitFor(() => expect(props.onSave).toHaveBeenCalledOnce())
    view.rerender(<RecordEditor {...props} error={p('saveFailed')} />)
    expect(
      screen.getByRole<HTMLInputElement>('textbox', {
        name: 'Title',
      }).value,
    ).toBe('New museum')
    expect(
      screen.queryByRole('button', { name: p('discardReload') }),
    ).toBeNull()
    view.rerender(<RecordEditor {...props} error={p('stale')} />)
    fireEvent.click(screen.getByRole('button', { name: p('discardReload') }))
    expect(props.onReload).toHaveBeenCalledOnce()
  })
  it('rejects backwards times before attempting a save', async () => {
    const save = vi.fn(async () => true)
    render(
      <RecordEditor
        editor={{
          section: 'activities',
          index: 0,
          row: {
            title: 'Museum',
            date: '2026-12-03',
            start: '12:00',
            end: '10:00',
          },
          title: 'Edit',
        }}
        document={parseDocument('{}')}
        media={{}}
        busy={false}
        error=""
        onSave={save}
        onClose={() => {}}
        onReload={() => {}}
      />,
    )
    fireEvent.submit(
      screen.getByRole('button', { name: 'Save' }).closest('form')!,
    )
    expect(screen.getByRole('alert').textContent).toContain(
      p('scheduleInvalid'),
    )
    expect(save).not.toHaveBeenCalled()
  })
})
