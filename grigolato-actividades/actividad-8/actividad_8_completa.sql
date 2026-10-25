-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- SCRIPT CONSOLIDADO: ACTIVIDAD 8 COMPLETA
-- Rutas y accesibilidad sanitaria en el Departamento Concordia
-- Autor: Grigolato
-- Sistema Métrico Proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- Esquemas: capas / entrerios
-- ============================================================================

SET search_path TO entrerios, capas, public;

-- ============================================================================
-- 8.1. RED VIAL PRINCIPAL QUE ATRAVIESA EL DEPARTAMENTO
-- ============================================================================
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
rutas_candidatas AS (
    SELECT 
        r.fid,
        r.highway AS categoria,
        COALESCE(r.ref, r.name, 'Sin Denominación') AS identificador_ruta,
        r.name AS nombre_tramo,
        r.ref AS codigo_oficial,
        r.geom
    FROM capas.rutas r
    JOIN depto_concordia d ON ST_Intersects(r.geom, d.geom)
)
SELECT 
    identificador_ruta,
    categoria,
    COUNT(*) AS cantidad_tramos,
    CASE 
        WHEN identificador_ruta ILIKE 'RN%' OR identificador_ruta ILIKE 'Ruta Nacional%' OR codigo_oficial ILIKE 'RN%' THEN 'Ruta Nacional'
        WHEN identificador_ruta ILIKE 'RP%' OR identificador_ruta ILIKE 'Ruta Provincial%' OR codigo_oficial ILIKE 'RP%' THEN 'Ruta Provincial'
        WHEN identificador_ruta ILIKE 'A%' THEN 'Acceso Nacional / Autovía'
        ELSE 'Red Vial Principal / Enlace'
    END AS jurisdiccion
FROM rutas_candidatas
GROUP BY identificador_ruta, categoria, codigo_oficial
ORDER BY jurisdiccion DESC, cantidad_tramos DESC;


-- ============================================================================
-- 8.2. LONGITUD DE LAS RUTAS EN CONCORDIA Y VISTA PARA QGIS
-- ============================================================================
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


-- ============================================================================
-- 8.3. ESTABLECIMIENTOS DE SALUD Y DISTRIBUCIÓN ESPACIAL
-- ============================================================================
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
    ROUND(ST_Y(s.geom)::numeric, 5) AS latitud,
    ROUND(ST_X(s.geom)::numeric, 5) AS longitud,
    s.geom
FROM entrerios.salud s
JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom);

SELECT 
    tipo,
    COUNT(*) AS cantidad,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER())::numeric, 2) AS porcentaje
FROM entrerios.vw_act8_salud_concordia
GROUP BY tipo
ORDER BY cantidad DESC;


-- ============================================================================
-- 8.4. LOCALIDAD MÁS ALEJADA DE UN ESTABLECIMIENTO DE SALUD
-- ============================================================================
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
localidades_concordia AS (
    SELECT c.fid AS loc_id, c.name AS localidad, c.geom AS geom_loc, ST_Transform(c.geom, 5343) AS geom_loc_5343
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
),
salud_concordia AS (
    SELECT s.id, COALESCE(s.nombre, 'Centro S/D') AS hospital, s.geom AS geom_salud, ST_Transform(s.geom, 5343) AS geom_salud_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
),
distancias AS (
    SELECT 
        l.loc_id,
        l.localidad,
        s.hospital,
        ROUND((ST_Distance(l.geom_loc_5343, s.geom_salud_5343) / 1000.0)::numeric, 2) AS distancia_km,
        ROW_NUMBER() OVER (PARTITION BY l.loc_id ORDER BY ST_Distance(l.geom_loc_5343, s.geom_salud_5343) ASC) AS rn
    FROM localidades_concordia l
    CROSS JOIN salud_concordia s
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY distancia_km DESC) AS ranking,
    localidad,
    distancia_km AS distancia_minima_km,
    hospital AS centro_salud_referencia,
    CASE WHEN ROW_NUMBER() OVER (ORDER BY distancia_km DESC) = 1 THEN '--> LOCALIDAD MÁS AISLADA' ELSE '' END AS estado
FROM distancias
WHERE rn = 1
ORDER BY distancia_km DESC;

CREATE OR REPLACE VIEW entrerios.vw_act8_lineas_aislamiento AS
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
localidades_concordia AS (
    SELECT c.fid AS loc_id, c.name AS localidad, c.geom, ST_Transform(c.geom, 5343) AS geom_5343
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
),
salud_concordia AS (
    SELECT s.id, COALESCE(s.nombre, 'Centro S/D') AS hospital, s.geom, ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
),
pares_cercanos AS (
    SELECT 
        l.loc_id,
        l.localidad,
        s.hospital,
        ROUND((ST_Distance(l.geom_5343, s.geom_5343) / 1000.0)::numeric, 2) AS dist_km,
        ST_MakeLine(l.geom, s.geom) AS geom_linea,
        ROW_NUMBER() OVER (PARTITION BY l.loc_id ORDER BY ST_Distance(l.geom_5343, s.geom_5343) ASC) AS rn
    FROM localidades_concordia l
    CROSS JOIN salud_concordia s
)
SELECT 
    loc_id AS id,
    localidad,
    hospital AS hospital_cercano,
    dist_km,
    geom_linea AS geom
FROM pares_cercanos
WHERE rn = 1;


-- ============================================================================
-- 8.5. BUFFER DE 5 KM DE COBERTURA SANITARIA Y LOCALIDADES EXCLUIDAS
-- ============================================================================
CREATE OR REPLACE VIEW entrerios.vw_act8_buffer_salud_5km AS
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
salud_concordia AS (
    SELECT ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
),
buffer_unido AS (
    SELECT ST_Union(ST_Buffer(geom_5343, 5000)) AS geom_buffer_5343
    FROM salud_concordia
),
buffer_recortado AS (
    SELECT ST_Intersection(b.geom_buffer_5343, d.geom_5343) AS geom_cobertura_depto_5343
    FROM buffer_unido b, depto_concordia d
)
SELECT 
    1 AS id,
    'Cobertura Sanitaria 5 km (Concordia)'::text AS descripcion,
    ROUND((ST_Area(geom_cobertura_depto_5343) / 1000000.0)::numeric, 2) AS superficie_cubierta_km2,
    ST_Transform(geom_cobertura_depto_5343, 4326) AS geom
FROM buffer_recortado;

CREATE OR REPLACE VIEW entrerios.vw_act8_localidades_fuera_cobertura AS
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
buffer_salud AS (
    SELECT ST_Union(ST_Buffer(ST_Transform(s.geom, 5343), 5000)) AS geom_buffer_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
)
SELECT 
    c.fid AS id,
    c.name AS localidad,
    c.place AS jerarquia,
    ROUND(ST_Y(c.geom)::numeric, 5) AS latitud,
    ROUND(ST_X(c.geom)::numeric, 5) AS longitud,
    c.geom
FROM capas.ciudades c
JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
CROSS JOIN buffer_salud b
WHERE NOT ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343);

-- Resumen cuantitativo final de cobertura
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
buffer_salud AS (
    SELECT ST_Union(ST_Buffer(ST_Transform(s.geom, 5343), 5000)) AS geom_buffer_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
),
conteo AS (
    SELECT 
        COUNT(*) AS total_localidades,
        COUNT(*) FILTER (WHERE ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343)) AS cubiertas,
        COUNT(*) FILTER (WHERE NOT ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343)) AS sin_cobertura
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
    CROSS JOIN buffer_salud b
)
SELECT 
    total_localidades,
    cubiertas,
    sin_cobertura,
    ROUND((cubiertas * 100.0 / total_localidades)::numeric, 2) AS pct_cubiertas,
    ROUND((sin_cobertura * 100.0 / total_localidades)::numeric, 2) AS pct_sin_cobertura
FROM conteo;
