-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.3. Posibles situaciones de aislamiento (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Asegura mediciones ortogonales en metros para longitudes de trazas cortadas y radios de proximidad.
-- Justificación Funciones: ST_Intersection extrae los segmentos viales anegables y ST_Distance / ST_DWithin miden la separación al punto de corte.
-- ============================================================================

SET search_path TO entrerios, public;

-- 1. Vista de tramos viales principales comprometidos por inundación
CREATE OR REPLACE VIEW entrerios.vw_act9_rutas_afectadas_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
rutas_principales AS (
    SELECT 
        r.id,
        COALESCE(r.ref, r.name, 'Ruta sin denominación') AS identificador_ruta,
        r.highway AS jerarquia_vial,
        ST_Transform(r.geom, 5343) AS geom_5343
    FROM entrerios.rutas r, concordia c
    WHERE ST_Intersects(r.geom, c.geom)
      AND r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
),
zona_riesgo AS (
    SELECT geom_5343 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
)
SELECT 
    rp.id AS ruta_id,
    rp.identificador_ruta,
    rp.jerarquia_vial,
    ROUND((ST_Length(rp.geom_5343))::numeric, 2) AS longitud_total_m,
    ROUND((ST_Length(ST_Intersection(rp.geom_5343, zr.geom_5343)))::numeric, 2) AS longitud_afectada_m,
    ROUND((ST_Length(ST_Intersection(rp.geom_5343, zr.geom_5343)) / NULLIF(ST_Length(rp.geom_5343), 0) * 100.0)::numeric, 2) AS porcentaje_afectado,
    ST_Transform(ST_Intersection(rp.geom_5343, zr.geom_5343), 4326) AS geom
FROM rutas_principales rp
CROSS JOIN zona_riesgo zr
WHERE ST_Intersects(rp.geom_5343, zr.geom_5343);

-- 2. Vista de diagnóstico de aislamiento para localidades
CREATE OR REPLACE VIEW entrerios.vw_act9_localidades_aislamiento_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
localidades_concordia AS (
    SELECT loc.id, loc.name AS localidad, ST_Transform(loc.geom, 5343) AS geom_5343, loc.geom AS geom_4326
    FROM entrerios.localidades loc, concordia c
    WHERE ST_Intersects(loc.geom, c.geom)
),
cortes_viales AS (
    SELECT ST_Union(ST_Transform(geom, 5343)) AS geom_cortes_5343 FROM entrerios.vw_act9_rutas_afectadas_concordia
),
zona_riesgo AS (
    SELECT geom_5343 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
),
red_vial AS (
    SELECT ST_Union(ST_Transform(r.geom, 5343)) AS geom_red_5343
    FROM entrerios.rutas r, concordia c
    WHERE ST_Intersects(r.geom, c.geom) AND r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
)
SELECT 
    lc.id,
    lc.localidad,
    CASE WHEN ST_Intersects(lc.geom_5343, zr.geom_5343) THEN 'Sí' ELSE 'No' END AS casco_urbano_en_riesgo,
    ROUND((ST_Distance(lc.geom_5343, rv.geom_red_5343))::numeric, 2) AS distancia_ruta_principal_m,
    ROUND((ST_Distance(lc.geom_5343, cv.geom_cortes_5343))::numeric, 2) AS distancia_corte_mas_cercano_m,
    CASE 
        WHEN ST_Intersects(lc.geom_5343, zr.geom_5343) AND ST_DWithin(lc.geom_5343, cv.geom_cortes_5343, 3000) THEN 'Crítico (En riesgo y corte próximo)'
        WHEN ST_DWithin(lc.geom_5343, cv.geom_cortes_5343, 2000) THEN 'Vulnerable (Vía de acceso amenazada)'
        ELSE 'Bajo (Conectividad vial asegurada)'
    END AS nivel_aislamiento,
    lc.geom_4326 AS geom
FROM localidades_concordia lc
CROSS JOIN zona_riesgo zr
CROSS JOIN cortes_viales cv
CROSS JOIN red_vial rv
ORDER BY distancia_corte_mas_cercano_m ASC;

-- Consulta de reporte para el informe
SELECT localidad, casco_urbano_en_riesgo, distancia_ruta_principal_m, distancia_corte_mas_cercano_m, nivel_aislamiento
FROM entrerios.vw_act9_localidades_aislamiento_concordia;

-- Interpretación: Detecta poblados cuyo único acceso vial formal queda interceptado por el avance de las aguas frente a crecidas.
