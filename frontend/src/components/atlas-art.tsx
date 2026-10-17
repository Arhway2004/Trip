/** Schematic route artwork: a brand motif, never presented as a real map. */
export function RouteArtwork({ className }: { className?: string }) {
  return (
    <svg
      className={className ?? 'atlas-cover-art'}
      viewBox="0 0 600 300"
      fill="none"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      <g stroke="currentColor" strokeWidth=".8" opacity=".17">
        {[0, 1, 2, 3, 4, 5].map((i) => (
          <path
            key={i}
            d={`M${330 + i * 22} -40 C${170 + i * 20} 70 ${650 - i * 14} 120 ${420 + i * 12} 330`}
          />
        ))}
        {[0, 1, 2].map((i) => (
          <path
            key={i}
            d={`M-40 ${80 + i * 24} C80 ${-10 + i * 28} 130 ${240 + i * 16} 300 ${300 + i * 20}`}
          />
        ))}
        <path d="M440 30v30m-15-15h30M540 230v30m-15-15h30M100 30v20m-10-10h20" />
      </g>
      <path
        d="M310 235C290 175 427 199 423 140S480 64 520 78"
        stroke="currentColor"
        strokeWidth="1.4"
        strokeDasharray="5 6"
        opacity=".65"
      />
      <circle cx="310" cy="235" r="5" fill="currentColor" />
      <circle cx="423" cy="140" r="4" fill="currentColor" />
      <circle cx="520" cy="78" r="11" stroke="#ecb394" strokeWidth="1" />
      <circle cx="520" cy="78" r="4" fill="#ecb394" />
    </svg>
  )
}
export function AtlasMark() {
  return (
    <svg
      className="atlas-brand-mark"
      viewBox="0 0 34 40"
      fill="none"
      aria-hidden="true"
    >
      <path d="M3 4h28v32H3z" stroke="currentColor" strokeWidth="1.5" />
      <path
        d="M9 0v8m16-8v8M9 32v8m16-8v8"
        stroke="currentColor"
        strokeWidth="1.5"
      />
      <path d="m10 27 5-14 3 10 6-13" stroke="currentColor" strokeWidth="1.6" />
      <circle cx="24" cy="10" r="2.5" fill="var(--vermilion)" />
    </svg>
  )
}
