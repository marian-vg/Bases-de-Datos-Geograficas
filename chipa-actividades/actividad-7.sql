-- Actividad 7. Hidrografía de Concordia.

-- 7.1. ST_Touches exige que los departamentos se toquen sin superponer sus
-- interiores. Los límites de Concordia tienen pequeños solapes con Federación,
-- Federal y Colón: por eso se descartan y solo aparece San Salvador.
-- No significa que sea su único vecino: el resultado está incompleto por la
-- calidad de los límites. No cambiamos a ST_Intersects sin más, porque también
-- aceptaría solapes o contactos en un solo punto.
-- Además, exigimos dimensión 1 (línea), no dimensión 0 (solo un punto).
SELECT vecino.fid AS id,
       vecino.nam AS nombre,
	   vecino.geom as geom,
       ST_GeometryType(vecino.geom) as geometria
FROM capas.departamentos AS elegido
JOIN capas.departamentos AS vecino
  ON elegido.fid <> vecino.fid
 AND ST_Touches(elegido.geom, vecino.geom)
WHERE elegido.nam = 'Concordia'
  AND ST_Dimension(ST_Intersection(elegido.geom, vecino.geom)) = 1;

-- 7.1. Esta consulta muestra los departamentos que se
-- superponen con Concordia y cuánto se superponen, en m². No arregla los datos
-- ni presenta esos solapes como si fueran una frontera compartida.
SELECT vecino.fid AS id, vecino.nam AS departamento_candidato, vecino.geom AS geo,
       ST_Area(ST_Intersection(elegido.geom, vecino.geom)::geography) AS solape_m2
FROM capas.departamentos AS elegido
JOIN capas.departamentos AS vecino
  ON elegido.fid <> vecino.fid AND ST_Intersects(elegido.geom, vecino.geom)
WHERE elegido.nam = 'Concordia'
  AND ST_Dimension(ST_Intersection(elegido.geom, vecino.geom)) = 2
ORDER BY departamento_candidato;

-- 7.2. Elegimos San Salvador, que sí cumple la condición anterior, y obtenemos
-- la línea compartida con Concordia. Mide 74725,22 m; geom permite verla en QGIS.
WITH departamentos_elegidos AS (
    SELECT elegido.fid AS id, vecino.nam AS departamento_vecino,
           ST_CollectionExtract(
               ST_Intersection(elegido.geom, vecino.geom), 2
           ) AS geom
    FROM capas.departamentos AS elegido
    JOIN capas.departamentos AS vecino
      ON ST_Touches(elegido.geom, vecino.geom)
    WHERE elegido.nam = 'Concordia'
      AND vecino.nam = 'San Salvador'
)
SELECT id, departamento_vecino,
       round(ST_Length(geom::geography)::numeric, 2) AS longitud_frontera_m,
       geom
FROM departamentos_elegidos
WHERE NOT ST_IsEmpty(geom);

-- 7.3. Ordenamos los 17 departamentos según las lagunas y cuerpos de agua
-- registrados. Si uno cruza un límite, cuenta en ambos departamentos.
-- El archivo OSM puede tener faltantes o duplicados porque el ranking describe los datos, no el agua real.
WITH cantidades AS (
    SELECT d.fid AS id, d.nam AS nombre, count(l.id) AS cuerpos_de_agua
    FROM capas.departamentos AS d
    LEFT JOIN entrerios.lagunas AS l ON ST_Intersects(d.geom, l.geom)
    GROUP BY d.fid, d.nam
)
SELECT rank() OVER (ORDER BY cuerpos_de_agua DESC) AS puesto_provisional,
       id, nombre, cuerpos_de_agua,
       '17 departamentos; cobertura y calidad del agua OSM no verificadas' AS alcance
FROM cantidades
ORDER BY puesto_provisional, nombre;

-- 7.4. Primero recortamos el agua al límite de Concordia. Después unimos las
-- partes para no sumar dos veces las zonas superpuestas. Dividimos los m² por
-- 1000000 para obtener km². Si no hay agua registrada, su superficie es cero.
-- Resultado: total 3292,75; agua 72,95; restante 3219,80 km²; agua 2,22 %.
WITH departamento AS (
    SELECT fid AS id, nam AS nombre, geom
    FROM capas.departamentos
    WHERE nam = 'Concordia'
), agua_unida AS (
    SELECT ST_Union(ST_Intersection(l.geom, d.geom)) AS geom
    FROM entrerios.lagunas AS l
    JOIN departamento AS d ON ST_Intersects(l.geom, d.geom)
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

-- 7.5. Recortamos los ríos y arroyos a Concordia y medimos sus tramos en metros.
-- ST_CollectionExtract conserva las líneas: tocar el límite en un solo punto
-- no suma longitud. Cada fila es un tramo del archivo, no necesariamente todo
-- un río. Tomamos river/stream (ríos/arroyos), no canales.
WITH recortes AS (
    SELECT r.fid AS id, coalesce(r.name, '(sin nombre)') AS nombre,
           ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
    FROM capas.rios AS r
    JOIN capas.departamentos AS d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia'
      AND r.waterway IN ('river', 'stream')
)
SELECT id, nombre,
       ST_Length(geom::geography) AS longitud_m,
       geom
FROM recortes
WHERE NOT ST_IsEmpty(geom);

-- 7.5. Sumamos los tramos: 119 en total, con una longitud de 552998,75 m.
-- Repetimos el recorte para que esta consulta también pueda ejecutarse sola.
WITH recortes AS (
    SELECT ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
    FROM capas.rios AS r
    JOIN capas.departamentos AS d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia'
      AND r.waterway IN ('river', 'stream')
)
SELECT count(*) AS tramos,
       round(sum(ST_Length(geom::geography))::numeric, 2) AS longitud_total_m
FROM recortes
WHERE NOT ST_IsEmpty(geom);

-- QGIS: cargar una consulta con id y geom desde DB Manager para verla en el mapa.
-- concordia.qgz usa vistas de una entrega anterior: ejecutar estas consultas
-- no las actualiza. Para ver este resultado, cargar la consulta directamente.
