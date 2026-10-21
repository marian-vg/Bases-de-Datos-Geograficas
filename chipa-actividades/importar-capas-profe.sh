#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Teacher files are read-only inputs; existing tables are never overwritten.
[[ -f .env ]] || { echo 'Primero ejecutar ./scripts/preparar.sh' >&2; exit 1; }
set -a
source .env
set +a
export PGPASSWORD="$POSTGRES_PASSWORD"
command -v ogr2ogr >/dev/null || { echo 'Se requiere ogr2ogr (gdal-bin).' >&2; exit 1; }
./scripts/psql.sh -c 'CREATE SCHEMA IF NOT EXISTS fuentes_profe;'
importar() {
  local tabla=$1 archivo=$2
  shift 2
  [[ -f "$archivo" ]] || { printf 'Falta %s\n' "$archivo" >&2; return 1; }
  if [[ $(./scripts/psql.sh -Atc "SELECT to_regclass('fuentes_profe.$tabla') IS NOT NULL") == t ]]; then
    printf 'Conservando fuentes_profe.%s (ya existe).\n' "$tabla"
    return
  fi
  ogr2ogr -f PostgreSQL \
    "PG:host=127.0.0.1 port=${POSTGRES_PORT:-5434} dbname=bdg_entrerios user=postgres" \
    "$archivo" -nln "fuentes_profe.$tabla" \
    -lco GEOMETRY_NAME=geom -lco FID=fid -nlt GEOMETRY -t_srs EPSG:4326 "$@"
}
# The processed department names contain replacement characters. The complete
# raw DBF stores Latin-1 bytes; selecting province code 30 preserves real names.
importar departamentos Capas_Profe/data_raw/departamento/departamentoPolygon.shp \
  -oo ENCODING=LATIN1 -where "in1 LIKE '30%'"
importar ciudades Capas_Profe/data_processed/ciudades_er.gpkg
importar rios Capas_Profe/data_processed/rios_er.gpkg
importar calles Capas_Profe/data_processed/calles_er.gpkg
importar rutas Capas_Profe/data_processed/highways_er_completo.gpkg
printf '\nCapas disponibles en fuentes_profe; entrerios y fuentes se conservaron.\n'
