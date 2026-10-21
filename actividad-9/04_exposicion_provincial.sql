-- ============================================================================
-- ACTIVIDAD 9 - GESTIÓN DEL RIESGO HÍDRICO
-- Sub-actividad 9.4: Departamentos con mayor exposición
--
-- Alcance: Provincial (Todos los departamentos de Entre Ríos)
-- Umbral de referencia: 30 % de superficie
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista de Exposición Provincial ante Riesgo Hídrico
-- ----------------------------------------------------------------------------
-- Para cada departamento de la provincia se calcula:
-- a) Superficie total en km².
-- b) Superficie ocupada por la zona de influencia (buffer 2 km) de ríos y lagunas.
-- c) Porcentaje de exposición respecto al total departamental.
-- d) Bandera indicando si supera el umbral de referencia del 30%.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act9_exposicion_provincial CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act9_exposicion_provincial AS
WITH 
departamentos_proyectados AS (
    SELECT 
        d.id,
        d.nam AS departamento,
        d.geom AS geom_4326,
        ST_Transform(d.geom, 5343) AS geom_5343,
        (ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0) AS area_total_km2
    FROM entrerios.departamentos d
),
buffer_por_departamento AS (
    -- Calculamos el buffer departamentalizado para optimizar con índices GiST
    SELECT 
        dp.id AS dep_id,
        ST_Union(ST_Buffer(ST_Transform(r.geom, 5343), 2000)) AS geom_buffer_rios
    FROM departamentos_proyectados dp
    JOIN entrerios.rios r ON ST_Intersects(r.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_lagunas_por_departamento AS (
    SELECT 
        dp.id AS dep_id,
        ST_Union(ST_Buffer(ST_Transform(l.geom, 5343), 2000)) AS geom_buffer_lagunas
    FROM departamentos_proyectados dp
    JOIN entrerios.lagunas l ON ST_Intersects(l.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_consolidado AS (
    SELECT 
        dp.id AS dep_id,
        dp.departamento,
        dp.area_total_km2,
        dp.geom_5343,
        dp.geom_4326,
        -- Unión de buffers de ríos y lagunas recortada al polígono del departamento
        ST_Intersection(
            dp.geom_5343,
            ST_Union(
                COALESCE(br.geom_buffer_rios, 'POLYGON EMPTY'::geometry),
                COALESCE(bl.geom_buffer_lagunas, 'POLYGON EMPTY'::geometry)
            )
        ) AS geom_riesgo_5343
    FROM departamentos_proyectados dp
    LEFT JOIN buffer_por_departamento br ON dp.id = br.dep_id
    LEFT JOIN buffer_lagunas_por_departamento bl ON dp.id = bl.dep_id
)
SELECT 
    bc.dep_id AS id,
    bc.departamento,
    ROUND(bc.area_total_km2::numeric, 2) AS area_total_km2,
    ROUND((ST_Area(bc.geom_riesgo_5343) / 1000000.0)::numeric, 2) AS area_riesgo_km2,
    ROUND(((ST_Area(bc.geom_riesgo_5343) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0)::numeric, 2) AS porcentaje_expuesto,
    CASE 
        WHEN ((ST_Area(bc.geom_riesgo_5343) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0) >= 30.0 THEN 'SI'
        ELSE 'NO'
    END AS supera_umbral_30,
    -- Comparación directa de nuestro departamento elegido
    CASE 
        WHEN bc.departamento ILIKE 'Concordia' THEN 'Departamento Seleccionado (Concordia)'
        ELSE 'Resto de la Provincia'
    END AS grupo_analisis,
    bc.geom_4326 AS geom
FROM buffer_consolidado bc
ORDER BY porcentaje_expuesto DESC;

COMMENT ON VIEW entrerios.vw_act9_exposicion_provincial IS
'Ranking provincial de exposición ante riesgo hídrico (buffer 2 km) con umbral de referencia del 30%.';

-- ----------------------------------------------------------------------------
-- 2. Consulta de Ranking Provincial
-- ----------------------------------------------------------------------------
SELECT 
    row_number() OVER (ORDER BY porcentaje_expuesto DESC) AS ranking,
    departamento,
    area_total_km2,
    area_riesgo_km2,
    porcentaje_expuesto,
    supera_umbral_30,
    grupo_analisis
FROM entrerios.vw_act9_exposicion_provincial;

-- ----------------------------------------------------------------------------
-- 3. Departamentos Críticos que Superan el 30%
-- ----------------------------------------------------------------------------
SELECT 
    departamento,
    area_total_km2,
    area_riesgo_km2,
    porcentaje_expuesto
FROM entrerios.vw_act9_exposicion_provincial
WHERE supera_umbral_30 = 'SI'
ORDER BY porcentaje_expuesto DESC;
