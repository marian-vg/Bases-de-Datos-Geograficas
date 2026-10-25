-- Actividad 11. Calles OSM y Argenmap: departamento Concordia.
-- Consultas independientes sobre la única red entrerios.calles.
-- EPSG:5347 (POSGAR 2007, faja 5) da longitudes en m y superficies en m².
-- Se recorta antes de sumar. Las calzadas distintas cuentan como líneas distintas.

-- 11.1. Longitud por departamento y promedio aritmético de los 17, incluido
-- Concordia. Una línea sobre un límite puede contribuir a ambos departamentos.
-- Se mide lo registrado en la fuente, no la totalidad real de caminos.
-- Requiere la carga provincial de calles, no solo el GeoJSON de Concordia.
WITH longitudes AS (
    SELECT d.id, d.nam AS departamento,
           coalesce(sum(ST_Length(ST_Transform(
               ST_Intersection(c.geom, d.geom), 5347))), 0) / 1000 AS longitud_km
    FROM entrerios.departamentos d
    LEFT JOIN entrerios.calles c ON ST_Intersects(c.geom, d.geom)
    GROUP BY d.id, d.nam
)
SELECT departamento, departamento = 'Concordia' AS elegido,
       round(longitud_km::numeric, 3) AS longitud_km,
       round((avg(longitud_km) OVER ())::numeric, 3) AS promedio_departamental_km,
       count(*) OVER () AS departamentos_comparados
FROM longitudes
ORDER BY longitud_km DESC, departamento;

-- 11.2. INTA aproxima la superficie de las localidades con sus áreas urbanas.
-- Ranking solo de áreas identificadas en esa fuente, no de las 14 localidades
-- sin excepciones. Se unen las partes homónimas (Concordia tiene siete).
-- Correspondencias verificadas por nombre y ubicación, no por contención sola:
-- Calabacillas = Calabacilla, Colonia Ayui = Colonia Ayuí, Yeruá = Estación Yeruá.
-- Benito Legerén y Pedernal tienen puntos levemente fuera de su área homónima.
-- Villa Adela y Las Tejas están en el área Concordia pero sin área propia:
-- no se les asigna esa superficie ni una densidad cero. Igual para Estancia
-- Grande, sin correspondencia. Otras áreas INTA sin localidad OSM no se agregan.
WITH correspondencias (id_localidad, nombre_inta) AS (
    VALUES ('node/198398866', 'Los Charrúas'),
           ('node/198406805', 'Nueva Escocia'),
           ('node/198407866', 'Osvaldo Magnasco'),
           ('node/198409950', 'Pedernal'),
           ('node/198414475', 'Puerto Yeruá'),
           ('node/198437144', 'Estación Yeruá'),
           ('node/198441415', 'Calabacilla'),
           ('node/198445828', 'Concordia'),
           ('node/198455000', 'La Criolla'),
           ('node/1047062966', 'Benito Legerén'),
           ('node/1049278452', 'Colonia Ayuí')
), areas AS (
    SELECT s.nombre, ST_Union(ST_Intersection(s.geom, d.geom)) AS geom
    FROM entrerios.suelo s
    JOIN entrerios.departamentos d ON ST_Intersects(s.geom, d.geom)
    WHERE d.nam = 'Concordia' AND s.simb = 'AU'
    GROUP BY s.nombre
), mediciones AS (
    SELECT l.id, l.name AS localidad, a.nombre AS area_inta, a.geom,
           ST_Area(ST_Transform(a.geom, 5347)) / 1000000 AS superficie_km2,
           coalesce(sum(ST_Length(ST_Transform(
               ST_Intersection(c.geom, a.geom), 5347))), 0) / 1000 AS longitud_km
    FROM entrerios.localidades l
    JOIN entrerios.departamentos d ON ST_Covers(d.geom, l.geom)
    LEFT JOIN correspondencias m ON m.id_localidad = l.id
    LEFT JOIN areas a ON a.nombre = m.nombre_inta
    LEFT JOIN entrerios.calles c ON ST_Intersects(c.geom, a.geom)
    WHERE d.nam = 'Concordia'
    GROUP BY l.id, l.name, a.nombre, a.geom
)
SELECT id, localidad, area_inta,
       CASE WHEN superficie_km2 > 0 THEN 'Evaluada'
            ELSE 'Sin área identificada' END AS estado,
       round(superficie_km2::numeric, 4) AS superficie_km2,
       CASE WHEN superficie_km2 > 0 THEN round(longitud_km::numeric, 3) END AS longitud_km,
       round((longitud_km / nullif(superficie_km2, 0))::numeric, 3) AS densidad_km_por_km2,
       geom
FROM mediciones
ORDER BY longitud_km / nullif(superficie_km2, 0) DESC NULLS LAST, localidad;

-- 11.3.a. Solo categorías registradas, sin inferir etiquetas ausentes.
-- La lista permite mostrar cero si no hay tramos de una categoría.
WITH categorias (highway) AS (VALUES ('primary'), ('secondary')),
tramos AS (
    SELECT c.highway, ST_Intersection(c.geom, d.geom) AS geom
    FROM entrerios.calles c
    JOIN entrerios.departamentos d ON ST_Intersects(c.geom, d.geom)
    WHERE d.nam = 'Concordia' AND c.highway IN ('primary', 'secondary')
)
SELECT t.highway,
       round((coalesce(sum(ST_Length(ST_Transform(c.geom, 5347))), 0) / 1000)::numeric, 3) AS longitud_km
FROM categorias t
LEFT JOIN tramos c ON c.highway = t.highway
GROUP BY t.highway
ORDER BY t.highway;

-- 11.3.b. Faltantes locales: NULL no excluye una calle de 11.1 ni 11.2.
SELECT count(*) AS tramos_departamento,
       count(*) FILTER (WHERE nullif(c.highway, '') IS NULL) AS tramos_sin_highway,
       round((coalesce(sum(ST_Length(ST_Transform(ST_Intersection(c.geom, d.geom), 5347)))
           FILTER (WHERE nullif(c.highway, '') IS NULL), 0) / 1000)::numeric, 3) AS km_sin_highway
FROM entrerios.calles c
JOIN entrerios.departamentos d ON ST_Intersects(c.geom, d.geom)
WHERE d.nam = 'Concordia';

-- 11.4. Capa de calles recortada para comparar en QGIS con Argenmap.
-- El renderizador propio genera evidencia urbana, rural y de un cruce hídrico.
-- Argenmap es un servicio externo de visualización, no se importa a PostGIS.
SELECT c.id, c.name, c.highway, c.bridge,
       ST_CollectionExtract(ST_Intersection(c.geom, d.geom), 2) AS geom
FROM entrerios.calles c
JOIN entrerios.departamentos d ON ST_Intersects(c.geom, d.geom)
WHERE d.nam = 'Concordia';
