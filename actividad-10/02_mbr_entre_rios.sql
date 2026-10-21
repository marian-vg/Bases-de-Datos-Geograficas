-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.2. MBR (Minimum Bounding Rectangle) de Entre Ríos (ST_Envelope)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Permite calcular superficies comparables en km² proyectadas al plano sin deformaciones angulares.
-- Justificación Funciones: ST_Envelope genera el rectángulo mínimo delimitador y ST_Union disuelve las divisiones departamentales.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista para contrastar cartográficamente el contorno real vs el MBR en QGIS
CREATE OR REPLACE VIEW entrerios.vw_act10_mbr_entre_rios AS
WITH 
provincia AS (
    SELECT ST_Union(ST_Transform(geom, 5343)) AS geom_provincia_5343
    FROM entrerios.departamentos
),
geometrias AS (
    SELECT geom_provincia_5343, ST_Envelope(geom_provincia_5343) AS geom_mbr_5343 FROM provincia
)
SELECT 
    1 AS id,
    'Territorio Real Provincial'::text AS capa,
    ROUND((ST_Area(geom_provincia_5343) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_provincia_5343, 4326) AS geom
FROM geometrias
UNION ALL
SELECT 
    2 AS id,
    'MBR (ST_Envelope) Provincial'::text AS capa,
    ROUND((ST_Area(geom_mbr_5343) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_mbr_5343, 4326) AS geom
FROM geometrias;

-- Consulta comparativa de superficies y ratio de ocupación
WITH 
provincia AS (
    SELECT ST_Union(ST_Transform(geom, 5343)) AS geom_5343 FROM entrerios.departamentos
),
areas AS (
    SELECT 
        ST_Area(geom_5343) / 1000000.0 AS area_real_km2,
        ST_Area(ST_Envelope(geom_5343)) / 1000000.0 AS area_mbr_km2
    FROM provincia
)
SELECT 
    ROUND(area_real_km2::numeric, 2) AS superficie_real_provincia_km2,
    ROUND(area_mbr_km2::numeric, 2) AS superficie_mbr_km2,
    ROUND((area_mbr_km2 - area_real_km2)::numeric, 2) AS diferencia_superficie_km2,
    ROUND((area_real_km2 / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_ocupacion_real,
    ROUND(((area_mbr_km2 - area_real_km2) / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_espacio_vacio
FROM areas;

-- Justificación técnica de la diferencia: El MBR genera un rectángulo ortogonal que abarca del extremo norte-sur y este-oeste, englobando ríos limítrofes y suelo de provincias vecinas que la forma cóncava provincial no ocupa.
