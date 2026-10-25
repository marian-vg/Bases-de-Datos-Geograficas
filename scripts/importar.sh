#!/usr/bin/env bash
# Loads shapes/ into the tables created by actividades-sql/02-crear-tablas.sql.
# Only fills empty tables: rerunning never duplicates rows.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d --wait postgres

# PGDATABASE permite verificar la misma carga en una base de prueba aislada.
PGDATABASE=${PGDATABASE:-bdg_entrerios}
PG="PG:host=postgres dbname=$PGDATABASE user=postgres"

psql_importacion() {
  docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U postgres -d "$PGDATABASE" "$@"
}

ogr() {
  docker compose run --rm -T gdal ogr2ogr -f PostgreSQL "$PG" "$@"
}

importar() {
  local tabla=$1 archivo=$2
  shift 2
  [[ -f "shapes/$archivo" ]] || { printf 'Falta shapes/%s\n' "$archivo" >&2; return 1; }
  if [[ $(psql_importacion -Atc "SELECT count(*) > 0 FROM entrerios.$tabla") == t ]]; then
    printf 'Conservando entrerios.%s (ya tiene datos).\n' "$tabla"
    return
  fi
  printf 'Cargando entrerios.%s desde %s\n' "$tabla" "$archivo"
  ogr "/data/$archivo" -append -nln "entrerios.$tabla" "$@"
}

importar_calles() {
  local archivo
  for archivo in calles_er.gpkg highways_er_completo.gpkg export-calles-concordia-ER.geojson; do
    [[ -f "shapes/$archivo" ]] || { printf 'Falta shapes/%s\n' "$archivo" >&2; return 1; }
  done
  if [[ $(psql_importacion -Atc "SELECT count(*) > 0 FROM entrerios.calles") == t ]]; then
    printf 'Conservando entrerios.calles (ya tiene datos).\n'
    return
  fi
  # Base geométrica provincial: highways aporta etiquetas por ID, no más líneas.
  # Concordia completa etiquetas y agrega 53 tramos. El derivado solo es temporal.
  docker compose run --rm -T gdal python3 - "$PG" <<'PY'
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from osgeo import ogr

ogr.UseExceptions()
campos = '''access admin_level alt_name bicycle boundary bridge check_date:surface
covered cycleway cycleway:left cycleway:right description email embankment fixme
foot highway horse incline junction lane_markings lanes layer lit loc_name locked
man_made maxheight maxspeed maxspeed:type name noname note official_name old_name
old_ref oneway parking:both:fee:conditional parking:lane:both ref short_name
sidewalk smoothness sorting_name source source:surface surface width'''.split()

fuente = ogr.Open('/data/highways_er_completo.gpkg')
etiquetas = {}
for tramo in fuente.GetLayer():
    identificador = tramo['osm_type'] + '/' + tramo['osm_id']
    etiquetas[identificador] = {c: tramo[c] for c in campos
                                if tramo.GetFieldIndex(c) >= 0 and tramo[c] is not None}

fuente = ogr.Open('/data/calles_er.gpkg')
calles = {}
for tramo in fuente.GetLayer():
    identificador = tramo['osm_type'] + '/' + tramo['osm_id']
    assert identificador not in calles, 'ID provincial repetido: ' + identificador
    # Los atributos de calles_er están desplazados: solo se toman ID y geometría.
    calles[identificador] = {
        'type': 'Feature',
        'geometry': json.loads(tramo.GetGeometryRef().ExportToJson(['COORDINATE_PRECISION=17'])),
        'properties': dict(etiquetas.get(identificador, {}))}

with open('/data/export-calles-concordia-ER.geojson', encoding='utf-8') as archivo:
    for tramo in json.load(archivo)['features']:
        identificador = tramo['properties']['@id']
        if identificador not in calles:
            calles[identificador] = {'type': 'Feature', 'geometry': tramo['geometry'], 'properties': {}}
        # Concordia tiene prioridad solo para las etiquetas que efectivamente aporta.
        calles[identificador]['properties'].update({c: tramo['properties'][c] for c in campos
            if tramo['properties'].get(c) is not None})

for identificador, tramo in calles.items():
    tramo['properties'].update({'id': identificador, '@id': identificador})
with tempfile.TemporaryDirectory() as temporal:
    salida = Path(temporal) / 'calles.geojson'
    with salida.open('w', encoding='utf-8') as archivo:
        json.dump({'type': 'FeatureCollection', 'features': list(calles.values())},
                  archivo, ensure_ascii=False)
    subprocess.run(['ogr2ogr', '-f', 'PostgreSQL', sys.argv[1], str(salida),
                    '-append', '-nln', 'entrerios.calles', '-nlt', 'LINESTRING',
                    '-ds_transaction'], check=True)
print('Calles integradas:', len(calles))
PY
}

# Departments and soil use an integer id: keep the source FID as id.
importar departamentos departamento_entrerios.gpkg -preserve_fid
importar suelo suelo_entre_rios.gpkg -preserve_fid
importar salud export-hospitales-ER.geojson
importar rios export-rios-ER.geojson
importar rutas export-rutas-ER.geojson
importar_calles
# The table only accepts (multi)polygons: the 3 lines of the export are skipped.
importar lagunas export-lagunas-ER.geojson -nlt MULTIPOLYGON \
  -where "OGR_GEOMETRY IN ('POLYGON', 'MULTIPOLYGON')"
# Mariano's localities export has no locality in Concordia, so localities come
# from the course layer (same OSM format). The id keeps the 'node/123' style.
importar localidades ciudades_er.gpkg \
  -sql "SELECT *, CONCAT(osm_type, '/', osm_id) AS id FROM INPUT"

# Activity 6: load checks and ST_MakeValid corrections.
psql_importacion < actividades-sql/actividad-06.sql
