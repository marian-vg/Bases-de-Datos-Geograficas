-- Actividad 7. Hidrografía de Concordia.
-- Ejecutar completo en Query Tool o: ./scripts/psql.sh < chipa-actividades/actividad-7.sql
-- No modifica entrerios ni fuentes. Las vistas se pueden ejecutar nuevamente.
-- Preparación: ./chipa-actividades/importar-capas-profe.sh
-- Fuentes: límites IGN y ríos/arroyos entregados por el profesor (fuentes_profe);
-- polígonos de agua del export OSM previo (entrerios.lagunas). No se reemplaza
-- ninguna fuente original. La capa procesada de departamentos tenía acentos
-- corruptos: se usa el SHP completo, DBF Latin-1 y código provincial in1=30xxx.
-- Hay 17 departamentos, pero la cobertura/calidad OSM de agua no está validada:
-- puede haber objetos duplicados, faltantes o coberturas desiguales. El ranking
-- cuenta objetos por departamento, no cuerpos físicos únicos; un cuerpo que
-- cruza un límite cuenta en ambos. No es un indicador de riesgo por sí solo.
-- Contradicción topológica: Concordia y algunos candidatos vecinos tienen
-- pequeños solapes. No se corrigen ni se inventa una lista completa de vecinos;
-- se muestra ST_Touches literal y un diagnóstico separado de esos solapes.
-- Diagnóstico inicial: Federación ~37,16 m², Federal ~0,0208 m² y Colón
-- ~0,000317 m² de solape. ST_Touches solo identifica San Salvador; esto NO
-- demuestra que sea el único vecino real. Resolver la calidad de límites
-- requiere una decisión sobre los datos: aquí no se aplica corrección.

BEGIN;
CREATE SCHEMA IF NOT EXISTS chipa_actividades;

-- 7.1. Vecinos: ST_Touches incluye contacto puntual. Se exige frontera lineal
-- de longitud positiva para considerar que dos departamentos son limítrofes.
-- Referencia: https://postgis.net/docs/ST_Touches.html
CREATE OR REPLACE VIEW chipa_actividades.a7_vecinos AS
SELECT vecino.fid AS id,
       vecino.nam::text AS nombre,
       vecino.geom::geometry(MultiPolygon, 4326) AS geom
FROM fuentes_profe.departamentos AS elegido
JOIN fuentes_profe.departamentos AS vecino
  ON elegido.fid <> vecino.fid
 AND ST_Touches(elegido.geom, vecino.geom)
WHERE elegido.nam = 'Concordia'
  AND ST_Length(
        ST_CollectionExtract(
            ST_Intersection(elegido.geom, vecino.geom), 2
        )::geography
      ) > 0;

-- 7.2. Se elige el primer vecino por nombre para visualizar su frontera común.
-- Con los límites entregados, el criterio literal identifica San Salvador.
-- Los otros contactos candidatos tienen solapes; ver diagnóstico al final.
CREATE OR REPLACE VIEW chipa_actividades.a7_frontera_comun AS
WITH vecino_elegido AS (
    SELECT id AS fid, nombre AS nam, geom
    FROM chipa_actividades.a7_vecinos
    ORDER BY nombre, id
    LIMIT 1
)
SELECT vecino.fid AS id,
       vecino.nam AS departamento_vecino,
       ST_Multi(
           ST_CollectionExtract(
               ST_Intersection(elegido.geom, vecino.geom), 2
           )
       )::geometry(MultiLineString, 4326) AS geom
FROM fuentes_profe.departamentos AS elegido
CROSS JOIN vecino_elegido AS vecino
WHERE elegido.nam = 'Concordia';

-- 7.3. Ranking provincial PROVISIONAL por cobertura/calidad de la fuente OSM.
CREATE OR REPLACE VIEW chipa_actividades.a7_ranking_agua AS
WITH cantidades AS (
    SELECT d.fid AS id, d.nam::text AS nombre, count(l.id) AS cuerpos_de_agua
    FROM fuentes_profe.departamentos AS d
    LEFT JOIN entrerios.lagunas AS l ON ST_Intersects(d.geom, l.geom)
    GROUP BY d.fid, d.nam
)
SELECT rank() OVER (ORDER BY cuerpos_de_agua DESC) AS puesto_provisional,
       id, nombre, cuerpos_de_agua,
       '17 departamentos; cobertura y calidad del agua OSM no verificadas'::text AS alcance
FROM cantidades;

-- 7.4. Recortar al departamento y unir el agua evita sumar superficies
-- superpuestas. COALESCE permite obtener cero si no hay polígonos de agua.
-- geography mide m² sobre el elipsoide; dividir por 1.000.000 da km².
-- Referencia: https://postgis.net/docs/ST_Union.html
CREATE OR REPLACE VIEW chipa_actividades.a7_superficies AS
WITH departamento AS (
    SELECT fid AS id, nam::text AS nombre, geom::geometry(MultiPolygon, 4326) AS geom
    FROM fuentes_profe.departamentos
    WHERE nam = 'Concordia'
), agua_recortada AS (
    SELECT ST_Intersection(l.geom, d.geom) AS geom
    FROM entrerios.lagunas AS l
    JOIN departamento AS d ON ST_Intersects(l.geom, d.geom)
), agua_unida AS (
    SELECT ST_Union(geom) AS geom
    FROM agua_recortada
), superficies AS (
    SELECT d.id, d.nombre,
           ST_Area(d.geom::geography) / 1000000.0 AS total_km2,
           coalesce(ST_Area(a.geom::geography), 0) / 1000000.0 AS agua_km2,
           d.geom
    FROM departamento AS d
    CROSS JOIN agua_unida AS a
)
SELECT id, nombre,
       round(total_km2::numeric, 2) AS superficie_total_km2,
       round(agua_km2::numeric, 2) AS superficie_agua_km2,
       round((total_km2 - agua_km2)::numeric, 2) AS superficie_restante_km2,
       round((100 * agua_km2 / nullif(total_km2, 0))::numeric, 2) AS porcentaje_agua,
       geom
FROM superficies;

-- 7.5. Se conserva solo la parte lineal de cada curso dentro de Concordia.
-- Un contacto exclusivamente puntual no aporta longitud y se descarta.
-- Se excluyen 9 canales: se solicitan ríos y arroyos (river/stream).
-- Cada fila representa un objeto de la fuente, no necesariamente un río entero.
CREATE OR REPLACE VIEW chipa_actividades.a7_cursos_de_agua AS
WITH recortes AS (
    SELECT r.fid AS id, coalesce(r.name, '(sin nombre)')::text AS nombre,
           ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
    FROM fuentes_profe.rios AS r
    JOIN fuentes_profe.departamentos AS d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia'
      AND r.waterway IN ('river', 'stream')
)
SELECT id, nombre,
       ST_Length(geom::geography) AS longitud_m,
       ST_Multi(geom)::geometry(MultiLineString, 4326) AS geom
FROM recortes
WHERE NOT ST_IsEmpty(geom);
-- Diagnóstico: solapes geométricos, NO una frontera común ni vecindad resuelta.
-- No se alteran límites ni se utiliza tolerancia para forzar ST_Touches.
CREATE OR REPLACE VIEW chipa_actividades.a7_solapes_limites AS
SELECT vecino.fid AS id, vecino.nam AS departamento_candidato,
       ST_Area(ST_Intersection(elegido.geom, vecino.geom)::geography) AS solape_m2
FROM fuentes_profe.departamentos AS elegido
JOIN fuentes_profe.departamentos AS vecino
  ON elegido.fid <> vecino.fid AND ST_Intersects(elegido.geom, vecino.geom)
WHERE elegido.nam = 'Concordia'
  AND ST_Dimension(ST_Intersection(elegido.geom, vecino.geom)) = 2;
COMMIT;

-- Control con los archivos entregados: 17 departamentos; agua en Concordia
-- 72,95 km² sobre 3292,75 km² (2,22 %); 119 tramos con longitud positiva,
-- 552998,75 m en total. Cambian frente al export anterior porque las fuentes
-- hidrográficas no contienen el mismo conjunto de objetos ni igual cobertura.
-- Resultados tabulares. Las vistas con geom se agregan directamente en QGIS.
SELECT 'Vecindad literal incompleta por solapes; ranking OSM provisional' AS advertencia;
SELECT * FROM chipa_actividades.a7_solapes_limites ORDER BY departamento_candidato;
SELECT id, nombre FROM chipa_actividades.a7_vecinos ORDER BY nombre;
SELECT id, departamento_vecino FROM chipa_actividades.a7_frontera_comun;
SELECT * FROM chipa_actividades.a7_ranking_agua ORDER BY puesto_provisional, nombre;
-- Cero objetos observados no significa ausencia real de agua.
SELECT nombre AS departamento_sin_objetos_en_el_export
FROM chipa_actividades.a7_ranking_agua WHERE cuerpos_de_agua = 0;
SELECT nombre, superficie_total_km2, superficie_agua_km2,
       superficie_restante_km2, porcentaje_agua
FROM chipa_actividades.a7_superficies;
SELECT nombre, count(*) AS segmentos,
       round(sum(longitud_m)::numeric, 2) AS longitud_total_m
FROM chipa_actividades.a7_cursos_de_agua
GROUP BY nombre
ORDER BY longitud_total_m DESC;
SELECT round(sum(longitud_m)::numeric, 2) AS longitud_total_cursos_m
FROM chipa_actividades.a7_cursos_de_agua;
