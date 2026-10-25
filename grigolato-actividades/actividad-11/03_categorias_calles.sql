-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 11: Calles, OpenStreetMap y Argenmap
-- Subpunto 11.3: Categorías de calles (primary y secondary)
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Objetivo:
-- Identificar las vías clasificadas en OpenStreetMap como primary y secondary,
-- y cuantificar cuántos kilómetros corresponden a cada categoría tanto a nivel
-- provincial como específico dentro del departamento Concordia.

-- 1. Resumen comparativo: Longitud por categoría (Provincia de Entre Ríos vs Concordia)
WITH concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
)
SELECT 
    r.highway AS categoria_via,
    COUNT(*) AS cantidad_tramos_provincia,
    ROUND((SUM(ST_Length(ST_Transform(r.geom, 5343))) / 1000.0)::numeric, 2) AS longitud_provincial_km,
    COUNT(CASE WHEN ST_Intersects(r.geom, c.geom) THEN 1 END) AS cantidad_tramos_concordia,
    ROUND((SUM(CASE WHEN ST_Intersects(r.geom, c.geom) 
                    THEN ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343)) 
                    ELSE 0 END) / 1000.0)::numeric, 2) AS longitud_concordia_km,
    ROUND(((SUM(CASE WHEN ST_Intersects(r.geom, c.geom) 
                     THEN ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343)) 
                     ELSE 0 END) / 
            NULLIF(SUM(ST_Length(ST_Transform(r.geom, 5343))), 0)) * 100.0)::numeric, 2) AS pct_en_concordia
FROM capas.rutas r
CROSS JOIN concordia c
WHERE r.highway IN ('primary', 'secondary')
GROUP BY r.highway
ORDER BY r.highway;


-- 2. Detalle de corredores viales principales y secundarios en Concordia
WITH concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
)
SELECT 
    r.highway AS categoria,
    COALESCE(r.ref, r.name, '(Sin Denominación)') AS denominacion,
    COUNT(*) AS cantidad_tramos,
    ROUND((SUM(ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343))) / 1000.0)::numeric, 2) AS longitud_km
FROM capas.rutas r
JOIN concordia c ON ST_Intersects(r.geom, c.geom)
WHERE r.highway IN ('primary', 'secondary')
GROUP BY r.highway, COALESCE(r.ref, r.name, '(Sin Denominación)')
ORDER BY r.highway, longitud_km DESC;


-- 3. Vista Espacial para QGIS: Corredores Primary y Secondary en Concordia
CREATE OR REPLACE VIEW entrerios.vw_act11_primary_secondary_concordia AS
WITH concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
)
SELECT 
    r.fid AS id,
    r.highway AS categoria,
    COALESCE(r.ref, r.name, 'S/D') AS nombre_o_codigo,
    ROUND((ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343)) / 1000.0)::numeric, 3) AS longitud_km,
    ST_Transform(ST_CollectionExtract(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343), 2), 4326) AS geom
FROM capas.rutas r
JOIN concordia c ON ST_Intersects(r.geom, c.geom)
WHERE r.highway IN ('primary', 'secondary')
  AND NOT ST_IsEmpty(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343));
