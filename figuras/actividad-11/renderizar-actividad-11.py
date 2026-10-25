#!/usr/bin/env python3
"""Desde la raíz: python de QGIS -X utf8 figuras/actividad-11/renderizar-actividad-11.py.
Requiere Docker, calles provinciales cargadas e Internet para Argenmap.
"""
import os
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mapas
from qgis.core import (QgsCoordinateReferenceSystem, QgsCoordinateTransform,
                       QgsRasterLayer, QgsRectangle, QgsReferencedRectangle)
from qgis.PyQt.QtGui import QFont, QFontDatabase

if os.name == 'nt':
    for nombre in ['arial.ttf', 'arialbd.ttf', 'ariali.ttf', 'arialbi.ttf']:
        QFontDatabase.addApplicationFont(str(Path(os.environ['WINDIR']) / 'Fonts' / nombre))
    mapas.FUENTE = 'Arial'
    QFont.insertSubstitution('Noto Sans', 'Arial')

# Equivalente Windows de psql.sh, sin modificar el helper compartido.
if os.name == 'nt':
    def psql(args, **kwargs):
        return subprocess.check_output(
            [os.environ.get('DOCKER_EXE', 'docker'), 'compose', 'exec', '-T', 'postgres', 'psql', '-X', '-v',
             'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'bdg_entrerios', *args[1:]],
            encoding='utf-8', **kwargs)
    mapas.subprocess = SimpleNamespace(check_output=psql)

OUT = Path(__file__).resolve().parent
GPKG = OUT / 'actividad-11-resultados.gpkg'
sql = (mapas.ROOT / 'actividades-sql/actividad-11.sql').read_text(encoding='utf-8')
consultas = [q.strip() for q in re.sub(r'(?m)^--.*$', '', sql).split(';') if q.strip()]
assert len(consultas) == 5
GPKG.unlink(missing_ok=True)
project = mapas.proyecto(OUT / 'actividad-11-composiciones.qgz')
calles = mapas.capa(GPKG, 'calles', 'Calles OSM de la base', consultas[4])
areas = mapas.capa(GPKG, 'areas_evaluadas', 'Áreas INTA evaluadas',
                  'SELECT * FROM (' + consultas[1] + ") q WHERE estado = 'Evaluada'")
localidades = mapas.capa(GPKG, 'localidades', 'Localidades OSM', """
    SELECT l.id, l.name, l.geom FROM entrerios.localidades l
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, l.geom)
    WHERE d.nam = 'Concordia'""")
puentes = mapas.capa(GPKG, 'puentes', 'Tramos con bridge = yes',
                    'SELECT * FROM (' + consultas[4] + ") q WHERE bridge = 'yes'")
mapas.linea(calles, '200,45,100', '0.35')
mapas.linea(puentes, '35,65,180', '1.0')
mapas.relleno(areas, '235,180,60,30', '150,100,35', '0.25')
mapas.punto(localidades, '40,40,40', tam='1.8')
mapas.etiquetas(localidades, '"name"', tam=7)

# Servicio publicado por IGN. {-y} invierte la fila del esquema TMS.
# https://www.ign.gob.ar/NuestrasActividades/InformacionGeoespacial/ServiciosOGC
url = ('https://wms.ign.gob.ar/geoserver/gwc/service/tms/1.0.0/'
       'capabaseargenmap@EPSG:3857@png/{z}/{x}/{-y}.png')
argenmap = QgsRasterLayer('type=xyz&url=' + url + '&zmin=3&zmax=18',
                         'Argenmap — IGN + OpenStreetMap', 'wms')
assert argenmap.isValid(), 'No se pudo crear la capa Argenmap'
project.addMapLayer(argenmap)

crs = mapas.CRS
transformacion = QgsCoordinateTransform(QgsCoordinateReferenceSystem('EPSG:4326'), crs, project)
# Tres sectores fijos, para que las imágenes sean comparables entre ejecuciones.
sectores = [
    ('urbano', '11.4. Centro urbano de Concordia', (-58.043, -31.408, -58.008, -31.381), 0.5),
    ('rural', '11.4. Sector rural: entorno de Pedernal', (-58.276, -31.698, -58.190, -31.635), 1),
    ('puente', '11.4. Cruce hídrico: Puente Alvear', (-58.057, -31.396, -58.042, -31.384), 0.2),
]
for nombre, titulo, limites, segmento in sectores:
    rect = transformacion.transformBoundingBox(QgsRectangle(*limites))
    mapas.exportar(OUT / f'actividad-11-argenmap-{nombre}.png', titulo,
                   [puentes, calles, localidades, argenmap], rect,
                   alto=150, segmento=segmento, crs=crs)

project.layerTreeRoot().setHasCustomLayerOrder(True)
project.layerTreeRoot().setCustomLayerOrder([puentes, calles, localidades, areas, argenmap])
project.viewSettings().setDefaultViewExtent(QgsReferencedRectangle(mapas.extension(calles), crs))
mapas.cerrar(project, GPKG)
print('Densidad INTA:', mapas.consulta(
    'SELECT localidad, superficie_km2, longitud_km, densidad_km_por_km2, estado FROM ('
    + consultas[1] + ') q'))
print('Comparación departamental:', mapas.consulta(
    'SELECT longitud_km, promedio_departamental_km, departamentos_comparados FROM ('
    + consultas[0] + ') q WHERE elegido'))
print('Categorías:', mapas.consulta(consultas[2]))
print('Faltantes:', mapas.consulta(consultas[3]))
project.clear()
mapas.app.exitQgis()
