#!/usr/bin/env python3
"""Activity 7 figures: query 7.1 result and the Concordia / San Salvador border map.
Run from the repo root with the database loaded:
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/actividad-07/renderizar-actividad-07.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mapas

OUT = Path(__file__).resolve().parent
GPKG = OUT / 'actividad-07-resultados.gpkg'
GPKG.unlink(missing_ok=True)
project = mapas.proyecto(OUT / 'actividad-07-composiciones.qgz')

# 7.1: neighbours that share a line with Concordia (same query as the script).
filas = mapas.consulta("""
    SELECT vecino.id, vecino.nam, ST_GeometryType(vecino.geom)
    FROM entrerios.departamentos AS elegido
    JOIN entrerios.departamentos AS vecino
      ON elegido.id <> vecino.id AND ST_Touches(elegido.geom, vecino.geom)
    WHERE elegido.nam = 'Concordia'
      AND ST_Dimension(ST_Intersection(elegido.geom, vecino.geom)) = 1""")
mapas.tabla(OUT / 'actividad-07-consulta-7-1.png', 'Resultado de la consulta 7.1',
            ['id', 'nombre', 'geometria'], filas)

# 7.2 and 7.5: department, neighbour, shared border and clipped rivers and streams.
concordia = mapas.capa(GPKG, 'concordia', 'Concordia',
                       "SELECT geom FROM entrerios.departamentos WHERE nam = 'Concordia'")
san_salvador = mapas.capa(GPKG, 'san_salvador', 'San Salvador',
                          "SELECT geom FROM entrerios.departamentos WHERE nam = 'San Salvador'")
frontera = mapas.capa(GPKG, 'frontera', 'Frontera compartida', """
    SELECT ST_CollectionExtract(ST_Intersection(c.geom, s.geom), 2) AS geom
    FROM entrerios.departamentos c, entrerios.departamentos s
    WHERE c.nam = 'Concordia' AND s.nam = 'San Salvador'""")
rios = mapas.capa(GPKG, 'rios_arroyos', 'Ríos y arroyos', """
    SELECT ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
    FROM entrerios.rios r JOIN entrerios.departamentos d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia' AND r.waterway IN ('river', 'stream')""")

mapas.relleno(concordia, '244,240,228,255', '70,70,70', '0.35')
mapas.relleno(san_salvador, '226,234,241,255', '70,70,70', '0.35')
mapas.linea(rios, '54,125,178', '0.18')
mapas.linea(frontera, '150,52,150', '0.9')

rect = mapas.extension(concordia).buffered(0)
rect.combineExtentWith(mapas.extension(san_salvador, 1.02))
mapas.exportar(OUT / 'actividad-07-frontera-hidrografia.png', 'Concordia: hidrografía y frontera con San Salvador',
               [frontera, rios, concordia, san_salvador], rect, alto=140, segmento=10, escala_x=76)
mapas.cerrar(project, GPKG)
