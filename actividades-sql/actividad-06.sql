-- Actividad 6. Construcción de la base de datos espacial: controles de carga.
-- Se ejecuta después de crear el modelo (01 y 02) y cargar shapes/.
-- Revisa, por tabla: tipo de geometría, SRID, cantidad de registros,
-- geometrías nulas y geometrías inválidas. Luego corrige las inválidas.
-- Se puede ejecutar más de una vez: si no hay nada para corregir, no cambia nada.

-- 6.1. Versión de PostGIS instalada.
SELECT postgis_full_version();

-- 6.2. Tipo de geometría y SRID declarados en cada tabla del esquema entrerios.
SELECT f_table_name AS tabla, type AS tipo_geometria, srid
FROM geometry_columns
WHERE f_table_schema = 'entrerios'
ORDER BY f_table_name;

-- 6.3. Registros, geometrías nulas e inválidas por tabla.
-- ST_IsValid detecta, por ejemplo, polígonos que se cortan a sí mismos.
SELECT 'departamentos' AS tabla, count(*) AS registros,
       count(*) FILTER (WHERE geom IS NULL) AS nulas,
       count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalidas
FROM entrerios.departamentos
UNION ALL
SELECT 'localidades', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.localidades
UNION ALL
SELECT 'rutas', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.rutas
UNION ALL
SELECT 'rios', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.rios
UNION ALL
SELECT 'lagunas', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.lagunas
UNION ALL
SELECT 'calles', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.calles
UNION ALL
SELECT 'salud', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.salud
UNION ALL
SELECT 'suelo', count(*), count(*) FILTER (WHERE geom IS NULL),
       count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.suelo;

-- 6.4. Corrección de geometrías inválidas con ST_MakeValid.
-- ST_MakeValid puede devolver una colección con partes de distinto tipo;
-- ST_CollectionExtract(..., 3) se queda solo con los polígonos y ST_Multi
-- los deja como MultiPolygon, que es el tipo que exige la tabla.
-- Con los datos actuales se corrigen 2 lagunas y 7 polígonos de suelo.
UPDATE entrerios.lagunas
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_IsValid(geom);

UPDATE entrerios.suelo
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_IsValid(geom);

UPDATE entrerios.departamentos
SET geom = ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
WHERE NOT ST_IsValid(geom);

-- 6.5. Control posterior: después de corregir no debe quedar ninguna inválida.
SELECT 'lagunas' AS tabla, count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalidas
FROM entrerios.lagunas
UNION ALL
SELECT 'suelo', count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.suelo
UNION ALL
SELECT 'departamentos', count(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM entrerios.departamentos;

-- 6.6. Ejemplo de consulta espacial real: superficie de Concordia en km²
-- (geography mide sobre el elipsoide) y establecimientos de salud que contiene.
SELECT d.nam AS departamento,
       round((ST_Area(d.geom::geography) / 1000000)::numeric, 2) AS superficie_km2,
       count(s.id) AS establecimientos_salud
FROM entrerios.departamentos AS d
LEFT JOIN entrerios.salud AS s ON ST_Intersects(d.geom, s.geom)
WHERE d.nam = 'Concordia'
GROUP BY d.id, d.nam, d.geom;
