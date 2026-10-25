#!/usr/bin/env python3
"""Desde la raíz: python de QGIS -X utf8 figuras/actividad-08/renderizar-actividad-08.py.
Requiere Docker y la base cargada. No modifica las tablas.
"""
import os
import re
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mapas
from qgis.core import (QgsCategorizedSymbolRenderer, QgsLineSymbol,
                       QgsReferencedRectangle, QgsRendererCategory)
from qgis.PyQt.QtGui import QFont, QFontDatabase

if os.name == 'nt':
    for nombre in ['arial.ttf', 'arialbd.ttf', 'ariali.ttf', 'arialbi.ttf']:
        QFontDatabase.addApplicationFont(str(Path(os.environ['WINDIR']) / 'Fonts' / nombre))
    mapas.FUENTE = 'Arial'
    QFont.insertSubstitution('Noto Sans', 'Arial')

# En Windows no se puede ejecutar el shebang de psql.sh. Se usa su mismo comando
# Docker solo en este renderizador, sin cambiar el helper compartido.
if os.name == 'nt':
    def psql(args, **kwargs):
        return subprocess.check_output(
            [os.environ.get('DOCKER_EXE', 'docker'), 'compose', 'exec', '-T', 'postgres', 'psql', '-X', '-v',
             'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'bdg_entrerios', *args[1:]],
            encoding='utf-8', **kwargs)
    mapas.subprocess = SimpleNamespace(check_output=psql)

OUT = Path(__file__).resolve().parent
GPKG = OUT / 'actividad-08-resultados.gpkg'
sql = (mapas.ROOT / 'actividades-sql/actividad-08.sql').read_text(encoding='utf-8')
consultas = [q.strip() for q in re.sub(r'(?m)^--.*$', '', sql).split(';') if q.strip()]
assert len(consultas) == 7
GPKG.unlink(missing_ok=True)
project = mapas.proyecto(OUT / 'actividad-08-composiciones.qgz')

departamento = mapas.capa(GPKG, 'concordia', 'Departamento Concordia',
                         "SELECT geom FROM entrerios.departamentos WHERE nam = 'Concordia'")
rutas = mapas.capa(GPKG, 'rutas', 'Rutas identificadas', consultas[2])
centros = mapas.capa(GPKG, 'centros', 'Hospitales y clínicas OSM',
                    'SELECT id, nombre, categoria, ST_PointOnSurface(geom) AS geom FROM ('
                    + consultas[3] + ') q')
buffers = mapas.capa(GPKG, 'buffers', 'Influencia de 5 km', consultas[5])
localidades = mapas.capa(GPKG, 'localidades', 'Localidades', consultas[6])
areas = mapas.capa(GPKG, 'areas_inta', 'Áreas urbanas INTA', """
    SELECT s.nombre, ST_Intersection(s.geom, d.geom) AS geom
    FROM entrerios.suelo s JOIN entrerios.departamentos d ON ST_Intersects(s.geom, d.geom)
    WHERE d.nam = 'Concordia' AND s.simb = 'AU'""")

mapas.relleno(departamento, '248,246,237', '70,70,70')
mapas.relleno(areas, '218,218,210', '150,150,140', '0.15')
mapas.relleno(buffers, '120,175,215,65', '40,105,155', '0.25')
mapas.punto(centros, '30,70,130', forma='cross_fill', tam='3')
mapas.categorias(localidades, 'cobertura', {
    'Cubierta': ('35,125,90', 'Cubierta (hasta 5 km)'),
    'Fuera de cobertura': ('185,65,35', 'Fuera de cobertura')})
mapas.etiquetas(localidades, '"localidad"', tam=6)
colores = ['#24577a', '#8f4924', '#79519b', '#39836a', '#c34b42', '#9a7a15', '#505050']
categorias = []
for ruta, color in zip(sorted(f['ruta'] for f in rutas.getFeatures()), colores):
    simbolo = QgsLineSymbol.createSimple({'line_color': color, 'line_width': '0.55'})
    categorias.append(QgsRendererCategory(ruta, simbolo, ruta))
rutas.setRenderer(QgsCategorizedSymbolRenderer('ruta', categorias))
mapas.etiquetas(rutas, '"ruta"', tam=7)

mapas.exportar(OUT / 'actividad-08-rutas.png', '8.1–8.2. Rutas de Concordia',
               [rutas, areas, departamento], mapas.extension(departamento), alto=155)
mapas.tabla(OUT / 'actividad-08-longitudes.png', '8.2. Longitud de red registrada por ruta',
            ['Ruta', 'Longitud (km)'], mapas.consulta(
                'SELECT ruta, longitud_km FROM (' + consultas[2] + ') q ORDER BY ruta'))
mapas.exportar(OUT / 'actividad-08-cobertura.png', '8.3–8.5. Cobertura sanitaria potencial',
               [localidades, centros, buffers, departamento],
               mapas.extension(departamento), alto=165)
project.layerTreeRoot().setHasCustomLayerOrder(True)
project.layerTreeRoot().setCustomLayerOrder([localidades, centros, rutas, buffers, areas, departamento])
project.viewSettings().setDefaultViewExtent(
    QgsReferencedRectangle(mapas.extension(departamento), mapas.CRS))
mapas.cerrar(project, GPKG)
print('Localidad más alejada:', mapas.consulta(
    'SELECT localidad, distancia_km FROM (' + consultas[4] + ') q'))
print('Fuera de cobertura:', mapas.consulta(
    'SELECT DISTINCT total_fuera_de_cobertura FROM (' + consultas[6] + ') q'))
project.clear()
mapas.app.exitQgis()
