-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 8: Rutas y accesibilidad sanitaria (Departamento Concordia)
-- Subpunto 8.5: Área de cobertura sanitaria de 5 km y localidades excluidas
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Metodología:
-- 1. Se genera un buffer de radio R = 5.000 m alrededor de cada establecimiento de salud.
-- 2. Se unifican (ST_Union) todos los buffers para formar un área continua de cobertura.
-- 3. Se evalúa mediante ST_Intersects / ST_Disjoint qué localidades del departamento
--    quedan contenidas dentro del radio de atención primaria de 5 km y cuáles quedan desprotegidas.

-- 1. Vista Espacial del Polígono de Cobertura Sanitaria (5 km) disuelto para QGIS
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
    -- Opcional: recortar al límite del departamento para métricas de superficie departamental
    SELECT ST_Intersection(b.geom_buffer_5343, d.geom_5343) AS geom_cobertura_depto_5343
    FROM buffer_unido b, depto_concordia d
)
SELECT 
    1 AS id,
    'Cobertura Sanitaria 5 km (Concordia)'::text AS descripcion,
    ROUND((ST_Area(geom_cobertura_depto_5343) / 1000000.0)::numeric, 2) AS superficie_cubierta_km2,
    ST_Transform(geom_cobertura_depto_5343, 4326) AS geom
FROM buffer_recortado;


-- 2. Identificación y clasificación de localidades (Dentro vs Fuera de Cobertura)
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
localidades_clasificadas AS (
    SELECT 
        c.fid AS localidad_id,
        c.name AS localidad,
        c.place AS jerarquia_urbana,
        ROUND(ST_Y(c.geom)::numeric, 5) AS latitud,
        ROUND(ST_X(c.geom)::numeric, 5) AS longitud,
        c.geom,
        CASE 
            WHEN ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343) THEN 'DENTRO DE COBERTURA'
            ELSE 'FUERA DE COBERTURA (DESPROTEGIDA)'
        END AS estado_cobertura
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
    CROSS JOIN buffer_salud b
)
SELECT 
    localidad,
    jerarquia_urbana,
    latitud,
    longitud,
    estado_cobertura
FROM localidades_clasificadas
ORDER BY estado_cobertura DESC, localidad ASC;


-- 3. Resumen cuantitativo departamental
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
        COUNT(*) FILTER (WHERE ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343)) AS localidades_cubiertas,
        COUNT(*) FILTER (WHERE NOT ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343)) AS localidades_sin_cobertura
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
    CROSS JOIN buffer_salud b
)
SELECT 
    total_localidades,
    localidades_cubiertas,
    localidades_sin_cobertura,
    ROUND((localidades_cubiertas * 100.0 / total_localidades)::numeric, 2) AS pct_localidades_cubiertas,
    ROUND((localidades_sin_cobertura * 100.0 / total_localidades)::numeric, 2) AS pct_localidades_sin_cobertura
FROM conteo;


-- 4. Vista Espacial para QGIS: Localidades desprotegidas (fuera del buffer)
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
    c.place AS tipo,
    c.geom
FROM capas.ciudades c
JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
CROSS JOIN buffer_salud b
WHERE NOT ST_Intersects(ST_Transform(c.geom, 5343), b.geom_buffer_5343);
