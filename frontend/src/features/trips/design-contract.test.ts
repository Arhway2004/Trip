import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { bannerGradient } from './domain'

// Both clients deliberately share a visual identity. Catch accidental drift
// without taking ownership of either client's rendering implementation.
describe('web and Flutter design contract', () => {
  it('uses the same neutral surfaces, ink and forest colors', () => {
    const css = readFileSync('src/styles.css', 'utf8')
    const flutter = readFileSync(
      '../mobile/lib/shared/presentation/theme/app_theme.dart',
      'utf8',
    )
    for (const [web, mobile, hex] of [
      ['canvas', 'canvas', 'F7F9F8'],
      ['surface', 'surface', 'FFFFFF'],
      ['ink', 'ink', '1F2923'],
      ['ink-2', 'ink2', '4D5C53'],
      ['ink-3', 'ink3', '5C6B62'],
      ['line', 'line', 'DCE3DE'],
      ['brand', 'brand', '245C46'],
      ['brand-soft', 'brandSoft', 'EAF2ED'],
      ['vermilion', 'accent', 'B64B32'],
    ]) {
      expect(css.toLowerCase()).toContain(`--${web}: #${hex.toLowerCase()}`)
      expect(flutter).toContain(`${mobile}: Color(0xFF${hex})`)
    }
  })
  it('assigns the same new-trip cover colors for every palette entry', () => {
    const dart = readFileSync(
      '../mobile/lib/contexts/trip/domain/banner.dart',
      'utf8',
    )
      .split('const bannerGradients')[1]
      .split('const bannerSolidColors')[0]
    const pairs = [
      ...dart.matchAll(/\(0xFF([\da-f]{6}),\s*0xFF([\da-f]{6})\)/gi),
    ]
    expect(pairs).toHaveLength(8)
    pairs.forEach((pair, i) =>
      expect(bannerGradient(String.fromCharCode(48 + i))).toEqual([
        `#${pair[1]}`,
        `#${pair[2]}`,
      ]),
    )
  })
  it('bundles identical typefaces in both applications', () => {
    for (const font of ['DM-Sans.ttf', 'Newsreader.ttf']) {
      expect(
        readFileSync(`public/fonts/${font}`).equals(
          readFileSync(`../mobile/assets/fonts/${font}`),
        ),
      ).toBe(true)
    }
  })
})
