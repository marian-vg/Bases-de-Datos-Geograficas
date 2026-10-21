-- Actividad 13. Plan de derivación sanitaria por cierre preventivo durante
-- una emergencia hídrica en Concordia.
--
-- Problema: si los hospitales y clínicas a 2 km o menos del agua se consideran
-- temporalmente no disponibles, ¿qué centros fuera de esa franja recibirían
-- sus derivaciones y cuántos centros dependerían de cada receptor?
-- Capas: departamento (IGN), salud, ríos/arroyos y cuerpos de agua (OSM).
-- Preparación: ./chipa-actividades/importar-capas-profe.sh
-- Límites y ríos/arroyos: fuentes_profe (IGN/OSM entregados por el profesor).
-- Salud y lagunas: exports OSM anteriores en entrerios; no hay una nueva capa
-- sanitaria entre las del profesor. Hay 14 ciudades entregadas dentro de
-- Concordia, pero no son necesarias para esta pregunta institucional.
--
-- Supuestos: franja ACADÉMICA de 2 km, no inundación observada ni mapa oficial.
-- Se usan cursos/cuerpos que intersectan Concordia, conservando su geometría
-- completa para no cortar artificialmente la cercanía en el borde.
-- Los receptores deben estar en Concordia y a más de 2 km de esas fuentes.
-- Distancia geodésica directa, NO recorrido vial ni garantía de acceso.
-- No hay datos de camas, pacientes, especialidades ni operatividad real.
--
-- Decisión académica: coordinar los receptores que concentran más centros.
-- Si no hay receptores, señalar que el modelo no permite una derivación local
-- y estudiar apoyo externo/centro de campaña. Antes de una decisión real hay
-- que verificar inundación, operatividad, capacidad y accesos en terreno.
-- Se diferencia de 10.3: simula indisponibilidad, excluye centros expuestos y
-- AGREGA la dependencia institucional por receptor; no busca solo cercanía.
-- Referencia de unidades: https://postgis.net/docs/ST_DWithin.html
-- Ejecutar completo; no requiere actividad-7.sql ni modifica las fuentes.

BEGIN;
CREATE SCHEMA IF NOT EXISTS chipa_actividades;

-- 1. Fuentes de exposición relevantes para el departamento.
CREATE OR REPLACE VIEW chipa_actividades.a13_agua_referencia AS
SELECT 'rio_' || r.fid AS id, r.geom
FROM fuentes_profe.rios AS r
JOIN fuentes_profe.departamentos AS d ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'Concordia'
  AND r.waterway IN ('river', 'stream')
UNION ALL
SELECT 'laguna_' || l.id AS id, l.geom
FROM entrerios.lagunas AS l
JOIN fuentes_profe.departamentos AS d ON ST_Intersects(l.geom, d.geom)
WHERE d.nam = 'Concordia';

-- 2. Clasificar cada hospital/clínica; EXISTS evita duplicar un centro cuando
-- está cerca de varias fuentes de agua. geography expresa el umbral en metros.
CREATE OR REPLACE VIEW chipa_actividades.a13_centros AS
SELECT s.id,
       coalesce(s.nombre, '(sin nombre)') AS nombre,
       EXISTS (
           SELECT 1
           FROM chipa_actividades.a13_agua_referencia AS a
           WHERE ST_DWithin(s.geom::geography, a.geom::geography, 2000)
       ) AS expuesto,
       s.geom
FROM entrerios.salud AS s
JOIN fuentes_profe.departamentos AS d ON ST_Intersects(s.geom, d.geom)
WHERE d.nam = 'Concordia'
  AND s.atributos->>'amenity' IN ('hospital', 'clinic');

-- 3. Comparar centros expuestos con receptores no expuestos. ROW_NUMBER elige
-- el más cercano; el id resuelve empates de manera reproducible.
-- LEFT JOIN conserva el origen si no hay ningún receptor disponible.
CREATE OR REPLACE VIEW chipa_actividades.a13_derivaciones AS
WITH alternativas AS (
    SELECT origen.id AS id,
           origen.nombre AS centro_origen,
           destino.id AS receptor_id,
           destino.nombre AS centro_receptor,
           ST_Distance(origen.geom::geography, destino.geom::geography) AS distancia_m,
           origen.geom AS geom_origen,
           destino.geom AS geom_destino,
           row_number() OVER (
               PARTITION BY origen.id
               ORDER BY ST_Distance(origen.geom::geography, destino.geom::geography),
                        destino.id
           ) AS orden
    FROM chipa_actividades.a13_centros AS origen
    LEFT JOIN chipa_actividades.a13_centros AS destino ON NOT destino.expuesto
    WHERE origen.expuesto
)
SELECT id, centro_origen, receptor_id, centro_receptor,
       round(distancia_m::numeric, 2) AS distancia_directa_m,
       CASE WHEN receptor_id IS NULL THEN 'Sin receptor fuera de riesgo'
            ELSE 'Confirmar capacidad y acceso antes de derivar'
       END AS decision,
       ST_MakeLine(geom_origen, geom_destino)::geometry(LineString, 4326) AS geom
FROM alternativas
WHERE orden = 1;

-- 4. Resultado agregado para coordinar receptores: número de centros, NO
-- pacientes ni camas. También aparecen receptores con cero derivaciones.
CREATE OR REPLACE VIEW chipa_actividades.a13_receptores AS
SELECT receptor.id,
       receptor.nombre,
       count(d.id) AS centros_a_derivar,
       round(max(d.distancia_directa_m) / 1000.0, 2) AS mayor_distancia_km,
       receptor.geom
FROM chipa_actividades.a13_centros AS receptor
LEFT JOIN chipa_actividades.a13_derivaciones AS d ON d.receptor_id = receptor.id
WHERE NOT receptor.expuesto
GROUP BY receptor.id, receptor.nombre, receptor.geom;
COMMIT;

SELECT count(*) AS centros_evaluados,
       count(*) FILTER (WHERE expuesto) AS cierres_hipoteticos,
       count(*) FILTER (WHERE NOT expuesto) AS receptores_fuera_de_franja
FROM chipa_actividades.a13_centros;
SELECT CASE WHEN count(*) = 0
            THEN 'Sin receptores locales bajo el criterio académico; evaluar apoyo externo'
            ELSE 'Hay receptores candidatos; confirmar capacidad y acceso'
       END AS conclusion_del_modelo
FROM chipa_actividades.a13_receptores;
SELECT id, centro_origen, centro_receptor, distancia_directa_m, decision
FROM chipa_actividades.a13_derivaciones
ORDER BY distancia_directa_m DESC NULLS FIRST;
SELECT id, nombre, centros_a_derivar, mayor_distancia_km
FROM chipa_actividades.a13_receptores
ORDER BY centros_a_derivar DESC, nombre;

-- QGIS: agregar fuentes_profe.departamentos y las vistas a13_centros (puntos),
-- a13_derivaciones (líneas directas, no rutas) y a13_receptores (puntos).
-- Clave única: id. Geometría: geom. CRS: EPSG:4326.
-- Categorizar a13_centros por expuesto; graduar receptores por centros_a_derivar.
-- Sin receptor, la derivación queda en la tabla con geometría NULL: consultar
-- esos casos antes de interpretar el mapa. Cero cierres tampoco prueba seguridad.
-- Proyecto listo: abrir chipa-actividades/concordia.qgz tras ejecutar ambos SQL.
-- Usa PostgreSQL local, sin contraseña guardada: ingresar la de .env al conectar.
-- El mapa muestra Concordia, los cursos entregados y los centros evaluados.
-- La clasificación es un supuesto académico, no una emergencia observada.
