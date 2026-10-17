#!/usr/bin/env bash
# One command to test on a phone. It starts the WanderPlan backend on this Mac
# (the flight-data key from ../secrets stays on the Mac), then runs the app with
# this Mac's address built in. The app signs in to the demo account by itself:
# nothing to type on the phone. The backend stops when you quit (q).
#
#   mobile/tool/run_phone.sh            # pick the device when asked
#   mobile/tool/run_phone.sh -d <id>    # extra arguments go to `flutter run`
set -euo pipefail

mobile="$(cd "$(dirname "$0")/.." && pwd)"
root="$(dirname "$mobile")"
port=8080

# Toolchains: Go, and the Flutter SDK this project uses (an older Flutter in
# /opt/homebrew/bin must not win).
[ -d /usr/local/go/bin ] && PATH="/usr/local/go/bin:$PATH"
[ -d "$HOME/Documents/Personal/Program/flutter/bin" ] && PATH="$HOME/Documents/Personal/Program/flutter/bin:$PATH"
export PATH

ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
if [ -z "$ip" ]; then
  echo "This Mac has no Wi-Fi address. Connect it to the same Wi-Fi as your phone." >&2
  exit 1
fi
url="http://$ip:$port"

api_pid=""
if curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null 2>&1; then
  # Only reuse a backend that can sign the app in (an older build can't).
  code="$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$port/v1/auth/demo" || true)"
  if [ "$code" != "200" ]; then
    echo "Port $port is used by an older WanderPlan backend (or another program)." >&2
    echo "Stop it (press Ctrl+C in the window where it runs, e.g. 'make run-mem'), then run this again." >&2
    exit 1
  fi
  echo "Backend already running on port $port; using it."
else
  bin="${TMPDIR:-/tmp}/wanderplan-api"
  log="${TMPDIR:-/tmp}/wanderplan-api.log"
  echo "Building the backend…"
  (cd "$root/backend" && GOTOOLCHAIN=local go build -o "$bin" ./cmd/api)
  echo "Starting the backend (log: $log)…"
  (
    # API keys from ../secrets go to the backend's environment only, never printed.
    set -a
    for f in "$root"/secrets/*.env; do [ -f "$f" ] && . "$f"; done
    set +a
    exec env DATABASE_URL= AUTH_MODE=dev HTTP_ADDR=":$port" \
      DEV_JWT_SECRET=change-me-local-dev-secret-at-least-32-chars "$bin"
  ) >"$log" 2>&1 &
  api_pid=$!
  trap '[ -n "$api_pid" ] && kill "$api_pid" 2>/dev/null; true' EXIT
  for _ in $(seq 1 30); do
    curl -fsS "http://127.0.0.1:$port/healthz" >/dev/null 2>&1 && break
    if ! kill -0 "$api_pid" 2>/dev/null; then
      echo "The backend stopped. Last lines of $log:" >&2
      tail -n 20 "$log" >&2
      exit 1
    fi
    sleep 1
  done
fi

echo "Phone will use $url (same Wi-Fi as this Mac)."
cd "$mobile"
flutter run --dart-define=WANDERPLAN_API_URL="$url" "$@"
