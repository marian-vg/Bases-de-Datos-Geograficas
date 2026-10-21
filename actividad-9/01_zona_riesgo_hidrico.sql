-- ============================================================================
-- ACTIVIDAD 9 - GESTIÓN DEL RIESGO HÍDRICO
-- Sub-actividad 9.1: Definición de una zona de riesgo hídrico
--
-- Departamento seleccionado: Concordia
-- Sistema de Coordenadas Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

-- Aseguramos el esquema de trabajo
SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista de la Zona de Riesgo Hídrico en Concordia (Buffer 2 km)
-- ----------------------------------------------------------------------------
-- Se genera una zona de influencia de 2.000 metros alrededor de los cursos
-- (ríos/arroyos) y cuerpos de agua (lagunas) que intersectan el departamento.
-- El resultado se unifica para evitar polígonos duplicados y se recorta
-- contra la frontera de Concordia.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act9_zona_riesgo_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act9_zona_riesgo_concordia AS
WITH 
dep_concordia AS (
    SELECT 
        id,
        nam AS nombre_departamento,
        geom AS geom_4326,
        ST_Transform(geom, 5343) AS geom_5343
    FROM entrerios.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
rios_concordia AS (
    SELECT 
        ST_Transform(r.geom, 5343) AS geom_5343
    FROM entrerios.rios r
    JOIN dep_concordia d ON ST_Intersects(r.geom, d.geom_4326)
),
lagunas_concordia AS (
    SELECT 
        ST_Transform(l.geom, 5343) AS geom_5343
    FROM entrerios.lagunas l
    JOIN dep_concordia d ON ST_Intersects(l.geom, d.geom_4326)
),
todos_cursos_agua AS (
    SELECT geom_5343 FROM rios_concordia
    UNION ALL
    SELECT geom_5343 FROM lagunas_concordia
),
buffer_agua AS (
    SELECT 
        ST_Union(ST_Buffer(geom_5343, 2000)) AS geom_buffer_5343
    FROM todos_cursos_agua
),
zona_riesgo_recortada AS (
    SELECT 
        d.nombre_departamento,
        -- Intersección con el límite de Concordia para ceñir el riesgo al departamento
        ST_Intersection(b.geom_buffer_5343, d.geom_5343) AS geom_5343
    FROM buffer_agua b
    CROSS JOIN dep_concordia d
)
SELECT 
    row_number() OVER () AS id,
    nombre_departamento,
    -- Geometría proyectada en EPSG:5343 para cálculos métricos
    geom_5343,
    -- Geometría en EPSG:4326 lista para visualizar en QGIS con mapas base estándar
    ST_Transform(geom_5343, 4326) AS geom,
    ROUND((ST_Area(geom_5343) / 1000000.0)::numeric, 2) AS superficie_riesgo_km2
FROM zona_riesgo_recortada;

COMMENT ON VIEW entrerios.vw_act9_zona_riesgo_concordia IS 
'Zona de influencia de 2 km alrededor de ríos, arroyos y lagunas dentro del Departamento Concordia (EPSG:5343 y EPSG:4326).';

-- ----------------------------------------------------------------------------
-- 2. Consulta de Balance Superficial de Concordia
-- ----------------------------------------------------------------------------
-- Compara la superficie total del departamento vs. la superficie bajo riesgo.
-- ----------------------------------------------------------------------------
SELECT 
    d.nam AS departamento,
    ROUND((ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0)::numeric, 2) AS superficie_total_km2,
    z.superficie_riesgo_km2,
    ROUND((z.superficie_riesgo_km2 / (ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0) * 100.0)::numeric, 2) AS porcentaje_en_riesgo
FROM entrerios.departamentos d
CROSS JOIN entrerios.vw_act9_zona_riesgo_concordia z
WHERE d.nam ILIKE 'Concordia';
