-- Actividad 8. Rutas y accesibilidad sanitaria de Concordia.
-- Cada consulta es independiente. EPSG:5347 (POSGAR 2007, faja 5)
-- permite medir en metros; las geometrías de salida quedan en EPSG:4326.
-- Se mide la red registrada: dos calzadas distintas cuentan como dos líneas.

-- 8.1. Rutas identificadas por referencia o nombre, no por highway.
SELECT r.id, r.ref, r.name,
       coalesce(nullif(r.ref, ''), r.name) AS ruta,
       ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
FROM entrerios.rutas r
JOIN entrerios.departamentos d ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'Concordia'
  AND (r.ref ~ '^(RN|RP)' OR r.name ILIKE 'Ruta Nacional%'
       OR r.name ILIKE 'Ruta Provincial%')
ORDER BY ruta, r.id;

-- Control: estos tramos no tienen referencia/nombre suficiente para asignar
-- una ruta nacional o provincial. No se infiere su identidad por cercanía.
SELECT count(*) AS tramos_sin_identificacion_de_ruta
FROM entrerios.rutas r
JOIN entrerios.departamentos d ON ST_Intersects(r.geom, d.geom)
WHERE d.nam = 'Concordia'
  AND NOT (coalesce(r.ref, '') ~ '^(RN|RP)'
           OR coalesce(r.name, '') ILIKE 'Ruta Nacional%'
           OR coalesce(r.name, '') ILIKE 'Ruta Provincial%');

-- 8.2. Kilómetros de cada ruta dentro del departamento.
-- Se conserva la referencia completa si un tramo declara más de una ruta:
-- no se reparte ni se suma ese tramo de nuevo por cada referencia.
WITH tramos AS (
    SELECT coalesce(nullif(r.ref, ''), r.name) AS ruta,
           ST_CollectionExtract(ST_Intersection(r.geom, d.geom), 2) AS geom
    FROM entrerios.rutas r
    JOIN entrerios.departamentos d ON ST_Intersects(r.geom, d.geom)
    WHERE d.nam = 'Concordia'
      AND (r.ref ~ '^(RN|RP)' OR r.name ILIKE 'Ruta Nacional%'
           OR r.name ILIKE 'Ruta Provincial%')
)
SELECT ruta,
       round((sum(ST_Length(ST_Transform(geom, 5347))) / 1000)::numeric, 3) AS longitud_km,
       ST_Multi(ST_Collect(geom)) AS geom
FROM tramos
GROUP BY ruta
ORDER BY ruta;

-- 8.3. Hospitales y clínicas OSM dentro o sobre el borde departamental.
-- Se respeta amenity, incluso si el nombre sugiere otra especialidad.
-- Las etiquetas no prueban capacidad de atención, horarios ni disponibilidad.
SELECT s.id, coalesce(nullif(s.name, ''), 'Sin nombre') AS nombre,
       s.amenity AS categoria, s.geom
FROM entrerios.salud s
JOIN entrerios.departamentos d ON ST_Covers(d.geom, s.geom)
WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic')
ORDER BY categoria, nombre, s.id;

-- 8.4. Mayor de las distancias mínimas, conservando empates sin redondear.
-- Distancia directa al punto más próximo de la geometría del establecimiento,
-- no tiempo de viaje ni distancia por caminos. Solo centros departamentales:
-- podría existir atención más cercana fuera de Concordia.
-- Si no hay centros elegibles no se inventa una distancia: no hay ganador.
WITH localidades AS (
    SELECT l.id, l.name, l.geom
    FROM entrerios.localidades l
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, l.geom)
    WHERE d.nam = 'Concordia'
), centros AS (
    SELECT s.id, s.geom
    FROM entrerios.salud s
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, s.geom)
    WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic')
), distancias AS (
    SELECT l.id, l.name, l.geom,
           min(ST_Distance(ST_Transform(l.geom, 5347),
                           ST_Transform(s.geom, 5347))) AS distancia_m
    FROM localidades l
    LEFT JOIN centros s ON true
    GROUP BY l.id, l.name, l.geom
)
SELECT id, name AS localidad, round((distancia_m / 1000)::numeric, 3) AS distancia_km, geom
FROM distancias
WHERE distancia_m = (SELECT max(distancia_m) FROM distancias)
ORDER BY id;

-- 8.5.a. Áreas de influencia de 5000 m, recortadas a Concordia.
-- Los solapes se muestran como cobertura potencial, no como población atendida.
SELECT s.id, coalesce(nullif(s.name, ''), 'Sin nombre') AS nombre,
       ST_Intersection(d.geom,
           ST_Transform(ST_Buffer(ST_Transform(s.geom, 5347), 5000), 4326)) AS geom
FROM entrerios.salud s
JOIN entrerios.departamentos d ON ST_Covers(d.geom, s.geom)
WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic');

-- 8.5.b. Conteo por localidad, nunca por cantidad de buffers superpuestos.
-- ST_DWithin incluye el borde (5000 m exactos). Si no hay centros, todas quedan
-- fuera. La distancia decide la cobertura, no la discretización del buffer.
WITH centros AS (
    SELECT s.geom
    FROM entrerios.salud s
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, s.geom)
    WHERE d.nam = 'Concordia' AND s.amenity IN ('hospital', 'clinic')
), cobertura AS (
    SELECT l.id, l.name, l.geom,
           EXISTS (
               SELECT 1 FROM centros s
               WHERE ST_DWithin(ST_Transform(l.geom, 5347),
                                ST_Transform(s.geom, 5347), 5000)
           ) AS cubierta
    FROM entrerios.localidades l
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, l.geom)
    WHERE d.nam = 'Concordia'
)
SELECT id, name AS localidad,
       CASE WHEN cubierta THEN 'Cubierta' ELSE 'Fuera de cobertura' END AS cobertura,
       count(*) FILTER (WHERE NOT cubierta) OVER () AS total_fuera_de_cobertura,
       geom
FROM cobertura
ORDER BY cubierta, localidad;
