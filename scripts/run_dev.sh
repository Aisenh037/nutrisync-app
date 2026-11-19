#!/usr/bin/env bash
# ============================================================
# NutriSync — Dev runner
# Loads .env and passes all keys as --dart-define flags.
# Usage: ./scripts/run_dev.sh [extra flutter args]
# Example: ./scripts/run_dev.sh -d chrome
# ============================================================

set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env not found. Copy .env.example → .env and fill in your keys."
  exit 1
fi

# Build --dart-define args from every non-comment, non-empty line in .env
DEFINES=""
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  if [ -n "$value" ]; then
    DEFINES="$DEFINES --dart-define=$key=$value"
  fi
done < "$ENV_FILE"

echo "🚀  Launching NutriSync with injected secrets..."
# shellcheck disable=SC2086
flutter run $DEFINES "$@"
