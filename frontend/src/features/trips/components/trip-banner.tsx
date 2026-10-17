import { cn } from '#/lib/utils'
import { RouteArtwork } from '#/components/atlas-art'
import { bannerGradient } from '../domain'
import { color, imageSource, text } from '../planner/model'
import type { PlanRow } from '../planner/model'

export function TripBanner({
  tripId,
  className,
  children,
  banner,
  media,
}: {
  tripId: string
  className?: string
  children?: React.ReactNode
  banner?: PlanRow
  media?: Record<string, string>
}) {
  const [a, b] = bannerGradient(tripId)
  const photo = imageSource(media?.[text(banner?.image)])
  const primary = color(banner?.colorA, a),
    secondary = color(banner?.colorB, b)
  const ink = color(banner?.textColor, '#fffdf8')
  const channels = [1, 3, 5].map((index) =>
    parseInt(ink.slice(index, index + 2), 16),
  )
  const darkInk =
    channels[0] * 0.299 + channels[1] * 0.587 + channels[2] * 0.114 < 145
  return (
    <div
      className={cn('atlas-cover', className)}
      data-placement={text(banner?.titlePlacement)}
      data-banner-style={text(banner?.style)}
      style={{
        background:
          banner?.kind === 'solid'
            ? primary
            : `linear-gradient(115deg, ${primary}, ${secondary})`,
        color: ink,
      }}
    >
      {banner?.kind === 'photo' && photo ? (
        <div className="atlas-cover-photo">
          <img
            src={photo}
            alt=""
            style={{
              objectPosition: `${(Number(banner.alignX ?? 0) + 1) * 50}% ${(Number(banner.alignY ?? 0) + 1) * 50}%`,
              transform: `scale(${Math.min(5, Math.max(1, Number(banner.scale ?? 1)))})`,
            }}
          />
          <div
            className="absolute inset-0"
            style={{ background: darkInk ? '#ffffffbb' : '#00000099' }}
          />
        </div>
      ) : (
        <RouteArtwork />
      )}
      <div className="atlas-cover-content">{children}</div>
    </div>
  )
}
