-- Actividad 12. Información del INTA y uso del suelo (departamento Concordia)
-- La Carta de Suelos del INTA se incorporó a QGIS por WFS
-- (geo-nodo03.inta.gob.ar/geoserver/wfs) y se guardó en PostGIS como
-- entrerios.suelo, con sus columnas originales (nombre, ipc, ...).
-- Datos: departamentos, suelo, ríos, lagunas y rutas del esquema entrerios.
--
-- La capa no trae "uso del suelo", sino unidades cartográficas de suelo con su
-- Índice de Productividad (IPC, de 0 a 100). Criterio del grupo:
--   agrícola   -> IPC >= 20 (series y asociaciones de lomas y planicies);
--   otros usos -> IPC < 20 (valles inundables de arroyos, aptos para ganadería
--                 o monte) y unidades sin suelo productivo (IPC 0: áreas
--                 urbanas, cuerpos de agua, islas y bañados).
-- El IPC mide aptitud, no lo que hoy está sembrado.
--
-- Áreas y longitudes se miden con geography (metros y m², sobre el elipsoide),
-- igual que en la actividad 7. Se divide por 1.000.000 para km² y por 1.000
-- para km. numeric permite redondear a dos decimales.
-- Cada consulta es independiente: seleccionar el bloque completo en pgAdmin.

-- PASO PREVIO. Campo derivado con la clasificación (se ejecuta una sola vez).
ALTER TABLE entrerios.suelo ADD COLUMN IF NOT EXISTS uso_suelo varchar(20);

UPDATE entrerios.suelo
SET uso_suelo = CASE
                    WHEN ipc >= 20 THEN 'agricola'
                    ELSE 'otros usos'
                END;


-- 12.1. Uso del suelo. ¿Qué porcentaje de Concordia es agrícola?
-- ST_Intersection recorta cada polígono de suelo al departamento; luego se
-- suman las superficies por clase y se comparan con la superficie total.
-- Resultado: agrícola 2.416,68 km² (73,39 %); otros usos 874,04 km² (26,54 %).
-- El 0,07 % restante son bordes del departamento sin polígono de suelo.
WITH departamento AS (
    SELECT geom
    FROM entrerios.departamentos
    WHERE nam = 'Concordia'
), suelo_concordia AS (
    SELECT s.uso_suelo,
           ST_Intersection(s.geom, d.geom) AS geom
    FROM entrerios.suelo AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
)
SELECT sc.uso_suelo,
       round((sum(ST_Area(sc.geom::geography)) / 1000000)::numeric, 2) AS superficie_km2,
       round((sum(ST_Area(sc.geom::geography))
              / (SELECT ST_Area(geom::geography) FROM departamento) * 100)::numeric, 2) AS porcentaje
FROM suelo_concordia AS sc
GROUP BY sc.uso_suelo
ORDER BY sc.uso_suelo;


-- 12.2. Áreas agrícolas expuestas.
-- Se repite la Zona de Riesgo Hídrico de la actividad 9: franja de 2.000 m
-- alrededor de ríos, arroyos y lagunas de Concordia, recortada al departamento.
-- ST_Buffer sobre geography mide los 2.000 m en metros; ST_Union une las
-- franjas para no contar dos veces la superficie donde se superponen.
-- MATERIALIZED obliga a calcular la zona una sola vez; sin él, PostgreSQL la
-- recalcula por cada polígono de suelo y la consulta tarda varios minutos.
-- Después se recortan los suelos agrícolas a esa zona. geom sirve para QGIS.
-- Resultado: 2.022,47 km² agrícolas expuestos, el 83,69 % de lo agrícola.
WITH departamento AS (
    SELECT geom
    FROM entrerios.departamentos
    WHERE nam = 'Concordia'
), agua AS (
    SELECT r.geom
    FROM entrerios.rios AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
    UNION ALL
    SELECT l.geom
    FROM entrerios.lagunas AS l
    JOIN departamento AS d ON ST_Intersects(l.geom, d.geom)
), zona_riesgo AS MATERIALIZED (
    SELECT ST_Intersection(ST_Union(ST_Buffer(a.geom::geography, 2000)::geometry),
                           (SELECT geom FROM departamento)) AS geom
    FROM agua AS a
), agricola AS (
    SELECT s.nombre, ST_Intersection(s.geom, d.geom) AS geom
    FROM entrerios.suelo AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.uso_suelo = 'agricola'
), expuesta AS (
    SELECT a.nombre,
           ST_Area(a.geom::geography) AS area_agricola,
           ST_Intersection(a.geom, z.geom) AS geom
    FROM agricola AS a, zona_riesgo AS z
)
SELECT e.nombre AS unidad_de_suelo,
       round((sum(e.area_agricola) / 1000000)::numeric, 2) AS agricola_km2,
       round((sum(ST_Area(e.geom::geography)) / 1000000)::numeric, 2) AS expuesta_km2,
       round((sum(ST_Area(e.geom::geography)) / sum(e.area_agricola) * 100)::numeric, 2) AS porcentaje_expuesto,
       ST_Union(e.geom) AS geom
FROM expuesta AS e
GROUP BY e.nombre
ORDER BY expuesta_km2 DESC;


-- 12.3. Corredores productivos.
-- ST_Intersection entre las rutas principales y los suelos agrícolas deja solo
-- los tramos de ruta que atraviesan campos agrícolas. Se agrupan por número de
-- ruta (ref) y se comparan con el largo total de esa ruta en el departamento.
-- Resultado: 195,51 de 317,89 km de rutas (61,5 %) cruzan suelo agrícola;
-- la RN14 aporta 101,88 km.
WITH departamento AS (
    SELECT geom
    FROM entrerios.departamentos
    WHERE nam = 'Concordia'
), rutas_concordia AS (
    SELECT coalesce(r.ref, '(sin número)') AS ruta,
           ST_Intersection(r.geom, d.geom) AS geom
    FROM entrerios.rutas AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
), agricola AS (
    SELECT s.geom
    FROM entrerios.suelo AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.uso_suelo = 'agricola'
), tramos_agricolas AS (
    SELECT rc.ruta, ST_Intersection(rc.geom, a.geom) AS geom
    FROM rutas_concordia AS rc
    JOIN agricola AS a ON ST_Intersects(rc.geom, a.geom)
), largo_total AS (
    SELECT ruta, sum(ST_Length(geom::geography)) AS metros
    FROM rutas_concordia
    GROUP BY ruta
)
SELECT t.ruta,
       round((lt.metros / 1000)::numeric, 2) AS km_en_departamento,
       round((sum(ST_Length(t.geom::geography)) / 1000)::numeric, 2) AS km_sobre_agricola,
       round((sum(ST_Length(t.geom::geography)) / lt.metros * 100)::numeric, 2) AS porcentaje,
       ST_Union(t.geom) AS geom
FROM tramos_agricolas AS t
JOIN largo_total AS lt ON lt.ruta = t.ruta
GROUP BY t.ruta, lt.metros
ORDER BY km_sobre_agricola DESC;
