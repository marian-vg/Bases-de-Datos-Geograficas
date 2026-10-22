-- Actividad 13. ¿A qué centros derivar si algunos deben cerrar por una crecida?
-- Suponemos una crecida del Río Uruguay: los hospitales y clínicas a 2 km o
-- menos del río no están disponibles. Buscamos un centro de destino fuera de
-- esa franja, en Concordia, y contamos cuántos centros dependerían de cada uno.
-- Datos: departamentos y ríos del profesor (capas), más salud de los archivos
-- OSM anteriores (entrerios). Son tres tipos de información.
-- Preparación: ./chipa-actividades/importar-capas-profe.sh
--
-- Elegimos el Río Uruguay porque es la amenaza real de crecida en Concordia;
-- una laguna o un arroyo chico no inundan la ciudad. Los 2 km son un supuesto
-- del ejercicio, NO un mapa oficial de riesgo. Medimos distancia directa, no
-- un recorrido por calles. No conocemos camas, pacientes ni especialidades.
-- Como destino descartamos laboratorios y centros de kinesiología, que OSM
-- marca como clínicas pero no pueden recibir pacientes derivados.
--
-- ¿Qué decisión ayuda a pensar? Reforzar los destinos que recibirían más
-- centros. Antes de decidir algo real habría que comprobar la crecida, la
-- capacidad sanitaria y los accesos. No repetimos solo la búsqueda de cercanía
-- de 10.3: suponemos cierres, descartamos destinos expuestos y agrupamos.
--
-- Son dos consultas independientes: seleccionar cada bloque WITH ... SELECT
-- completo en pgAdmin. No crean objetos ni necesitan las consultas de actividad 7.
-- geography mide en metros; numeric permite redondear a dos decimales.

-- CONSULTA 1. Un destino para cada centro que suponemos cerrado.
-- EXISTS pregunta si el río está cerca sin repetir el centro por cada tramo.
-- Ordenamos los destinos por distancia y elegimos el primero con LIMIT 1.
-- Si empatan, gana el id menor. geom es el punto de origen y geom_derivacion
-- la línea directa al destino (no una ruta).
-- Resultado: 6 centros cerrados; 4 derivarían a MEDICEF.
WITH departamento AS (
    SELECT geom
    FROM capas.departamentos
    WHERE nam = 'Concordia'
), rio_uruguay AS (
    SELECT r.geom
    FROM capas.rios AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
    WHERE r.name = 'Río Uruguay'
), centros AS (
    SELECT s.id, coalesce(s.nombre, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM rio_uruguay AS r
               WHERE ST_DWithin(s.geom::geography, r.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.atributos->>'amenity' IN ('hospital', 'clinic')
), receptores AS (
    SELECT id, nombre, geom
    FROM centros
    WHERE NOT expuesto
      AND nombre !~* 'laborator|kine'
), derivaciones AS (
    SELECT origen.id, origen.nombre AS centro_origen,
           destino.id AS receptor_id, destino.nombre AS centro_receptor,
           ST_Distance(origen.geom::geography, destino.geom::geography) AS distancia_m,
           origen.geom AS geom_origen, destino.geom AS geom_destino
    FROM centros AS origen
    JOIN receptores AS destino
      ON destino.id = (
          SELECT candidato.id
          FROM receptores AS candidato
          ORDER BY ST_Distance(origen.geom::geography, candidato.geom::geography),
                   candidato.id
          LIMIT 1
      )
    WHERE origen.expuesto
)
SELECT id, centro_origen, receptor_id, centro_receptor,
       round(distancia_m::numeric, 2) AS distancia_directa_m,
       geom_origen AS geom,
       ST_MakeLine(geom_origen, geom_destino) AS geom_derivacion
FROM derivaciones
ORDER BY distancia_m DESC, id;

-- CONSULTA 2. Contamos cuántos centros derivarían a cada destino. No es una
-- cantidad de pacientes ni de camas. Incluimos destinos que recibirían cero.
-- Repetimos los primeros pasos para ejecutar esta consulta por separado.
-- Resultado: 7 destinos; MEDICEF concentra 4 centros, sería el primero a reforzar.
WITH departamento AS (
    SELECT geom
    FROM capas.departamentos
    WHERE nam = 'Concordia'
), rio_uruguay AS (
    SELECT r.geom
    FROM capas.rios AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
    WHERE r.name = 'Río Uruguay'
), centros AS (
    SELECT s.id, coalesce(s.nombre, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM rio_uruguay AS r
               WHERE ST_DWithin(s.geom::geography, r.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.atributos->>'amenity' IN ('hospital', 'clinic')
), receptores AS (
    SELECT id, nombre, geom
    FROM centros
    WHERE NOT expuesto
      AND nombre !~* 'laborator|kine'
), derivaciones AS (
    SELECT origen.id, destino.id AS receptor_id,
           ST_Distance(origen.geom::geography, destino.geom::geography) AS distancia_m
    FROM centros AS origen
    JOIN receptores AS destino
      ON destino.id = (
          SELECT candidato.id
          FROM receptores AS candidato
          ORDER BY ST_Distance(origen.geom::geography, candidato.geom::geography),
                   candidato.id
          LIMIT 1
      )
    WHERE origen.expuesto
)
SELECT receptor.id, receptor.nombre,
       count(d.id) AS centros_a_derivar,
       round((max(d.distancia_m) / 1000.0)::numeric, 2) AS mayor_distancia_km,
       receptor.geom
FROM receptores AS receptor
LEFT JOIN derivaciones AS d ON d.receptor_id = receptor.id
GROUP BY receptor.id, receptor.nombre, receptor.geom
ORDER BY centros_a_derivar DESC, receptor.nombre;

-- QGIS: ejecutar la consulta 1 en DB Manager y cargarla dos veces: una con
-- geom (centros cerrados) y otra con geom_derivacion (líneas hacia el destino).
-- La consulta 2 se carga con geom para ver los destinos y su carga.
-- concordia.qgz usa vistas anteriores: estas consultas no las actualizan.
