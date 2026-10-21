-- ============================================================================
-- ACTIVIDAD 9 - GESTIÓN DEL RIESGO HÍDRICO
-- Sub-actividad 9.2: Infraestructura sanitaria expuesta
--
-- Departamento seleccionado: Concordia
-- Sistema de Coordenadas Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista de Establecimientos de Salud Expuestos en Concordia
-- ----------------------------------------------------------------------------
-- Filtra los centros de salud de Concordia que caen dentro del buffer
-- de riesgo hídrico de 2 km y calcula la distancia métrica real al agua.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act9_salud_riesgo_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act9_salud_riesgo_concordia AS
WITH 
dep_concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
salud_concordia AS (
    SELECT 
        s.id,
        COALESCE(s.name, 'Establecimiento sin nombre') AS nombre,
        s.amenity,
        s.healthcare,
        s.operator,
        s.geom AS geom_4326,
        ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s
    JOIN dep_concordia d ON ST_Intersects(s.geom, d.geom)
),
cursos_agua_concordia AS (
    -- Consolidamos ríos y lagunas para el cálculo de distancia exacta
    SELECT ST_Transform(r.geom, 5343) AS geom_5343 
    FROM entrerios.rios r
    JOIN dep_concordia d ON ST_Intersects(r.geom, d.geom)
    UNION ALL
    SELECT ST_Transform(l.geom, 5343) AS geom_5343 
    FROM entrerios.lagunas l
    JOIN dep_concordia d ON ST_Intersects(l.geom, d.geom)
),
agua_unificada AS (
    SELECT ST_Union(geom_5343) AS geom_agua_5343 FROM cursos_agua_concordia
)
SELECT 
    sc.id,
    sc.nombre,
    sc.amenity,
    sc.healthcare,
    sc.operator,
    -- Distancia exacta en metros al agua más cercana
    ROUND((ST_Distance(sc.geom_5343, a.geom_agua_5343))::numeric, 2) AS distancia_agua_metros,
    'DENTRO DE ZONA DE RIESGO (< 2 km)'::text AS condicion_riesgo,
    sc.geom_4326 AS geom
FROM salud_concordia sc
CROSS JOIN agua_unificada a
JOIN entrerios.vw_act9_zona_riesgo_concordia zr 
  ON ST_Intersects(sc.geom_5343, zr.geom_5343)
ORDER BY distancia_agua_metros ASC;

COMMENT ON VIEW entrerios.vw_act9_salud_riesgo_concordia IS
'Establecimientos sanitarios del Departamento Concordia ubicados dentro de la zona de riesgo hídrico (< 2000 m del agua).';

-- ----------------------------------------------------------------------------
-- 2. Consulta de Diagnóstico y Resumen
-- ----------------------------------------------------------------------------
-- Muestra el balance entre centros protegidos vs. centros expuestos en Concordia.
-- ----------------------------------------------------------------------------
SELECT 
    COUNT(s.id) AS total_centros_salud_concordia,
    COUNT(exp.id) AS centros_en_riesgo,
    COUNT(s.id) - COUNT(exp.id) AS centros_fuera_de_riesgo,
    ROUND((COUNT(exp.id)::numeric / NULLIF(COUNT(s.id), 0) * 100.0), 2) AS porcentaje_expuesto
FROM entrerios.salud s
JOIN entrerios.departamentos d ON ST_Intersects(s.geom, d.geom)
LEFT JOIN entrerios.vw_act9_salud_riesgo_concordia exp ON s.id = exp.id
WHERE d.nam ILIKE 'Concordia';
