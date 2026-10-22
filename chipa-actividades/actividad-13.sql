-- Actividad 13. ¿A qué centros derivar si algunos deben cerrar por una crecida?
-- Suponemos que los hospitales y clínicas a 2 km o menos del agua no están
-- disponibles. Buscamos un centro de destino fuera de esa franja, en Concordia,
-- y contamos cuántos centros dependerían de cada destino.
-- Datos: departamentos y ríos del profesor (capas), más salud y lagunas de los
-- archivos OSM anteriores (entrerios). Son al menos tres tipos de información.
-- Preparación: ./chipa-actividades/importar-capas-profe.sh
--
-- Los 2 km son un supuesto del ejercicio, NO una inundación observada ni un
-- mapa oficial de riesgo. Consideramos los cursos y lagunas que tocan Concordia;
-- usamos su forma completa para medir cercanía, sin cortarla en el límite.
-- Medimos distancia directa, no un recorrido por calles. No conocemos camas,
-- pacientes, especialidades ni si los centros realmente están funcionando.
--
-- ¿Qué decisión ayuda a pensar? Coordinar los destinos que recibirían más
-- centros. Si no hay destinos, estudiar apoyo externo o un hospital de campaña.
-- Antes de decidir algo real habría que comprobar la crecida, la capacidad
-- sanitaria y los accesos. No repetimos solo la búsqueda de cercanía de 10.3:
-- suponemos cierres, descartamos destinos expuestos y agrupamos las derivaciones.
--
-- Son dos consultas independientes: seleccionar cada bloque WITH ... SELECT
-- completo en pgAdmin. No crean objetos ni necesitan las consultas de actividad 7.
-- geography mide en metros; numeric permite redondear a dos decimales.

-- CONSULTA 1. Un destino para cada centro que suponemos cerrado.
-- EXISTS pregunta si hay agua cerca sin repetir el centro por cada río o laguna.
-- Ordenamos los destinos por distancia y elegimos el primero con LIMIT 1.
-- Si empatan, gana el id menor. LEFT JOIN conserva el origen si no hay destino.
-- Resultado actual: 15 centros sin destino. geom guarda el punto de origen;
-- geom_derivacion sería la línea directa al destino (no una ruta), o NULL si falta.
WITH departamento AS (
    SELECT geom
    FROM capas.departamentos
    WHERE nam = 'Concordia'
), agua_referencia AS (
    SELECT r.geom
    FROM capas.rios AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
    WHERE r.waterway IN ('river', 'stream')
    UNION ALL
    SELECT l.geom
    FROM entrerios.lagunas AS l
    JOIN departamento AS d ON ST_Intersects(l.geom, d.geom)
), centros AS (
    SELECT s.id, coalesce(s.nombre, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM agua_referencia AS a
               WHERE ST_DWithin(s.geom::geography, a.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.atributos->>'amenity' IN ('hospital', 'clinic')
), derivaciones AS (
    SELECT origen.id, origen.nombre AS centro_origen,
           destino.id AS receptor_id, destino.nombre AS centro_receptor,
           ST_Distance(origen.geom::geography, destino.geom::geography) AS distancia_m,
           origen.geom AS geom_origen, destino.geom AS geom_destino
    FROM centros AS origen
    LEFT JOIN centros AS destino
      ON destino.id = (
          SELECT candidato.id
          FROM centros AS candidato
          WHERE NOT candidato.expuesto
          ORDER BY ST_Distance(origen.geom::geography, candidato.geom::geography),
                   candidato.id
          LIMIT 1
      )
    WHERE origen.expuesto
)
SELECT id, centro_origen, receptor_id, centro_receptor,
       round(distancia_m::numeric, 2) AS distancia_directa_m,
       (SELECT count(*) FROM centros WHERE NOT expuesto) AS receptores_disponibles,
       CASE WHEN receptor_id IS NULL THEN 'Sin receptor local fuera de la franja'
            ELSE 'Confirmar capacidad y acceso antes de derivar'
       END AS decision,
       geom_origen AS geom,
       ST_MakeLine(geom_origen, geom_destino) AS geom_derivacion
FROM derivaciones
ORDER BY distancia_m DESC NULLS FIRST, id;

-- CONSULTA 2. Contamos cuántos centros derivarían a cada destino. No es una
-- cantidad de pacientes ni de camas. Incluimos destinos que recibirían cero.
-- Repetimos los primeros pasos para ejecutar esta consulta por separado.
-- Hoy devuelve cero filas: no hay destinos fuera de la franja. No cambiamos
-- los 2 km para forzar una respuesta ni deducimos que exista una inundación real.
WITH departamento AS (
    SELECT geom
    FROM capas.departamentos
    WHERE nam = 'Concordia'
), agua_referencia AS (
    SELECT r.geom
    FROM capas.rios AS r
    JOIN departamento AS d ON ST_Intersects(r.geom, d.geom)
    WHERE r.waterway IN ('river', 'stream')
    UNION ALL
    SELECT l.geom
    FROM entrerios.lagunas AS l
    JOIN departamento AS d ON ST_Intersects(l.geom, d.geom)
), centros AS (
    SELECT s.id, coalesce(s.nombre, '(sin nombre)') AS nombre, s.geom,
           EXISTS (
               SELECT 1
               FROM agua_referencia AS a
               WHERE ST_DWithin(s.geom::geography, a.geom::geography, 2000)
           ) AS expuesto
    FROM entrerios.salud AS s
    JOIN departamento AS d ON ST_Intersects(s.geom, d.geom)
    WHERE s.atributos->>'amenity' IN ('hospital', 'clinic')
), derivaciones AS (
    SELECT origen.id, destino.id AS receptor_id,
           ST_Distance(origen.geom::geography, destino.geom::geography) AS distancia_m
    FROM centros AS origen
    LEFT JOIN centros AS destino
      ON destino.id = (
          SELECT candidato.id
          FROM centros AS candidato
          WHERE NOT candidato.expuesto
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
FROM centros AS receptor
LEFT JOIN derivaciones AS d ON d.receptor_id = receptor.id
WHERE NOT receptor.expuesto
GROUP BY receptor.id, receptor.nombre, receptor.geom
ORDER BY centros_a_derivar DESC, receptor.nombre;

-- QGIS: ejecutar la consulta 1 en DB Manager y cargarla usando id y geom.
-- Así se ven los 15 puntos aunque no haya destino. geom_derivacion permitiría
-- dibujar las líneas, pero hoy son NULL. La consulta 2 vacía no indica un error.
-- concordia.qgz usa vistas anteriores: estas consultas no las actualizan.
