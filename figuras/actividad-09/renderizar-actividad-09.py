#!/usr/bin/env python3
"""Activity 9 figures, one per sub-item (9.1 to 9.4).
Reads the views created by actividades-sql/actividad-09.sql, so run that script first.
Run from the repo root (takes several minutes, like the activity itself):
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/actividad-09/renderizar-actividad-09.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import mapas

OUT = Path(__file__).resolve().parent
GPKG = OUT / 'actividad-09-resultados.gpkg'
GPKG.unlink(missing_ok=True)
project = mapas.proyecto(OUT / 'actividad-09-composiciones.qgz')

concordia = mapas.capa(GPKG, 'concordia', 'Concordia',
                       "SELECT id, nam AS nombre, geom FROM entrerios.departamentos WHERE nam = 'Concordia'")
zona = mapas.capa(GPKG, 'zona_riesgo', 'Zona de Riesgo Hídrico (2 km)',
                  'SELECT departamento, superficie_riesgo_km2, geom FROM entrerios.vw_act9_zona_riesgo_concordia')
salud = mapas.capa(GPKG, 'salud_expuesta', 'Establecimientos expuestos', """
    SELECT id, nombre, tipo_establecimiento, distancia_agua_metros, geom
    FROM entrerios.vw_act9_salud_riesgo_concordia""")
rutas = mapas.capa(GPKG, 'rutas_principales', 'Rutas principales', """
    SELECT r.ref, r.highway, ST_Intersection(r.geom, d.geom) AS geom
    FROM entrerios.rutas r JOIN entrerios.departamentos d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia' AND r.highway IN ('motorway', 'trunk', 'primary', 'secondary')""")
cortes = mapas.capa(GPKG, 'rutas_afectadas', 'Tramos de ruta en la zona', """
    SELECT identificador_ruta, jerarquia_vial, longitud_total_m, longitud_afectada_m, porcentaje_afectado, geom
    FROM entrerios.vw_act9_rutas_afectadas_concordia""")
localidades = mapas.capa(GPKG, 'localidades_aislamiento', 'Nivel de aislamiento', """
    SELECT localidad, casco_urbano_en_riesgo, distancia_ruta_principal_m, distancia_corte_mas_cercano_m,
           nivel_aislamiento, geom
    FROM entrerios.vw_act9_localidades_aislamiento_concordia""")
provincia = mapas.capa(GPKG, 'exposicion_provincial', 'Superficie expuesta', """
    SELECT departamento, area_total_km2, area_en_riesgo_km2, porcentaje_expuesto, supera_umbral_30_pct,
           CASE WHEN porcentaje_expuesto >= 80 THEN '80 % o más'
                WHEN porcentaje_expuesto >= 60 THEN '60 % a 80 %'
                ELSE '30 % a 60 %' END AS clase,
           geom
    FROM entrerios.vw_act9_exposicion_provincial""")

mapas.relleno(concordia, '249,249,245,255', '126,135,137', '0.35')
mapas.relleno(zona, '142,199,226,150', '63,144,181', '0.2')
mapas.punto(salud, '194,49,48')
mapas.linea(rutas, '150,150,150', '0.45')
mapas.linea(cortes, '194,49,48', '0.6')
mapas.categorias(localidades, 'nivel_aislamiento', {
    'Crítico (En riesgo y corte próximo)': ('194,49,48', 'Crítico'),
    'Vulnerable (Vía de acceso amenazada)': ('230,126,34', 'Vulnerable'),
    'Bajo (Sin corte próximo según este criterio)': ('34,121,75', 'Bajo'),
})
mapas.etiquetas(localidades, '"localidad"')
mapas.categorias(provincia, 'clase', {
    '80 % o más': ('8,81,156,255', '80 % o más'),
    '60 % a 80 %': ('66,146,198,255', '60 % a 80 %'),
    '30 % a 60 %': ('158,202,225,255', '30 % a 60 %'),
})
mapas.etiquetas(provincia, "\"departamento\" || '\\n' || format_number(\"porcentaje_expuesto\", 1) || ' %'", 6)

depto = mapas.extension(concordia)
mapas.exportar(OUT / 'actividad-09-1-zona-riesgo.png', '9.1 · Zona de Riesgo Hídrico de Concordia',
               [zona, concordia], depto, alto=140)
ciudad = mapas.extension(salud, 1.6)
mapas.exportar(OUT / 'actividad-09-2-salud-expuesta.png', '9.2 · Establecimientos de salud en la zona de riesgo',
               [salud, zona, concordia], ciudad, alto=130, segmento=5)
mapas.exportar(OUT / 'actividad-09-3-aislamiento.png', '9.3 · Rutas afectadas y nivel de aislamiento',
               [localidades, cortes, rutas, zona, concordia], depto, alto=140)
mapas.exportar(OUT / 'actividad-09-4-exposicion-provincial.png', '9.4 · Superficie departamental en zona de riesgo',
               [provincia], mapas.extension(provincia, 1.03), alto=150, segmento=50)
mapas.cerrar(project, GPKG)
