#!/usr/bin/env bash
# Loads shapes/ into the tables created by actividades-sql/02-crear-tablas.sql.
# Only fills empty tables: rerunning never duplicates rows.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --wait postgres

PG='PG:host=postgres dbname=bdg_entrerios user=postgres'

ogr() {
  docker compose run --rm -T gdal ogr2ogr -f PostgreSQL "$PG" "$@"
}

importar() {
  local tabla=$1 archivo=$2
  shift 2
  [[ -f "shapes/$archivo" ]] || { printf 'Falta shapes/%s\n' "$archivo" >&2; return 1; }
  if [[ $(./scripts/psql.sh -Atc "SELECT count(*) > 0 FROM entrerios.$tabla") == t ]]; then
    printf 'Conservando entrerios.%s (ya tiene datos).\n' "$tabla"
    return
  fi
  printf 'Cargando entrerios.%s desde %s\n' "$tabla" "$archivo"
  ogr "/data/$archivo" -append -nln "entrerios.$tabla" "$@"
}

# Departments and soil use an integer id: keep the source FID as id.
importar departamentos departamento_entrerios.gpkg -preserve_fid
importar suelo suelo_entre_rios.gpkg -preserve_fid
importar salud export-hospitales-ER.geojson
importar rios export-rios-ER.geojson
importar rutas export-rutas-ER.geojson
importar calles export-calles-concordia-ER.geojson
# The table only accepts (multi)polygons: the 3 lines of the export are skipped.
importar lagunas export-lagunas-ER.geojson -nlt MULTIPOLYGON \
  -where "OGR_GEOMETRY IN ('POLYGON', 'MULTIPOLYGON')"
# Mariano's localities export has no locality in Concordia, so localities come
# from the course layer (same OSM format). The id keeps the 'node/123' style.
importar localidades ciudades_er.gpkg \
  -sql "SELECT *, CONCAT(osm_type, '/', osm_id) AS id FROM INPUT"

# Activity 6: load checks and ST_MakeValid corrections.
./scripts/psql.sh < actividades-sql/actividad-06.sql
