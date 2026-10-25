-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 11: Calles, OpenStreetMap y Argenmap
-- Subpunto 11.1: Densidad de la red vial departamental
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- Esquema: capas / entrerios
-- ============================================================================

-- Objetivo:
-- 1. Calcular la longitud total de calles del departamento Concordia.
-- 2. Comparar este valor con el promedio de los 17 departamentos de Entre Ríos.
-- 3. Calcular la densidad lineal (km de calles / km2 de superficie departamental).

WITH calles_por_depto AS (
    SELECT 
        d.gid,
        d.nam AS departamento,
        COUNT(c.fid) AS cantidad_tramos,
        ROUND((SUM(ST_Length(ST_Transform(c.geom, 5343))) / 1000.0)::numeric, 2) AS longitud_calles_km,
        ROUND((ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0)::numeric, 2) AS superficie_depto_km2
    FROM capas.departamentos d
    LEFT JOIN capas.calles c ON ST_Intersects(c.geom, d.geom)
    GROUP BY d.gid, d.nam, d.geom
),
promedios AS (
    SELECT 
        ROUND(AVG(longitud_calles_km)::numeric, 2) AS prom_provincial_km,
        ROUND(SUM(longitud_calles_km)::numeric, 2) AS total_provincial_km
    FROM calles_por_depto
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY cd.longitud_calles_km DESC) AS ranking_provincial,
    cd.departamento,
    cd.cantidad_tramos,
    cd.longitud_calles_km,
    p.prom_provincial_km,
    ROUND((cd.longitud_calles_km - p.prom_provincial_km)::numeric, 2) AS diferencia_vs_promedio_km,
    ROUND(((cd.longitud_calles_km - p.prom_provincial_km) / p.prom_provincial_km * 100.0)::numeric, 2) AS porcentaje_vs_promedio,
    ROUND((cd.longitud_calles_km / cd.superficie_depto_km2)::numeric, 3) AS densidad_lineal_km_por_km2,
    CASE 
        WHEN cd.departamento ILIKE 'Concordia' THEN '--> SELECCIONADO' 
        ELSE '' 
    END AS observacion
FROM calles_por_depto cd
CROSS JOIN promedios p
ORDER BY cd.longitud_calles_km DESC;
