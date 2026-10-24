"""Shared helpers for the activity renderers (same look as the activity 13 maps).

Each layer comes from a SQL query run through scripts/psql.sh in a read-only
transaction and is saved into the activity GeoPackage, so the QGIS project
opens without database credentials.
"""
import os
import subprocess
import tempfile
from pathlib import Path

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from qgis.core import *
from qgis.PyQt.QtGui import QColor, QFont

ROOT = Path(__file__).resolve().parents[1]
NORTE = Path(__file__).resolve().parent / 'norte.svg'
CRS = QgsCoordinateReferenceSystem('EPSG:32721')
FUENTE = 'Noto Sans'

app = QgsApplication([], False)
app.initQgis()
_temporal = tempfile.TemporaryDirectory()


def proyecto(ruta_qgz):
    project = QgsProject.instance()
    project.clear()
    project.setFileName(str(ruta_qgz))
    project.setFilePathStorage(Qgis.FilePathType.Relative)
    project.setCrs(CRS)
    return project


def capa(gpkg, tabla, nombre, sql, geometria='geom'):
    """Runs sql, stores the result as `tabla` in gpkg and adds it to the project."""
    geojson = ("BEGIN READ ONLY; SELECT json_build_object('type','FeatureCollection','features',"
               "coalesce(json_agg(json_build_object('type','Feature','geometry',ST_AsGeoJSON(q." + geometria + ")::json,"
               "'properties',to_jsonb(q)-'geom'-'" + geometria + "')), '[]'::json)) FROM (" + sql + ") q; ROLLBACK;")
    crudo = subprocess.check_output([str(ROOT / 'scripts/psql.sh'), '-qAtc', geojson], cwd=ROOT, text=True)
    ruta = Path(_temporal.name) / (tabla + '.geojson')
    ruta.write_text(crudo)
    opciones = QgsVectorFileWriter.SaveVectorOptions()
    opciones.driverName = 'GPKG'
    opciones.layerName = tabla
    fuente = QgsVectorLayer(str(ruta), tabla, 'ogr')
    # Mixed single/multi parts would break the GeoPackage type: store them all as multi.
    if fuente.geometryType() == QgsWkbTypes.LineGeometry:
        opciones.overrideGeometryType = QgsWkbTypes.MultiLineString
        opciones.forceMulti = True
    elif fuente.geometryType() == QgsWkbTypes.PolygonGeometry:
        opciones.overrideGeometryType = QgsWkbTypes.MultiPolygon
        opciones.forceMulti = True
    opciones.actionOnExistingFile = (QgsVectorFileWriter.CreateOrOverwriteLayer if Path(gpkg).exists()
                                     else QgsVectorFileWriter.CreateOrOverwriteFile)
    resultado = QgsVectorFileWriter.writeAsVectorFormatV3(
        fuente, str(gpkg), QgsProject.instance().transformContext(), opciones)
    assert resultado[0] == QgsVectorFileWriter.NoError, resultado
    guardada = QgsVectorLayer(f'{gpkg}|layername={tabla}', nombre, 'ogr')
    assert guardada.isValid(), tabla
    QgsProject.instance().addMapLayer(guardada)
    return guardada


def relleno(capa_, color, borde, ancho='0.3'):
    capa_.renderer().setSymbol(QgsFillSymbol.createSimple(
        {'color': color, 'outline_color': borde, 'outline_width': ancho}))


def linea(capa_, color, ancho='0.4', estilo='solid'):
    capa_.renderer().setSymbol(QgsLineSymbol.createSimple(
        {'line_color': color, 'line_width': ancho, 'line_style': estilo}))


def punto(capa_, color, forma='circle', tam='2.8'):
    capa_.renderer().setSymbol(QgsMarkerSymbol.createSimple(
        {'name': forma, 'color': color, 'outline_color': 'white', 'outline_width': '0.3', 'size': tam}))


def categorias(capa_, campo, colores, forma=None):
    """One symbol per value of campo; colores maps value -> (color, label[, outline, outline width])."""
    cats = []
    for valor, (color, etiqueta, *borde) in colores.items():
        borde_color, borde_ancho = borde if borde else ('126,135,137', '0.3')
        if capa_.geometryType() == QgsWkbTypes.PolygonGeometry:
            simbolo = QgsFillSymbol.createSimple({'color': color, 'outline_color': borde_color, 'outline_width': borde_ancho})
        else:
            simbolo = QgsMarkerSymbol.createSimple({'name': forma or 'circle', 'color': color, 'outline_color': 'white',
                                                    'outline_width': '0.3', 'size': '3'})
        cats.append(QgsRendererCategory(valor, simbolo, etiqueta))
    capa_.setRenderer(QgsCategorizedSymbolRenderer(campo, cats))


def etiquetas(capa_, expresion, tam=7):
    s = QgsPalLayerSettings()
    s.fieldName = expresion
    s.isExpression = True
    s.dist = 1.2
    formato = QgsTextFormat()
    formato.setFont(QFont(FUENTE, tam))
    formato.setSize(tam)
    buffer = QgsTextBufferSettings()
    buffer.setEnabled(True)
    buffer.setSize(0.6)
    buffer.setColor(QColor('white'))
    formato.setBuffer(buffer)
    s.setFormat(formato)
    capa_.setLabeling(QgsVectorLayerSimpleLabeling(s))
    capa_.setLabelsEnabled(True)


def extension(capa_, margen=1.08, crs=CRS):
    transformacion = QgsCoordinateTransform(capa_.crs(), crs, QgsProject.instance())
    rect = transformacion.transformBoundingBox(capa_.extent())
    rect.scale(margen)
    return rect


def exportar(png, titulo, capas, rect, alto=150, segmento=10, escala_x=6, crs=CRS):
    """Builds a print layout (map, legend, north arrow, scale bar) and exports it at 360 dpi."""
    project = QgsProject.instance()
    layout = QgsPrintLayout(project)
    layout.initializeDefaults()
    layout.setName(titulo)
    layout.pageCollection().page(0).setPageSize(QgsLayoutSize(190, alto))
    layout.renderContext().setDpi(360)
    project.layoutManager().addLayout(layout)

    etiqueta = QgsLayoutItemLabel(layout)
    etiqueta.setText(titulo)
    etiqueta.setFont(QFont(FUENTE, 10, QFont.Bold))
    layout.addLayoutItem(etiqueta)
    etiqueta.attemptMove(QgsLayoutPoint(3, 1))
    etiqueta.attemptResize(QgsLayoutSize(184, 9))

    alto_mapa = alto - 16
    mapa = QgsLayoutItemMap(layout)
    layout.addLayoutItem(mapa)
    mapa.attemptMove(QgsLayoutPoint(3, 12))
    mapa.attemptResize(QgsLayoutSize(112, alto_mapa))
    mapa.setCrs(crs)
    mapa.setLayers(capas)
    mapa.setKeepLayerSet(True)
    mapa.setFrameEnabled(True)
    mapa.zoomToExtent(rect)

    leyenda = QgsLayoutItemLegend(layout)
    leyenda.setTitle('Leyenda')
    leyenda.setLinkedMap(mapa)
    leyenda.setAutoUpdateModel(False)
    raiz = leyenda.model().rootGroup()
    raiz.removeAllChildren()
    for c in capas:
        raiz.addLayer(c)
    leyenda.setStyleFont(QgsLegendStyle.Title, QFont(FUENTE, 8, QFont.Bold))
    leyenda.setStyleFont(QgsLegendStyle.Group, QFont(FUENTE, 8))
    leyenda.setStyleFont(QgsLegendStyle.Subgroup, QFont(FUENTE, 7))
    leyenda.setStyleFont(QgsLegendStyle.SymbolLabel, QFont(FUENTE, 7))
    leyenda.setSymbolWidth(5)
    leyenda.setSymbolHeight(2.6)
    layout.addLayoutItem(leyenda)
    leyenda.attemptMove(QgsLayoutPoint(118, 12))
    leyenda.attemptResize(QgsLayoutSize(69, alto_mapa))

    norte = QgsLayoutItemPicture(layout)
    norte.setPicturePath(str(NORTE))
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
    escala.setUnitsPerSegment(segmento)
    escala.setNumberOfSegments(2)
    escala.setNumberOfSegmentsLeft(0)
    escala.setUnitLabel('km')
    escala.setFont(QFont(FUENTE, 7))
    escala.setHeight(1.3)
    layout.addLayoutItem(escala)
    escala.attemptMove(QgsLayoutPoint(escala_x, 12 + alto_mapa - 10))
    escala.attemptResize(QgsLayoutSize(35, 7))

    ajustes = QgsLayoutExporter.ImageExportSettings()
    ajustes.dpi = 360
    assert QgsLayoutExporter(layout).exportToImage(str(png), ajustes) == QgsLayoutExporter.Success
    print(Path(png).name)


def tabla(png, titulo, columnas, filas):
    """Exports a query result as a small table image (title + HTML table)."""
    project = QgsProject.instance()
    layout = QgsPrintLayout(project)
    layout.initializeDefaults()
    layout.setName(titulo)
    alto = 12 + 6 * (len(filas) + 1)
    layout.pageCollection().page(0).setPageSize(QgsLayoutSize(190, alto))
    layout.renderContext().setDpi(360)
    estilo = 'font-family:Noto Sans;font-size:8pt;border-collapse:collapse;width:100%;'
    # Approximate width in mm from the longest text of each column, so the image has no blank margin.
    largos = [max(len(str(v)) for v in [c] + [f[i] for f in filas]) for i, c in enumerate(columnas)]
    ancho = min(184, max(len(titulo) * 2.4, sum(1.9 * n + 5 for n in largos)))
    celda = 'border-bottom:1px solid #b0b4b6;padding:3px 6px;text-align:left;'
    html = f'<p style="font-family:Noto Sans;font-size:10pt;font-weight:bold;margin:0 0 6px 0">{titulo}</p>'
    html += f'<table style="{estilo}"><tr>' + ''.join(
        f'<th style="{celda}background:#eef0ef">{c}</th>' for c in columnas) + '</tr>'
    for fila in filas:
        html += '<tr>' + ''.join(f'<td style="{celda}">{v}</td>' for v in fila) + '</tr>'
    html += '</table>'
    etiqueta = QgsLayoutItemLabel(layout)
    etiqueta.setMode(QgsLayoutItemLabel.ModeHtml)
    etiqueta.setText(html)
    layout.addLayoutItem(etiqueta)
    etiqueta.attemptMove(QgsLayoutPoint(3, 2))
    etiqueta.attemptResize(QgsLayoutSize(ancho, alto - 4))
    ajustes = QgsLayoutExporter.ImageExportSettings()
    ajustes.dpi = 360
    ajustes.cropToContents = True
    ajustes.cropMargins = QgsMargins(8, 8, 8, 8)
    assert QgsLayoutExporter(layout).exportToImage(str(png), ajustes) == QgsLayoutExporter.Success
    print(Path(png).name)


def consulta(sql):
    """Returns the rows of sql as lists of strings (read-only)."""
    salida = subprocess.check_output([str(ROOT / 'scripts/psql.sh'), '-qAt', '-F', '\t', '-c',
                                      'BEGIN READ ONLY; ' + sql + '; ROLLBACK;'], cwd=ROOT, text=True)
    return [linea_.split('\t') for linea_ in salida.splitlines() if linea_]


def cerrar(project, gpkg):
    assert project.write()
    import sqlite3
    conexion = sqlite3.connect(gpkg)
    conexion.execute('PRAGMA wal_checkpoint(TRUNCATE)')
    conexion.execute('PRAGMA journal_mode=DELETE')
    conexion.close()
    print('Proyecto:', project.fileName())
