-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 11: Calles, OpenStreetMap y Argenmap
-- Subpunto 11.4: Análisis espacial comparativo con Argenmap (IGN)
-- Autor: Grigolato
-- ============================================================================

-- Objetivo:
-- Proporcionar vistas espaciales y consultas para la comparación simultánea
-- entre la cartografía vectorial de OpenStreetMap y el mapa base oficial Argenmap del IGN.
-- Ejes de análisis:
--   1. Cobertura general y densidad
--   2. Ubicación y trazado geométrico
--   3. Sectores rurales y caminos de tierra/huellas
--   4. Zonas de ribera y cursos de agua
--   5. Puentes y cruces hídricos

-- 1. Vista Espacial de la Trama Urbana y Rural de Calles en Concordia (OSM)
CREATE OR REPLACE VIEW entrerios.vw_act11_calles_concordia AS
WITH concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
)
SELECT 
    c.fid AS id,
    c.name AS nombre_calle,
    COALESCE(c.surface, 'no especificada') AS superficie,
    c.geom
FROM capas.calles c
JOIN concordia d ON ST_Intersects(c.geom, d.geom);


-- 2. Detección y Análisis Espacial de Cruces de Vías con Cursos de Agua (Puentes y Pasos)
-- Identifica puntos donde la red vial corta un río o arroyo en Concordia usando índices GiST.
CREATE OR REPLACE VIEW entrerios.vw_act11_cruces_hidricos_concordia AS
WITH concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia' 
    LIMIT 1
),
vias_concordia AS (
    SELECT c.fid, 'calle'::text AS tipo_via, c.name, c.geom
    FROM capas.calles c
    JOIN concordia d ON ST_Intersects(c.geom, d.geom)
    UNION ALL
    SELECT r.fid, r.highway AS tipo_via, r.name, r.geom
    FROM capas.rutas r
    JOIN concordia d ON ST_Intersects(r.geom, d.geom)
),
rios_concordia AS (
    SELECT ri.fid, ri.name AS nombre_rio, ri.geom
    FROM capas.rios ri
    JOIN concordia d ON ST_Intersects(ri.geom, d.geom)
),
intersecciones AS (
    SELECT 
        v.fid AS via_id,
        v.tipo_via,
        COALESCE(v.name, 'S/D') AS via_nombre,
        COALESCE(r.nombre_rio, 'Curso de Agua S/N') AS rio_nombre,
        ST_Intersection(v.geom, r.geom) AS geom_cruce
    FROM vias_concordia v
    JOIN rios_concordia r ON ST_Intersects(v.geom, r.geom)
)
SELECT 
    row_number() OVER () AS id,
    tipo_via,
    via_nombre,
    rio_nombre,
    ST_GeometryN(ST_CollectionExtract(geom_cruce, 1), 1) AS geom
FROM intersecciones
WHERE NOT ST_IsEmpty(geom_cruce);


-- 3. Resumen estadístico de tramos viales por tipo de superficie en Concordia
WITH concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia' 
    LIMIT 1
)
SELECT 
    COALESCE(c.surface, 'Sin clasificar / Asfalto urbano') AS tipo_superficie,
    COUNT(*) AS cantidad_tramos,
    ROUND((SUM(ST_Length(ST_Transform(c.geom, 5343))) / 1000.0)::numeric, 2) AS longitud_total_km,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::numeric, 2) AS pct_tramos
FROM capas.calles c
JOIN concordia d ON ST_Intersects(c.geom, d.geom)
GROUP BY COALESCE(c.surface, 'Sin clasificar / Asfalto urbano')
ORDER BY cantidad_tramos DESC;
