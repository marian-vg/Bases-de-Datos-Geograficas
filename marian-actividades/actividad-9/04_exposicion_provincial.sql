-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.4. Departamentos con mayor exposición (Alcance Provincial - Umbral 30%)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Uniformiza el cálculo de áreas geográficas en km² para los 17 departamentos sin distorsión meridiana.
-- Justificación Funciones: ST_Buffer genera el área de influencia de 2.000 m y ST_Intersection cuantifica la superposición con cada departamento.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista del ranking provincial de exposición hídrica
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
    SELECT dp.id AS dep_id, ST_Union(ST_Buffer(ST_Transform(r.geom, 5343), 2000)) AS geom_buffer_rios
    FROM departamentos_proyectados dp
    JOIN entrerios.rios r ON ST_Intersects(r.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_lagunas_por_departamento AS (
    SELECT dp.id AS dep_id, ST_Union(ST_Buffer(ST_Transform(l.geom, 5343), 2000)) AS geom_buffer_lagunas
    FROM departamentos_proyectados dp
    JOIN entrerios.lagunas l ON ST_Intersects(l.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_consolidado AS (
    SELECT 
        dp.id AS dep_id,
        dp.departamento,
        dp.area_total_km2,
        dp.geom_4326,
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
    ROUND((ST_Area(bc.geom_riesgo_5343) / 1000000.0)::numeric, 2) AS area_en_riesgo_km2,
    ROUND(((ST_Area(bc.geom_riesgo_5343) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0)::numeric, 2) AS porcentaje_expuesto,
    CASE 
        WHEN ((ST_Area(bc.geom_riesgo_5343) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0) >= 30.0 THEN 'Sí'
        ELSE 'No'
    END AS supera_umbral_30_pct,
    CASE WHEN bc.departamento ILIKE 'Concordia' THEN 'Departamento en estudio' ELSE 'Provincial' END AS categoria_estudio,
    bc.geom_4326 AS geom
FROM buffer_consolidado bc
ORDER BY porcentaje_expuesto DESC;

-- Consulta de departamentos críticos que superan el umbral del 30%
SELECT 
    row_number() OVER (ORDER BY porcentaje_expuesto DESC) AS ranking,
    departamento,
    area_total_km2,
    area_en_riesgo_km2,
    porcentaje_expuesto,
    supera_umbral_30_pct,
    categoria_estudio
FROM entrerios.vw_act9_exposicion_provincial;

-- Interpretación: Demuestra la vulnerabilidad relativa de cada departamento; los fluviales y deltaicos superan holgadamente el 30% de exposición.
