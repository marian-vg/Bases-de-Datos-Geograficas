-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- SCRIPT CONSOLIDADO: ACTIVIDAD 11 COMPLETA
-- Calles, OpenStreetMap y Argenmap
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- Esquema: capas / entrerios
-- ============================================================================

SET search_path TO entrerios, capas, public;

-- ============================================================================
-- 11.1. DENSIDAD DE LA RED VIAL DEPARTAMENTAL
-- ============================================================================
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


-- ============================================================================
-- 11.2. DENSIDAD VIAL POR LOCALIDAD (BUFFER DE 2 KM)
-- ============================================================================
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


-- ============================================================================
-- 11.3. CATEGORÍAS PRIMARY Y SECONDARY
-- ============================================================================
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


-- ============================================================================
-- 11.4. VISTAS DE COMPARACIÓN CON ARGENMAP Y CRUCES HÍDRICOS
-- ============================================================================
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
