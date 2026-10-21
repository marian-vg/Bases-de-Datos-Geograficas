-- Source layers remain untouched in fuentes; canonical tables are created only once.
BEGIN;
CREATE TABLE IF NOT EXISTS entrerios.departamentos AS
SELECT fid AS id, coalesce(to_jsonb(f)->>'nam',to_jsonb(f)->>'name') AS nombre,
       to_jsonb(f)-'geom' AS atributos,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(geom),3))::geometry(MultiPolygon,4326) AS geom
FROM fuentes.departamentos f;
CREATE TABLE IF NOT EXISTS entrerios.localidades AS
SELECT fid AS id, to_jsonb(f)->>'name' AS nombre, to_jsonb(f)-'geom' AS atributos,
       ST_PointOnSurface(ST_MakeValid(geom))::geometry(Point,4326) AS geom
FROM fuentes.localidades f;
CREATE TABLE IF NOT EXISTS entrerios.rutas AS
SELECT fid AS id, to_jsonb(f)->>'name' AS nombre, to_jsonb(f)-'geom' AS atributos,
       geom::geometry(LineString,4326) AS geom FROM fuentes.rutas f;
CREATE TABLE IF NOT EXISTS entrerios.rios AS
SELECT fid AS id, to_jsonb(f)->>'name' AS nombre, to_jsonb(f)-'geom' AS atributos,
       geom::geometry(LineString,4326) AS geom FROM fuentes.rios f;
CREATE TABLE IF NOT EXISTS entrerios.lagunas AS
SELECT fid AS id, to_jsonb(f)->>'name' AS nombre, to_jsonb(f)-'geom' AS atributos,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(geom),3))::geometry(MultiPolygon,4326) AS geom
FROM fuentes.lagunas f WHERE ST_Dimension(geom)=2;
CREATE TABLE IF NOT EXISTS entrerios.salud AS
SELECT fid AS id, to_jsonb(f)->>'name' AS nombre, to_jsonb(f)-'geom' AS atributos,
       geom::geometry(Point,4326) AS geom FROM fuentes.salud f;
CREATE TABLE IF NOT EXISTS entrerios.suelo AS
SELECT fid AS id, to_jsonb(f)->>'nombre' AS nombre, to_jsonb(f)-'geom' AS atributos,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(geom),3))::geometry(MultiPolygon,4326) AS geom
FROM fuentes.suelo f;
-- No street dataset is supplied: keep the required table explicitly empty.
CREATE TABLE IF NOT EXISTS entrerios.calles (
  id bigint PRIMARY KEY, nombre text, atributos jsonb, geom geometry(LineString,4326)
);
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['departamentos','localidades','rutas','rios','lagunas','salud','suelo','calles'] LOOP
    EXECUTE format('CREATE UNIQUE INDEX IF NOT EXISTS %I ON entrerios.%I (id)',t||'_id_idx',t);
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON entrerios.%I USING gist (geom)',t||'_geom_idx',t);
    EXECUTE format('ANALYZE entrerios.%I',t);
  END LOOP;
END $$;
COMMIT;
