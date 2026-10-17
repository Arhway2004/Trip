import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ImportedPlan } from './imported-plan'

vi.mock('@tanstack/react-query', () => ({
  useQuery: () => ({
    isPending: false,
    isError: false,
    data: {
      documentJson: JSON.stringify({
        destinations: [{ city: 'Chengdu', country: 'China' }],
        activities: [
          {
            title: 'Flight to Chengdu',
            date: '2026-12-04',
            start: '10:00',
            end: '12:30',
            location: { name: 'Kunming airport' },
            bookingReference: 'QA-123',
            notes: 'Confirm before booking.',
          },
          { title: 'Old town walk', date: '2026-12-05' },
          {
            title: 'Hotel stay',
            date: '2026-12-04',
            start: '15:00',
            endDate: '2026-12-06',
            end: '11:00',
          },
        ],
        photos: [{ file: 'media/unsafe.svg', caption: 'Retained photo' }],
      }),
      media: { 'media/unsafe.svg': 'PHN2Zz4=' },
    },
  }),
}))
vi.mock('../import.functions', () => ({ getImportedPackage: vi.fn() }))
afterEach(cleanup)

describe('imported plan disclosure', () => {
  it('shows activity essentials while keeping extra fields available on expansion', () => {
    render(<ImportedPlan tripId="test-trip" />)
    const title = screen.getByRole('heading', { name: 'Flight to Chengdu' })
    const row = title.closest('details')!
    expect(row.open).toBe(false)
    expect(row.querySelector('summary')!.textContent).toContain('10:00 – 12:30')
    expect(row.querySelector('summary')!.textContent).toContain(
      'Kunming airport',
    )
    expect(row.querySelector('dl')!.textContent).toContain('QA-123')
    expect(row.querySelector('dl')!.textContent).toContain(
      'Confirm before booking.',
    )
    expect(
      screen
        .getByRole('heading', { name: 'Hotel stay' })
        .closest('details')!
        .querySelector('summary')!.textContent,
    ).toContain('15:00 – 6 Dec 11:00')
    // The first day starts open; later days and secondary sections start closed.
    expect(row.parentElement!.closest('details')!.open).toBe(true)
    expect(
      screen
        .getByRole('heading', { name: 'Chengdu', hidden: true })
        .closest('details')!
        .parentElement!.closest('details')!.open,
    ).toBe(false)
  })

  it('keeps untimed activities readable and does not render unsupported media', () => {
    render(<ImportedPlan tripId="test-trip" />)
    const walk = screen
      .getByRole('heading', { name: 'Old town walk', hidden: true })
      .closest('details')!
    expect(walk.querySelector('summary')!.textContent).toContain('Time TBD')
    expect(walk.parentElement!.closest('details')!.open).toBe(false)
    expect(screen.queryByRole('img')).toBeNull()
    expect(screen.getByText('Retained photo')).toBeDefined()
  })
})
