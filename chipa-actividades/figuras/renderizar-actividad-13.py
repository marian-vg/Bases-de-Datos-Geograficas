#!/usr/bin/env python3
"""Render activity 13 with native QGIS print layouts.
Run from any directory: QT_QPA_PLATFORM=offscreen /usr/bin/python3 <this file>
Reads the project's existing PostGIS database through scripts/psql.sh in READ ONLY
transactions; writes only the adjacent GeoPackage, PNGs, SVG and standalone QGZ.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import textwrap
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from qgis.core import *
from qgis.PyQt.QtCore import QPointF
from qgis.PyQt.QtGui import QColor, QFont, QPolygonF

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
app = QgsApplication([], False)
app.initQgis()
project = QgsProject.instance()
project.setFileName(str(OUT / 'actividad-13-composiciones.qgz'))
project.setFilePathStorage(Qgis.FilePathType.Relative)
crs = QgsCoordinateReferenceSystem('EPSG:32721')
project.setCrs(crs)
transform = QgsCoordinateTransform(QgsCoordinateReferenceSystem('EPSG:4326'), crs, project)
gpkg = OUT / 'actividad-13-resultados.gpkg'
if gpkg.exists():
    gpkg.unlink()
queries = re.findall(r'WITH departamento AS \(.*?;', (ROOT / 'chipa-actividades/actividad-13.sql').read_text(), re.S)
assert len(queries) == 2
scratch = tempfile.TemporaryDirectory()

def persist(layer, key, name):
    options = QgsVectorFileWriter.SaveVectorOptions()
    options.driverName = 'GPKG'
    options.layerName = key
    if layer.geometryType() == QgsWkbTypes.LineGeometry:
        options.overrideGeometryType = QgsWkbTypes.MultiLineString
        options.forceMulti = True
    options.actionOnExistingFile = (QgsVectorFileWriter.CreateOrOverwriteLayer if gpkg.exists() else QgsVectorFileWriter.CreateOrOverwriteFile)
    result = QgsVectorFileWriter.writeAsVectorFormatV3(layer, str(gpkg), project.transformContext(), options)
    assert result[0] == QgsVectorFileWriter.NoError, result
    saved = QgsVectorLayer(str(gpkg) + '|layername=' + key, name, 'ogr')
    assert saved.isValid()
    project.addMapLayer(saved)
    return saved

def layer(key, name, query, geometry='geom'):
    sql = "BEGIN READ ONLY; SELECT json_build_object('type','FeatureCollection','features',coalesce(json_agg(json_build_object('type','Feature','geometry',ST_AsGeoJSON(q." + geometry + ")::json,'properties',to_jsonb(q)-'geom'-'geom_derivacion')), '[]'::json)) FROM (" + query.rstrip(';') + ") q; ROLLBACK;"
    raw = subprocess.check_output([str(ROOT / 'scripts/psql.sh'), '-qAtc', sql], cwd=ROOT, text=True)
    path = Path(scratch.name) / (key + '.geojson')
    path.write_text(raw)
    return persist(QgsVectorLayer(str(path), name, 'ogr'), key, name)

closed = layer('cerrados', 'Centros cerrados', queries[0])
routes = layer('derivaciones', 'Derivaciones directas', queries[0], 'geom_derivacion')
dest = layer('destinos', 'Destinos: centros a derivar', queries[1])
receivers = layer('receptores_elegidos', 'Destinos elegidos', 'SELECT * FROM (' + queries[1].rstrip(';') + ') q WHERE centros_a_derivar > 0')
dept = layer('departamento', 'Límite departamental', "SELECT geom FROM capas.departamentos WHERE nam='Concordia'")
river_sql = "SELECT r.geom FROM capas.rios r JOIN capas.departamentos d ON ST_Intersects(r.geom,d.geom) WHERE d.nam='Concordia' AND r.name='Río Uruguay'"
river = layer('rio_uruguay', 'Río Uruguay', river_sql)
band = layer('franja_2km', 'Franja de 2 km', 'SELECT ST_Union(ST_Buffer(geom::geography,2000)::geometry) AS geom FROM (' + river_sql + ') r')
assert [closed.featureCount(), routes.featureCount(), dest.featureCount(), receivers.featureCount()] == [6,6,7,3]
city = transform.transformBoundingBox(QgsRectangle(-58.052,-31.417,-57.989,-31.354))
a = QgsVectorLayer('Polygon?crs=EPSG:32721', 'Detalle de la Figura 3', 'memory')
f = QgsFeature(); f.setGeometry(QgsGeometry.fromRect(city)); a.dataProvider().addFeatures([f])
area = persist(a, 'detalle_figura3', 'Detalle de la Figura 3')

ids = {1:'1',52:'2',131:'3',50:'4',62:'5',43:'6'}
keys = {122:'A',59:'B',54:'C',45:'D',170:'E',91:'F',2:'G'}
for l, field, values in [(closed,'clave',ids),(dest,'clave',keys),(receivers,'clave',keys)]:
    l.startEditing(); l.addAttribute(QgsField(field,10)); l.updateFields()
    for feature in l.getFeatures(): l.changeAttributeValue(feature.id(),l.fields().indexFromName(field),values[feature['id']])
    assert l.commitChanges()
red = QgsMarkerSymbol.createSimple({'name':'circle','color':'194,49,48','outline_color':'white','outline_width':'0.3','size':'3.2'})
green = QgsMarkerSymbol.createSimple({'name':'diamond','color':'34,121,75','outline_color':'white','outline_width':'0.3','size':'3'})

def categories(l, symbol, field, keyfield=None, counts=False):
    cats=[]
    for feature in sorted(l.getFeatures(), key=lambda f:f['clave']):
        name = feature[field]
        label = feature['clave'] + ' · ' + name
        if counts: label += ' — ' + str(feature['centros_a_derivar'])
        cats.append(QgsRendererCategory(feature['id'],symbol.clone(),textwrap.fill(label,36)))
    l.setRenderer(QgsCategorizedSymbolRenderer('id',cats))

categories(closed,red,'centro_origen')
categories(receivers,green,'nombre')
categories(dest,green,'nombre',counts=True)
routes.renderer().setSymbol(QgsLineSymbol.createSimple({'line_color':'117,73,158','line_width':'0.55','line_style':'dash'}))
river.renderer().setSymbol(QgsLineSymbol.createSimple({'line_color':'36,113,170','line_width':'0.55'}))
band.renderer().setSymbol(QgsFillSymbol.createSimple({'color':'142,199,226,35','outline_color':'63,144,181,200','outline_width':'0.24','outline_style':'dash'}))
dept.renderer().setSymbol(QgsFillSymbol.createSimple({'color':'249,249,245,255','outline_color':'126,135,137','outline_width':'0.32'}))
area.renderer().setSymbol(QgsFillSymbol.createSimple({'color':'255,255,255,0','outline_color':'117,73,158','outline_width':'0.5'}))

def labeling(l):
    s=QgsPalLayerSettings();s.fieldName='clave';s.dist=1.5;s.placement=QgsPalLayerSettings.OrderedPositionsAroundPoint
    fmt=QgsTextFormat();fmt.setFont(QFont('Noto Sans',8));fmt.setSize(8);b=QgsTextBufferSettings();b.setEnabled(True);b.setSize(.65);b.setColor(QColor('white'));fmt.setBuffer(b);s.setFormat(fmt)
    l.setLabeling(QgsVectorLayerSimpleLabeling(s));l.setLabelsEnabled(True)
labeling(closed);labeling(receivers)
# Native SVG copied next to the project so the QGZ is portable across machines.
shutil.copyfile('/usr/share/qgis/svg/arrows/NorthArrow_07.svg', OUT / 'norte.svg')
layouts=[]
def make(name,title,height,layers,extent,mapwidth,mapheight,legendx,legendwidth,segment):
    layout=QgsPrintLayout(project);layout.initializeDefaults();layout.setName(name);layout.pageCollection().page(0).setPageSize(QgsLayoutSize(190,height));layout.renderContext().setDpi(360);project.layoutManager().addLayout(layout);layouts.append(layout)
    titleitem=QgsLayoutItemLabel(layout);titleitem.setText(title);titleitem.setFont(QFont('Noto Sans',10,QFont.Bold));layout.addLayoutItem(titleitem);titleitem.attemptMove(QgsLayoutPoint(3,1));titleitem.attemptResize(QgsLayoutSize(184,9))
    m=QgsLayoutItemMap(layout);layout.addLayoutItem(m);m.attemptMove(QgsLayoutPoint(3,12));m.attemptResize(QgsLayoutSize(mapwidth,mapheight));m.setCrs(crs);m.setLayers(layers);m.setKeepLayerSet(True);m.setFrameEnabled(True);m.zoomToExtent(extent)
    legend=QgsLayoutItemLegend(layout);legend.setTitle('Leyenda');legend.setLinkedMap(m);legend.setAutoUpdateModel(False);root=legend.model().rootGroup();root.removeAllChildren()
    for l in layers:root.addLayer(l)
    legend.setWrapString('\n');legend.setStyleFont(QgsLegendStyle.Title,QFont('Noto Sans',8,QFont.Bold));legend.setStyleFont(QgsLegendStyle.Group,QFont('Noto Sans',8));legend.setStyleFont(QgsLegendStyle.Subgroup,QFont('Noto Sans',7));legend.setStyleFont(QgsLegendStyle.SymbolLabel,QFont('Noto Sans',7));legend.setSymbolWidth(5);legend.setSymbolHeight(2.6);legend.setBoxSpace(1);legend.setColumnCount(1);layout.addLayoutItem(legend);legend.attemptMove(QgsLayoutPoint(legendx,12));legend.attemptResize(QgsLayoutSize(legendwidth,mapheight))
    north=QgsLayoutItemPicture(layout);north.setPicturePath(str(OUT/'norte.svg'));north.setSvgFillColor(QColor('black'));north.setSvgStrokeColor(QColor('black'));north.setLinkedMap(m);layout.addLayoutItem(north);north.attemptMove(QgsLayoutPoint(6,15));north.attemptResize(QgsLayoutSize(8,8))
    scale=QgsLayoutItemScaleBar(layout);scale.setStyle('Single Box');scale.setLinkedMap(m);scale.applyDefaultSize();scale.setUnits(QgsUnitTypes.DistanceKilometers);scale.setUnitsPerSegment(segment);scale.setNumberOfSegments(2);scale.setNumberOfSegmentsLeft(0);scale.setUnitLabel('km');scale.setFont(QFont('Noto Sans',7));scale.setHeight(1.3);layout.addLayoutItem(scale);scale.attemptMove(QgsLayoutPoint(6,12+mapheight-10));scale.attemptResize(QgsLayoutSize(30,7))
    return layout,m

rect=transform.transformBoundingBox(dept.extent());rect.scale(1.08)
l0,m0=make('Figura 2 - Departamento','Departamento de Concordia',69,[area,river,dept],rect,108,54,115,72,10)
l1,m1=make('Figura 3 - Consulta 1','Consulta 1 · Derivaciones sanitarias',126,[closed,receivers,routes,river,band],city,111,109,118,68,.5)
q2extent=transform.transformBoundingBox(QgsRectangle(-58.215,-31.445,-57.93,-31.125))
l2,m2=make('Figura 4 - Consulta 2','Consulta 2 · Centros a derivar por destino',155,[dest,river,dept],q2extent,108,139,115,72,5)
# Leader annotations identify nearby true destination points without displacement.
positions={122:(-57.989,-31.371),59:(-57.980,-31.350),54:(-57.969,-31.393),45:(-57.970,-31.415),170:(-58.187,-31.156),91:(-58.005,-31.310),2:(-58.094,-31.388)}
for f in dest.getFeatures():
    p=transform.transform(f.geometry().asPoint());z=transform.transform(QgsPointXY(*positions[f['id']]))
    p=m2.mapToItemCoords(QPointF(p.x(),p.y()));z=m2.mapToItemCoords(QPointF(z.x(),z.y()));a=QPointF(3+p.x(),12+p.y());b=QPointF(3+z.x(),12+z.y())
    line=QgsLayoutItemPolyline(QPolygonF([a,b]),l2);line.setSymbol(QgsLineSymbol.createSimple({'line_color':'34,121,75','line_width':'0.18'}));l2.addLayoutItem(line)
    label=QgsLayoutItemLabel(l2);label.setText(keys[f['id']]);label.setFont(QFont('Noto Sans',8,QFont.Bold));l2.addLayoutItem(label);label.attemptMove(QgsLayoutPoint(b.x(),b.y()-3));label.attemptResize(QgsLayoutSize(7,6))
# Source-free, credential-free project with relative paths to persistent data.
project.setTitle('Actividad 13 - Resultados y composiciones QGIS')
assert project.write()
outputs=[('actividad-13-departamento-concordia.png',l0),('actividad-13-consulta-1-derivaciones.png',l1),('actividad-13-consulta-2-destinos.png',l2)]
for filename,layout in outputs:
    settings=QgsLayoutExporter.ImageExportSettings();settings.dpi=360
    assert QgsLayoutExporter(layout).exportToImage(str(OUT/filename),settings)==QgsLayoutExporter.Success
    print(filename)
print('Standalone project:', project.fileName())
