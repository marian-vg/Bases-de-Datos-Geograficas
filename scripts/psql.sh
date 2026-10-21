#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -t 0 ]]; then
  docker compose exec postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d bdg_entrerios "$@"
else
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d bdg_entrerios "$@"
fi
