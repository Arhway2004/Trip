import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import { webcrypto } from 'node:crypto'
import { describe, expect, it, vi } from 'vitest'
import { convertReference } from './import'
import { budgetReport } from './budget'

vi.mock('../../plan.functions', () => ({ getPlan: vi.fn() }))
describe('Reference file compatibility', () => {
  it('converts the real reference sample, including all scenarios and original source metadata', () => {
    const sandbox = {
      window: { CTP: {} } as {
        CTP: {
          Seed: { buildTrip: () => Record<string, unknown> }
          Calc: {
            ctx: (
              trip: unknown,
              scenario: unknown,
            ) => { budget: { planned: number } }
          }
        }
      },
      crypto: webcrypto,
      Intl,
      Date,
      structuredClone,
      console,
    }
    vm.createContext(sandbox)
    for (const file of ['util.js', 'seed.js', 'model.js', 'calc.js'])
      vm.runInContext(
        readFileSync(
          new URL(
            '../../../../../../Reference/Trip/js/' + file,
            import.meta.url,
          ),
          'utf8',
        ),
        sandbox,
      )
    const raw = sandbox.window.CTP.Seed.buildTrip(),
      converted = convertReference({
        schema: 'china-trip-planner',
        schemaVersion: 1,
        trip: raw,
      })!
    expect(converted).toHaveLength(1)
    const doc = converted[0].document
    expect(doc.activities.length).toBeGreaterThan(10)
    expect(doc.scenarios).toHaveLength((raw.scenarios as Array<unknown>).length)
    expect(doc.referenceImport).toEqual(raw)
    expect(doc.attractions).toHaveLength(
      (raw.attractions as Array<unknown>).length,
    )
    const active = (raw.scenarios as Array<Record<string, unknown>>).find(
      (sc) => sc.id === raw.activeScenarioId,
    )!
    const original = sandbox.window.CTP.Calc.ctx(raw, active).budget.planned
    expect(budgetReport(doc, 'THB', 50000).planned).toBeCloseTo(original, 1)
  })
  it('rejects unsupported reference versions and leaves mobile packages to the current importer', () => {
    expect(() =>
      convertReference({ schema: 'china-trip-planner', schemaVersion: 10 }),
    ).toThrow()
    expect(
      convertReference({ format: 'wanderplan.trip', schemaVersion: 3 }),
    ).toBeUndefined()
  })
})
