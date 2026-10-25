#!/usr/bin/env python3
"""Genera actividad-14-resultados.gpkg, el proyecto QGIS (.qgz) y el mapa de la Actividad 14.
Ejecutar desde la raíz del repo, con la base levantada:
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/actividad-14/renderizar-actividad-14.py
Lee la base con scripts/psql.sh en transacciones de solo lectura.
"""
import os
import subprocess
import tempfile
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')

from qgis.core import (
    Qgis, QgsApplication, QgsCoordinateReferenceSystem, QgsCoordinateTransform,
    QgsFillSymbol, QgsLayoutExporter, QgsLayoutItemLabel, QgsLayoutItemLegend,
    QgsLayoutItemMap, QgsLayoutItemPicture, QgsLayoutItemScaleBar, QgsLayoutPoint,
    QgsLayoutSize, QgsLegendStyle, QgsMarkerSymbol, QgsPalLayerSettings,
    QgsPrintLayout, QgsProject, QgsTextBufferSettings, QgsTextFormat,
    QgsUnitTypes, QgsVectorFileWriter, QgsVectorLayer, QgsVectorLayerSimpleLabeling
)
from qgis.PyQt.QtGui import QColor, QFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
GPKG = OUT / 'actividad-14-resultados.gpkg'
NORTE_DST = OUT.parent / 'norte.svg'

app = QgsApplication([], False)
app.initQgis()

project = QgsProject.instance()
project.setFileName(str(OUT / 'actividad-14-composicion.qgz'))
project.setFilePathStorage(Qgis.FilePathType.Relative)
crs = QgsCoordinateReferenceSystem('EPSG:5347')
project.setCrs(crs)

# 1. Resultados: cada capa sale de una consulta sobre el esquema entrerios.
consulta_14 = (ROOT / 'actividades-sql/actividad-14.sql').read_text().split('WITH', 1)[1]
consulta_14 = 'WITH' + consulta_14.strip().rstrip(';')
salud_concordia = """
    SELECT s.id, s.name AS nombre, s.amenity, s.operator, s.emergency, s.geom
    FROM entrerios.salud s
    JOIN entrerios.departamentos d ON ST_Intersects(s.geom, d.geom)
    WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic')
      AND coalesce(s.name, '') !~* 'laborator|kine'"""
capas_sql = {
    'parcelas_candidatas_top5': (consulta_14, 'geom_poligono'),
    'emplazamientos_sugeridos': (consulta_14, 'geom_punto'),
    'localidades_vulnerables': ("""
        SELECT l.id, l.name AS localidad,
               round(ST_Y(l.geom)::numeric, 5) AS latitud, round(ST_X(l.geom)::numeric, 5) AS longitud,
               round((min(ST_Distance(l.geom::geography, s.geom::geography)) / 1000)::numeric, 2) AS dist_hospital_cercano_km,
               l.geom
        FROM entrerios.localidades l
        JOIN entrerios.departamentos d ON ST_Intersects(l.geom, d.geom) AND d.nam = 'Concordia'
        CROSS JOIN (""" + salud_concordia + """) s
        GROUP BY l.id, l.name, l.geom
        HAVING min(ST_Distance(l.geom::geography, s.geom::geography)) > 5000""", 'geom'),
    'efectores_salud_existentes': (salud_concordia, 'geom'),
    'limite_departamento_concordia': ("SELECT id, nam AS nombre, geom FROM entrerios.departamentos WHERE nam = 'Concordia'", 'geom'),
}
if GPKG.exists():
    GPKG.unlink()
temporal = tempfile.TemporaryDirectory()
for tabla, (sql, geometria) in capas_sql.items():
    geojson = ("BEGIN READ ONLY; SELECT json_build_object('type','FeatureCollection','features',"
               "coalesce(json_agg(json_build_object('type','Feature','geometry',ST_AsGeoJSON(q." + geometria + ")::json,"
               "'properties',to_jsonb(q)-'geom'-'geom_poligono'-'geom_punto')), '[]'::json)) FROM (" + sql + ") q; ROLLBACK;")
    crudo = subprocess.check_output([str(ROOT / 'scripts/psql.sh'), '-qAtc', geojson], cwd=ROOT, text=True)
    ruta = Path(temporal.name) / (tabla + '.geojson')
    ruta.write_text(crudo)
    opciones = QgsVectorFileWriter.SaveVectorOptions()
    opciones.driverName = 'GPKG'
    opciones.layerName = tabla
    opciones.actionOnExistingFile = (QgsVectorFileWriter.CreateOrOverwriteLayer if GPKG.exists()
                                     else QgsVectorFileWriter.CreateOrOverwriteFile)
    resultado = QgsVectorFileWriter.writeAsVectorFormatV3(
        QgsVectorLayer(str(ruta), tabla, 'ogr'), str(GPKG), project.transformContext(), opciones)
    assert resultado[0] == QgsVectorFileWriter.NoError, resultado

def cargar_capa(tabla, nombre):
    lyr = QgsVectorLayer(f"{GPKG}|layername={tabla}", nombre, "ogr")
    assert lyr.isValid(), f"No se pudo cargar {tabla}"
    project.addMapLayer(lyr)
    return lyr

# Orden de dibujo (de arriba hacia abajo en leyenda/mapa)
puntos_sugeridos = cargar_capa('emplazamientos_sugeridos', 'Emplazamientos candidatos (Top 5)')
localidades_vuln = cargar_capa('localidades_vulnerables', 'Localidades sin cobertura (> 5 km)')
salud_existente  = cargar_capa('efectores_salud_existentes', 'Efectores de salud actuales')
parcelas_top5    = cargar_capa('parcelas_candidatas_top5', 'Parcelas aptas seleccionadas')
depto_concordia  = cargar_capa('limite_departamento_concordia', 'Límite departamental (Concordia)')

# Simbología
depto_concordia.renderer().setSymbol(QgsFillSymbol.createSimple({
    'color': '249,249,245,255', 'outline_color': '126,135,137', 'outline_width': '0.35'
}))
parcelas_top5.renderer().setSymbol(QgsFillSymbol.createSimple({
    'color': '163,217,165,180', 'outline_color': '34,121,75', 'outline_width': '0.45'
}))
salud_existente.renderer().setSymbol(QgsMarkerSymbol.createSimple({
    'name': 'cross_fill', 'color': '36,113,170', 'outline_color': 'white', 'outline_width': '0.25', 'size': '2.8'
}))
localidades_vuln.renderer().setSymbol(QgsMarkerSymbol.createSimple({
    'name': 'circle', 'color': '230,126,34', 'outline_color': 'white', 'outline_width': '0.3', 'size': '2.8'
}))
puntos_sugeridos.renderer().setSymbol(QgsMarkerSymbol.createSimple({
    'name': 'star', 'color': '194,49,48', 'outline_color': 'white', 'outline_width': '0.35', 'size': '4.5'
}))

# Etiquetas para puestos candidatos y localidades vulnerables
def etiquetar(capa, expresion, color_texto='black', tam=7.5, negrita=False):
    s = QgsPalLayerSettings()
    s.fieldName = expresion
    s.isExpression = True
    s.dist = 1.6
    fmt = QgsTextFormat()
    fmt.setFont(QFont('Noto Sans', int(tam), QFont.Bold if negrita else QFont.Normal))
    fmt.setSize(tam)
    fmt.setColor(QColor(color_texto))
    buf = QgsTextBufferSettings()
    buf.setEnabled(True)
    buf.setSize(0.7)
    buf.setColor(QColor('white'))
    fmt.setBuffer(buf)
    s.setFormat(fmt)
    capa.setLabeling(QgsVectorLayerSimpleLabeling(s))
    capa.setLabelsEnabled(True)

etiquetar(puntos_sugeridos, "'#' || \"puesto\"", '#8B0000', 8.5, True)
etiquetar(localidades_vuln, "\"localidad\"", '#333333', 7.0, False)

# Composición de impresión (mismo formato que Actividad 13)
layout = QgsPrintLayout(project)
layout.initializeDefaults()
layout.setName('Figura - Actividad 14')
layout.pageCollection().page(0).setPageSize(QgsLayoutSize(190, 145))
layout.renderContext().setDpi(360)
project.layoutManager().addLayout(layout)

titulo = QgsLayoutItemLabel(layout)
titulo.setText('Actividad 14. Sitios candidatos para Centro de Emergencia Sanitaria')
titulo.setFont(QFont('Noto Sans', 10, QFont.Bold))
layout.addLayoutItem(titulo)
titulo.attemptMove(QgsLayoutPoint(3, 2))
titulo.attemptResize(QgsLayoutSize(184, 8))

mapa = QgsLayoutItemMap(layout)
layout.addLayoutItem(mapa)
mapa.attemptMove(QgsLayoutPoint(3, 12))
mapa.attemptResize(QgsLayoutSize(112, 128))
mapa.setCrs(crs)
capas_visibles = [puntos_sugeridos, localidades_vuln, salud_existente, parcelas_top5, depto_concordia]
mapa.setLayers(capas_visibles)
mapa.setKeepLayerSet(True)
mapa.setFrameEnabled(True)

tr = QgsCoordinateTransform(QgsCoordinateReferenceSystem('EPSG:4326'), crs, project)
ext = tr.transformBoundingBox(depto_concordia.extent())
ext.scale(1.08)
mapa.zoomToExtent(ext)

leyenda = QgsLayoutItemLegend(layout)
leyenda.setTitle('Referencias')
leyenda.setLinkedMap(mapa)
leyenda.setAutoUpdateModel(False)
root = leyenda.model().rootGroup()
root.removeAllChildren()
for lyr in capas_visibles:
    root.addLayer(lyr)
leyenda.setStyleFont(QgsLegendStyle.Title, QFont('Noto Sans', 8, QFont.Bold))
leyenda.setStyleFont(QgsLegendStyle.SymbolLabel, QFont('Noto Sans', 7))
layout.addLayoutItem(leyenda)
leyenda.attemptMove(QgsLayoutPoint(118, 12))
leyenda.attemptResize(QgsLayoutSize(69, 90))

if NORTE_DST.exists():
    norte = QgsLayoutItemPicture(layout)
    norte.setPicturePath(str(NORTE_DST))
    norte.setSvgFillColor(QColor('black'))
    norte.setSvgStrokeColor(QColor('black'))
    norte.setLinkedMap(mapa)
    layout.addLayoutItem(norte)
    norte.attemptMove(QgsLayoutPoint(6, 15))
    norte.attemptResize(QgsLayoutSize(8, 8))

escala = QgsLayoutItemScaleBar(layout)
escala.setStyle('Single Box')
escala.setLinkedMap(mapa)
escala.applyDefaultSize()
escala.setUnits(QgsUnitTypes.DistanceKilometers)
escala.setUnitsPerSegment(10)
escala.setNumberOfSegments(2)
escala.setNumberOfSegmentsLeft(0)
escala.setUnitLabel('km')
escala.setFont(QFont('Noto Sans', 7))
escala.setHeight(1.3)
layout.addLayoutItem(escala)
escala.attemptMove(QgsLayoutPoint(6, 130))
escala.attemptResize(QgsLayoutSize(35, 7))

project.setTitle('Actividad 14 - Centro de Atención Sanitaria de Emergencia')
project.write()

png_out = OUT / 'actividad-14-sitios-candidatos.png'
settings = QgsLayoutExporter.ImageExportSettings()
settings.dpi = 360
QgsLayoutExporter(layout).exportToImage(str(png_out), settings)
print("Generado con éxito:", png_out)
