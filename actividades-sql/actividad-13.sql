-- Actividad 13. ¿A qué centros derivar si algunos deben cerrar por una crecida?
-- Suponemos una crecida del Río Uruguay: los hospitales y clínicas a 2 km o
-- menos del río no están disponibles. Buscamos un centro de destino fuera de
-- esa franja, en Concordia, y contamos cuántos centros dependerían de cada uno.
-- Datos: departamentos (IGN), superficie de agua del Río Uruguay y salud (OSM),
-- todo del esquema entrerios. Son tres tipos de información.
-- En los datos OSM el Río Uruguay en Concordia no es una línea sino la
-- superficie de agua relation/1101792 de la tabla lagunas (water=river, sin
-- nombre en el archivo). Medimos los 2 km desde la orilla de esa superficie.
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
-- completo en pgAdmin. No crean objetos ni dependen de otras actividades.
-- geography mide en metros; numeric permite redondear a dos decimales.

-- CONSULTA 1. Un destino para cada centro que suponemos cerrado.
-- EXISTS pregunta si el río está cerca sin repetir el centro por cada tramo.
-- Ordenamos los destinos por distancia y elegimos el primero con LIMIT 1.
-- Si empatan, gana el id menor (orden alfabético). geom es el punto de origen y geom_derivacion
-- la línea directa al destino (no una ruta).
-- Resultado: 7 centros cerrados; 3 derivarían a Asistencia Municipal.
WITH departamento AS (
    SELECT geom
    FROM entrerios.departamentos
    WHERE nam = 'Concordia'
), rio_uruguay AS (
    SELECT l.geom
    FROM entrerios.lagunas AS l
    WHERE l.id = 'relation/1101792'
), centros AS (
    SELECT s.id, coalesce(s.name, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM rio_uruguay AS r
               WHERE ST_DWithin(s.geom::geography, r.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.amenity IN ('hospital', 'clinic')
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
-- Resultado: 6 destinos; Asistencia Municipal concentra 3 centros, sería el primero a reforzar.
WITH departamento AS (
    SELECT geom
    FROM entrerios.departamentos
    WHERE nam = 'Concordia'
), rio_uruguay AS (
    SELECT l.geom
    FROM entrerios.lagunas AS l
    WHERE l.id = 'relation/1101792'
), centros AS (
    SELECT s.id, coalesce(s.name, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM rio_uruguay AS r
               WHERE ST_DWithin(s.geom::geography, r.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.amenity IN ('hospital', 'clinic')
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
