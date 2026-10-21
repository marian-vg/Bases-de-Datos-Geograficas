#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --wait postgres
# Never overwrite an existing source table or the student's working tables.
import_layer() {
  local table=$1 file=$2
  local exists
  [[ -f "shapes/$file" ]] || { printf 'Falta shapes/%s\n' "$file" >&2; return 1; }
  exists=$(./scripts/psql.sh -Atc "SELECT to_regclass('fuentes.$table') IS NOT NULL")
  if [[ "$exists" == t ]]; then
    printf 'Conservando fuentes.%s (ya existe).\n' "$table"
    return
  fi
  docker compose run --rm -T gdal ogr2ogr -f PostgreSQL \
    'PG:host=postgres dbname=bdg_entrerios user=postgres' \
    "/data/$file" -nln "fuentes.$table" \
    -lco GEOMETRY_NAME=geom -lco FID=fid -nlt GEOMETRY -t_srs EPSG:4326
}
import_layer departamentos concordia_shape.gpkg
import_layer localidades export-localidades.geojson
import_layer rutas export-rutas-ER.geojson
import_layer rios export-rios-ER.geojson
import_layer lagunas export-lagunas-ER.geojson
import_layer salud export-hospitales-ER.geojson
import_layer suelo suelo_entre_rios.gpkg
./scripts/psql.sh < sql/preparar-capas.sql
./scripts/psql.sh < sql/verificar.sql
