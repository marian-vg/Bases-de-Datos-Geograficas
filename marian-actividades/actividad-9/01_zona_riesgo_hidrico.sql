-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.1. Definición de una zona de riesgo (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Se proyecta a POSGAR 07 Argentina 5 para realizar cálculos métricos planos sin la distorsión angular de EPSG:4326.
-- Justificación Funciones: ST_Buffer genera el radio de 2.000 m; ST_Union disuelve solapamientos y ST_Intersection acota al límite de Concordia.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista espacial para visualizar el área de riesgo en QGIS y consultar métricas
CREATE OR REPLACE VIEW entrerios.vw_act9_zona_riesgo_concordia AS
WITH 
concordia AS (
    SELECT ST_Transform(geom, 5343) AS geom_5343
    FROM entrerios.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
red_hidrica AS (
    SELECT ST_Transform(r.geom, 5343) AS geom_5343 FROM entrerios.rios r, concordia c WHERE ST_Intersects(r.geom, ST_Transform(c.geom_5343, 4326))
    UNION ALL
    SELECT ST_Transform(l.geom, 5343) AS geom_5343 FROM entrerios.lagunas l, concordia c WHERE ST_Intersects(l.geom, ST_Transform(c.geom_5343, 4326))
),
buffer_disuelto AS (
    SELECT ST_Union(ST_Buffer(geom_5343, 2000)) AS geom_buffer_5343 FROM red_hidrica
),
zona_recortada AS (
    SELECT ST_Intersection(b.geom_buffer_5343, c.geom_5343) AS geom_5343
    FROM buffer_disuelto b, concordia c
)
SELECT 
    1 AS id,
    'Concordia'::text AS departamento,
    ROUND((ST_Area(geom_5343) / 1000000.0)::numeric, 2) AS superficie_riesgo_km2,
    ST_Transform(geom_5343, 4326) AS geom
FROM zona_recortada;

-- Consulta de balance de superficie
SELECT 
    d.nam AS departamento,
    ROUND((ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0)::numeric, 2) AS superficie_total_km2,
    z.superficie_riesgo_km2,
    ROUND((z.superficie_riesgo_km2 / (ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0) * 100.0)::numeric, 2) AS porcentaje_en_riesgo
FROM entrerios.departamentos d, entrerios.vw_act9_zona_riesgo_concordia z
WHERE d.nam ILIKE 'Concordia';

-- Interpretación: Representa la superficie de Concordia ubicada a menos de 2 km de cursos de agua, base para evaluar la exposición territorial.
