#!/usr/bin/env bash
# Runs once, when the PostgreSQL volume is empty. The database itself is
# created by POSTGRES_DB; schema and tables come from the same scripts used
# without Docker, so there is a single data model.
set -euo pipefail
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -f /actividades-sql/01-crear-esquema.sql \
  -f /actividades-sql/02-crear-tablas.sql
