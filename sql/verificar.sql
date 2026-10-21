SELECT postgis_full_version();
SELECT f_table_schema, f_table_name, type, srid FROM geometry_columns
WHERE f_table_schema='entrerios' ORDER BY f_table_name;
SELECT format(
  'SELECT %L AS tabla, count(*) AS registros, count(*) FILTER (WHERE geom IS NULL) AS nulas, count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalidas, array_agg(DISTINCT ST_SRID(geom)) AS srids FROM entrerios.%I;',
  f_table_name,f_table_name)
FROM geometry_columns WHERE f_table_schema='entrerios' ORDER BY f_table_name
\gexec
-- Real spatial query: metric area and health facilities intersecting the supplied department.
SELECT d.nombre, round((ST_Area(d.geom::geography)/1e6)::numeric,2) AS superficie_km2,
       count(s.id) AS establecimientos_salud
FROM entrerios.departamentos d LEFT JOIN entrerios.salud s ON ST_Intersects(d.geom,s.geom)
GROUP BY d.id,d.nombre,d.geom;
-- Line features excluded from the polygon working layer remain in fuentes.lagunas.
SELECT ST_GeometryType(geom) AS tipo_original, count(*) FROM fuentes.lagunas GROUP BY 1;
