#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f .env ]]; then
  umask 077
  {
    printf 'POSTGRES_PASSWORD=%s\n' "$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
    printf 'PGADMIN_PASSWORD=%s\n' "$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
    printf 'PGADMIN_EMAIL=usuario@example.com\nPOSTGRES_PORT=5434\nPGADMIN_PORT=5050\n'
  } > .env
fi
docker compose up -d --wait postgres pgadmin
printf '\nBase lista. SQL: ./scripts/psql.sh | Importar capas: ./scripts/importar.sh\n'
