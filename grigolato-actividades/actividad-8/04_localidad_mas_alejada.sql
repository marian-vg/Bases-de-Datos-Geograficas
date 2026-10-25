-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 8: Rutas y accesibilidad sanitaria (Departamento Concordia)
-- Subpunto 8.4: Localidad más alejada de un establecimiento de salud
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Metodología y criterio aplicado:
-- 1. Se identifican todas las localidades del departamento Concordia (capas.ciudades).
-- 2. Para cada localidad, se calcula la distancia métrica euclidiana hacia TODOS los
--    establecimientos de salud del departamento, reproyectando a POSGAR 07 Faja 5 (EPSG:5343).
-- 3. Se extrae el hospital/clínica más cercano para cada localidad (mínima distancia).
-- 4. Se ordena el ranking de manera descendente: la localidad en la posición 1 es
--    la que presenta la MAYOR distancia respecto a su centro de salud más próximo.
-- 
-- Justificación del criterio:
-- La distancia euclidiana en un sistema proyectado ortogonal (EPSG:5343) proporciona una
-- métrica rigurosa e imparcial de proximidad espacial (cota mínima teórica). En la realidad,
-- la distancia por red vial es aún mayor debido a la sinuosidad de los caminos, lo cual
-- acentúa todavía más la vulnerabilidad de las localidades rurales aisladas.

-- 1. Ranking de localidades de Concordia según su distancia al centro de salud más cercano
WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
localidades_concordia AS (
    SELECT 
        c.fid AS localidad_id,
        c.name AS localidad,
        c.geom AS geom_loc,
        ST_Transform(c.geom, 5343) AS geom_loc_5343
    FROM capas.ciudades c
    JOIN depto_concordia d ON ST_Intersects(c.geom, d.geom)
),
salud_concordia AS (
    SELECT 
        s.id AS salud_id,
        COALESCE(s.nombre, 'Centro de Salud S/D') AS hospital,
        s.amenity AS tipo,
        s.geom AS geom_salud,
        ST_Transform(s.geom, 5343) AS geom_salud_5343
    FROM entrerios.salud s
    JOIN depto_concordia d ON ST_Intersects(s.geom, d.geom)
),
distancias_cruzadas AS (
    SELECT 
        l.localidad_id,
        l.localidad,
        s.salud_id,
        s.hospital,
        s.tipo AS tipo_salud,
        ROUND((ST_Distance(l.geom_loc_5343, s.geom_salud_5343) / 1000.0)::numeric, 2) AS distancia_km,
        l.geom_loc,
        s.geom_salud,
        ROW_NUMBER() OVER (PARTITION BY l.localidad_id ORDER BY ST_Distance(l.geom_loc_5343, s.geom_salud_5343) ASC) AS orden_cercania
    FROM localidades_concordia l
    CROSS JOIN salud_concordia s
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY distancia_km DESC) AS ranking_aislamiento,
    localidad,
    distancia_km AS distancia_al_mas_cercano_km,
    hospital AS centro_salud_mas_cercano,
    tipo_salud,
    CASE 
        WHEN ROW_NUMBER() OVER (ORDER BY distancia_km DESC) = 1 THEN '--> LOCALIDAD MÁS ALEJADA'
        ELSE ''
    END AS observacion
FROM distancias_cruzadas
WHERE orden_cercania = 1
ORDER BY distancia_km DESC;


-- 2. Vista Espacial para QGIS: Líneas de conexión Localidad -> Centro de Salud más cercano
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
    SELECT s.id AS salud_id, COALESCE(s.nombre, 'Centro S/D') AS hospital, s.geom, ST_Transform(s.geom, 5343) AS geom_5343
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
WHERE rn = 1
ORDER BY dist_km DESC;
