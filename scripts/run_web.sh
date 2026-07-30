#!/usr/bin/env bash
# Starts the CORS proxy and Flutter web together.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

cleanup() {
  if [[ -n "${PROXY_PID:-}" ]] && kill -0 "$PROXY_PID" 2>/dev/null; then
    kill "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "→ Iniciando proxy Steam en :8787"
dart run tool/steam_proxy.dart &
PROXY_PID=$!

# Wait until proxy accepts connections
for _ in $(seq 1 30); do
  if curl -sf "http://localhost:8787/" >/dev/null 2>&1 || \
     curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8787/" | grep -qE '404|200'; then
    break
  fi
  sleep 0.2
done

echo "→ Iniciando Flutter web en http://localhost:8080"
flutter run -d chrome --web-hostname=localhost --web-port=8080 "$@"
