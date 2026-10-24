#!/usr/bin/env python3
"""Activity 10 figures: MBR of Entre Ríos (10.2) and health facility clusters (10.4).
Reads the views created by actividades-sql/actividad-10.sql, so run that script first.
Run from the repo root:
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/actividad-10/renderizar-actividad-10.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mapas

OUT = Path(__file__).resolve().parent
GPKG = OUT / 'actividad-10-resultados.gpkg'
GPKG.unlink(missing_ok=True)
project = mapas.proyecto(OUT / 'actividad-10-composiciones.qgz')

# 10.2: real territory against its minimum bounding rectangle.
mbr = mapas.capa(GPKG, 'mbr_entre_rios', 'Superficie', 'SELECT id, capa, superficie_km2, geom FROM entrerios.vw_act10_mbr_entre_rios')
mapas.categorias(mbr, 'capa', {
    'MBR (ST_Envelope) Provincial': ('255,255,255,0', 'MBR (ST_Envelope)', '194,49,48', '0.6'),
    'Territorio Real Provincial': ('163,217,165,220', 'Territorio de Entre Ríos'),
})
# Draw the rectangle on top of the province so its outline is visible.
mbr.renderer().setOrderByEnabled(True)
mbr.renderer().setOrderBy(mapas.QgsFeatureRequest.OrderBy([mapas.QgsFeatureRequest.OrderByClause('id', True)]))
# The MBR was computed in EPSG:5343: drawn in that same system it is an upright rectangle.
posgar = mapas.QgsCoordinateReferenceSystem('EPSG:5343')
mapas.exportar(OUT / 'actividad-10-2-mbr.png', '10.2 · Entre Ríos y su MBR',
               [mbr], mapas.extension(mbr, 1.05, posgar), alto=140, segmento=50, crs=posgar)

# 10.4: facilities by K-Means group, group centroid and convex hull.
grupos = {'1': ('194,49,48', 'Grupo 1'), '2': ('36,113,170', 'Grupo 2'), '3': ('34,121,75', 'Grupo 3')}
cobertura = mapas.capa(GPKG, 'cobertura_grupos', 'Área de cada grupo', """
    SELECT grupo_cluster_id::text AS grupo, total_efectores, geom_cobertura
    FROM entrerios.vw_act10_centroides_clusters_concordia
    -- A group with a single facility has a point as hull: it has no area to draw.
    WHERE ST_GeometryType(geom_cobertura) = 'ST_Polygon'""", 'geom_cobertura')
centros = mapas.capa(GPKG, 'establecimientos_grupo', 'Establecimientos por grupo', """
    SELECT id, nombre, tipo, grupo_cluster_id::text AS grupo, geom
    FROM entrerios.vw_act10_clusters_salud_concordia""")
centroides = mapas.capa(GPKG, 'centroides', 'Centroide de cada grupo', """
    SELECT grupo_cluster_id::text AS grupo, total_efectores, latitud_centroide, longitud_centroide, geom_centroide
    FROM entrerios.vw_act10_centroides_clusters_concordia""", 'geom_centroide')
concordia = mapas.capa(GPKG, 'concordia', 'Concordia',
                       "SELECT id, nam AS nombre, geom FROM entrerios.departamentos WHERE nam = 'Concordia'")
mapas.categorias(centros, 'grupo', grupos)
mapas.punto(centroides, '0,0,0', 'star', '4.2')
mapas.etiquetas(centroides, "'Grupo ' || \"grupo\"", 7)
mapas.relleno(cobertura, '120,120,120,40', '90,90,90', '0.3')
mapas.relleno(concordia, '249,249,245,255', '126,135,137', '0.35')
mapas.exportar(OUT / 'actividad-10-4-agrupamiento.png', '10.4 · Agrupamiento K-Means de establecimientos',
               [centroides, centros, cobertura, concordia], mapas.extension(centros, 1.25), alto=140, segmento=5)
mapas.cerrar(project, GPKG)
