-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 11: Calles, OpenStreetMap y Argenmap
-- Subpunto 11.2: Densidad vial por localidad (Departamento Concordia)
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Objetivo:
-- Determinar qué localidad presenta la mayor densidad vial:
--     Densidad = Longitud total de calles / Superficie de la localidad
-- 
-- Decisión Metodológica y Justificación Técnica:
-- En OpenStreetMap (capas.ciudades / place=city|town|village), las localidades están
-- modeladas mediante entidades geométricas de tipo PUNTO (centroides de asentamiento).
-- Debido a que no se dispone de polígonos catastrales o radios censales oficiales,
-- adoptar un límite empírico arbitrario distorsionaría la comparación.
-- Por tal motivo, se adopta un BUFFER CIRCULAR ESTANDARIZADO con radio R = 2.000 m (2 km)
-- centrado en cada localidad, delimitando una envolvente de análisis uniforme:
--     Área teórica = π * R^2 = π * (2.000 m)^2 ≈ 12,57 km²
-- 
-- Sobre dicha envolvente se intersectan y miden las calles contenidas:
--     Densidad vial (km/km²) = Longitud de calles (km) / 12,57 km²

-- 1. Ranking de localidades de Concordia ordenadas por densidad vial
WITH loc_concordia AS (
    SELECT 
        c.fid AS localidad_id,
        c.name AS localidad,
        c.geom AS geom_punto,
        ST_Buffer(ST_Transform(c.geom, 5343), 2000) AS geom_urbana_5343
    FROM capas.ciudades c
    JOIN capas.departamentos d ON ST_Intersects(c.geom, d.geom)
    WHERE d.nam ILIKE 'Concordia'
)
SELECT 
    ROW_NUMBER() OVER (
        ORDER BY (COALESCE(SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))), 0) / ST_Area(lc.geom_urbana_5343)) DESC
    ) AS ranking_densidad,
    lc.localidad,
    ROUND(ST_Y(lc.geom_punto)::numeric, 5) AS latitud,
    ROUND(ST_X(lc.geom_punto)::numeric, 5) AS longitud,
    ROUND((ST_Area(lc.geom_urbana_5343) / 1000000.0)::numeric, 2) AS superficie_analizada_km2,
    COUNT(ca.fid) AS cantidad_tramos_calles,
    ROUND((COALESCE(SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))), 0) / 1000.0)::numeric, 2) AS longitud_calles_km,
    ROUND(((COALESCE(SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))), 0) / 1000.0) / (ST_Area(lc.geom_urbana_5343) / 1000000.0))::numeric, 2) AS densidad_vial_km_km2
FROM loc_concordia lc
LEFT JOIN capas.calles ca ON ST_Intersects(ca.geom, ST_Transform(lc.geom_urbana_5343, 4326))
GROUP BY lc.localidad_id, lc.localidad, lc.geom_punto, lc.geom_urbana_5343
ORDER BY densidad_vial_km_km2 DESC;


-- 2. Vista Espacial para QGIS: Buffers urbanos de 2 km coloreados por densidad
CREATE OR REPLACE VIEW entrerios.vw_act11_densidad_localidades AS
WITH loc_concordia AS (
    SELECT 
        c.fid AS localidad_id,
        c.name AS localidad,
        c.geom AS geom_punto,
        ST_Buffer(ST_Transform(c.geom, 5343), 2000) AS geom_urbana_5343
    FROM capas.ciudades c
    JOIN capas.departamentos d ON ST_Intersects(c.geom, d.geom)
    WHERE d.nam ILIKE 'Concordia'
)
SELECT 
    lc.localidad_id AS id,
    lc.localidad,
    ROUND((ST_Area(lc.geom_urbana_5343) / 1000000.0)::numeric, 2) AS superficie_km2,
    ROUND((COALESCE(SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))), 0) / 1000.0)::numeric, 2) AS calles_km,
    ROUND(((COALESCE(SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))), 0) / 1000.0) / (ST_Area(lc.geom_urbana_5343) / 1000000.0))::numeric, 2) AS densidad_km_km2,
    ST_Transform(lc.geom_urbana_5343, 4326) AS geom
FROM loc_concordia lc
LEFT JOIN capas.calles ca ON ST_Intersects(ca.geom, ST_Transform(lc.geom_urbana_5343, 4326))
GROUP BY lc.localidad_id, lc.localidad, lc.geom_urbana_5343;
