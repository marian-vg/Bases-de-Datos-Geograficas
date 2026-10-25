-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 8: Rutas y accesibilidad sanitaria (Departamento Concordia)
-- Subpunto 8.2: Longitud de cada ruta dentro del departamento Concordia
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Objetivo:
-- Calcular cuántos kilómetros de cada ruta se encuentran dentro de Concordia.
-- Se utiliza ST_Intersection para recortar estrictamente cada tramo al límite departamental
-- y ST_Transform(..., 5343) con ST_Length para medir distancias métricas sin distorsión angular.

-- 1. Tabla de resultados métricos agrupados por corredor vial
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
tramos_recortados AS (
    SELECT 
        r.fid,
        r.highway AS categoria,
        COALESCE(r.ref, r.name, 'Sin Denominación') AS identificador_ruta,
        r.ref AS codigo_oficial,
        ST_Intersection(ST_Transform(r.geom, 5343), d.geom_5343) AS geom_tramo_5343
    FROM capas.rutas r
    JOIN depto_concordia d ON ST_Intersects(r.geom, d.geom)
)
SELECT 
    identificador_ruta,
    categoria,
    CASE 
        WHEN identificador_ruta ILIKE 'RN%' OR identificador_ruta ILIKE 'Ruta Nacional%' OR codigo_oficial ILIKE 'RN%' THEN 'Nacional'
        WHEN identificador_ruta ILIKE 'RP%' OR identificador_ruta ILIKE 'Ruta Provincial%' OR codigo_oficial ILIKE 'RP%' THEN 'Provincial'
        ELSE 'Otra Jerarquía'
    END AS jurisdiccion,
    COUNT(*) AS tramos_intersecados,
    ROUND((SUM(ST_Length(geom_tramo_5343)) / 1000.0)::numeric, 2) AS longitud_en_concordia_km
FROM tramos_recortados
WHERE NOT ST_IsEmpty(geom_tramo_5343)
GROUP BY identificador_ruta, categoria, codigo_oficial
ORDER BY longitud_en_concordia_km DESC;


-- 2. Creación de Vista Espacial para visualización cartográfica en QGIS
-- Permite cargar directamente la capa en QGIS con la geometría exacta recortada al departamento.
CREATE OR REPLACE VIEW entrerios.vw_act8_rutas_concordia AS
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
)
SELECT 
    row_number() OVER () AS id,
    r.fid AS fid_origen,
    COALESCE(r.ref, r.name, 'Sin Denominación') AS ruta,
    r.highway AS tipo_via,
    ROUND((ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), d.geom_5343)) / 1000.0)::numeric, 3) AS longitud_km,
    ST_Transform(ST_CollectionExtract(ST_Intersection(ST_Transform(r.geom, 5343), d.geom_5343), 2), 4326) AS geom
FROM capas.rutas r
JOIN depto_concordia d ON ST_Intersects(r.geom, d.geom)
WHERE NOT ST_IsEmpty(ST_Intersection(ST_Transform(r.geom, 5343), d.geom_5343));
