-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 8: Rutas y accesibilidad sanitaria (Departamento Concordia)
-- Subpunto 8.3: Establecimientos de salud en OpenStreetMap y distribución espacial
-- Autor: Grigolato
-- ============================================================================

-- Objetivo:
-- Identificar hospitales, clínicas y centros asistenciales de salud en Concordia.
-- Analizar su distribución espacial: concentración urbana frente al área rural.

-- 1. Detalle de establecimientos de salud en el departamento
WITH depto_concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia' 
    LIMIT 1
)
SELECT 
    s.id,
    COALESCE(s.nombre, 'Centro de Salud S/D') AS nombre_establecimiento,
    s.amenity AS tipo_amenity,
    COALESCE(s.operator, 'No especificado') AS subtipo_o_gestion,
    ROUND(ST_Y(s.geom)::numeric, 5) AS latitud,
    ROUND(ST_X(s.geom)::numeric, 5) AS longitud
FROM entrerios.salud s
JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
ORDER BY tipo_amenity, nombre_establecimiento;


-- 2. Resumen estadístico por tipología
WITH depto_concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia' 
    LIMIT 1
)
SELECT 
    COALESCE(s.amenity, 'otros') AS tipo_establecimiento,
    COUNT(*) AS cantidad,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::numeric, 2) AS porcentaje
FROM entrerios.salud s
JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
GROUP BY COALESCE(s.amenity, 'otros')
ORDER BY cantidad DESC;


-- 3. Vista Espacial para QGIS
CREATE OR REPLACE VIEW entrerios.vw_act8_salud_concordia AS
WITH depto_concordia AS (
    SELECT geom 
    FROM capas.departamentos 
    WHERE nam ILIKE 'Concordia' 
    LIMIT 1
)
SELECT 
    s.id,
    COALESCE(s.nombre, 'Centro de Salud S/D') AS nombre,
    COALESCE(s.amenity, 'salud') AS tipo,
    s.geom
FROM entrerios.salud s
JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom);
