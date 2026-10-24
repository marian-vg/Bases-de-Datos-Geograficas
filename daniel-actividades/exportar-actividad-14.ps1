# ============================================================================
# Exportación de Resultados de la Actividad 14 a GeoPackage (.gpkg) para QGIS
# ============================================================================
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath (Split-Path -Parent $MyInvocation.MyCommand.Path)
$targetDir = (Get-Location).Path
$pgConn = "PG:host=postgres dbname=bdg_entrerios user=postgres"

Write-Host "Generando capas en contenedor GDAL y exportando a $targetDir\actividad-14-resultados.gpkg..."

# Script interno que corre en GDAL (crea en /tmp para evitar problemas de bloqueo de SQLite en Windows Docker y luego copia a /out)
$shScript = @'
set -e
PG="PG:host=postgres dbname=bdg_entrerios user=postgres"
GPKG="/tmp/actividad-14-resultados.gpkg"
rm -f "$GPKG"

echo "-> Capa 1: parcelas_candidatas_top5"
ogr2ogr -f GPKG "$GPKG" "$PG" \
  -sql "SELECT puesto, id_parcela, unidad_suelo, indice_productividad_inta AS ipc, superficie_ha, localidades_vulnerables_cubiertas, detalle_localidades, dist_media_localidades_km, latitud_sugerida, longitud_sugerida, geom FROM capas.act14_sitios_candidatos ORDER BY puesto" \
  -nln "parcelas_candidatas_top5" -nlt MULTIPOLYGON -a_srs EPSG:4326

echo "-> Capa 2: emplazamientos_sugeridos"
ogr2ogr -f GPKG "$GPKG" "$PG" -update -append \
  -sql "SELECT puesto, id_parcela, unidad_suelo, superficie_ha, localidades_vulnerables_cubiertas, detalle_localidades, latitud_sugerida, longitud_sugerida, geom FROM capas.act14_puntos_emplazamiento ORDER BY puesto" \
  -nln "emplazamientos_sugeridos" -nlt POINT -a_srs EPSG:4326

echo "-> Capa 3: localidades_vulnerables"
ogr2ogr -f GPKG "$GPKG" "$PG" -update -append \
  -sql "SELECT id, localidad, latitud, longitud, dist_hospital_cercano_km, geom FROM capas.act14_localidades_vulnerables ORDER BY dist_hospital_cercano_km DESC" \
  -nln "localidades_vulnerables" -nlt POINT -a_srs EPSG:4326

echo "-> Capa 4: efectores_salud_existentes"
ogr2ogr -f GPKG "$GPKG" "$PG" -update -append \
  -sql "SELECT s.fid AS id, COALESCE(s.name, '(sin nombre)') AS nombre, s.amenity, s.operator, s.emergency, s.geom FROM capas.salud s JOIN capas.departamentos d ON ST_Intersects(s.geom, d.geom) WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic')" \
  -nln "efectores_salud_existentes" -nlt POINT -a_srs EPSG:4326

echo "-> Capa 5: limite_departamento_concordia"
ogr2ogr -f GPKG "$GPKG" "$PG" -update -append \
  -sql "SELECT fid AS id, nam AS nombre, geom FROM capas.departamentos WHERE nam = 'Concordia'" \
  -nln "limite_departamento_concordia" -nlt MULTIPOLYGON -a_srs EPSG:4326

cp "$GPKG" /out/actividad-14-resultados.gpkg
echo "OK: GeoPackage copiado a /out/actividad-14-resultados.gpkg"
'@

$shScript | Out-File -Encoding ascii -FilePath ".\_export_internal.sh"

docker compose -f ../docker-compose.yml run --rm -T -v "${targetDir}:/out" --entrypoint sh gdal /out/_export_internal.sh
Remove-Item -Force ".\_export_internal.sh"

Write-Host "Exportación completada exitosamente: $targetDir\actividad-14-resultados.gpkg"
