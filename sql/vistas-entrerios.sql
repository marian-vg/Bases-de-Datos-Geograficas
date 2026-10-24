-- Vistas de compatibilidad: exponen capas.* en entrerios.* con el formato que
-- usan los scripts del repo (id, nombre, atributos JSONB, geom) y además
-- conservan todas las columnas originales (nam, highway, waterway, ipc, ...).
-- Las vistas son "simples": PostgreSQL las expande en la consulta, por lo que
-- se aprovechan los índices GiST de las tablas de capas.
-- Si en entrerios ya existe una TABLA con el mismo nombre, no se toca.
-- Uso: docker compose exec -T postgres psql -U postgres -d bdg_entrerios < sql/vistas-entrerios.sql
DO $$
DECLARE
  r record;
  extra text;
  attrs text;
  sql_vista text;
  kind "char";
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('departamentos', 'departamentos', 'nam'),
      ('localidades',   'ciudades',      'name'),
      ('rutas',         'rutas',         'name'),
      ('rios',          'rios',          'name'),
      ('calles',        'calles',        'name'),
      ('suelo',         'suelo',         'nombre'),
      ('salud',         'salud',         'name'),
      ('lagunas',       'lagunas',       'name')
    ) AS v(vista, tabla, col_nombre)
  LOOP
    IF to_regclass(format('capas.%I', r.tabla)) IS NULL THEN
      RAISE NOTICE 'capas.% no existe: se omite entrerios.%', r.tabla, r.vista;
      CONTINUE;
    END IF;

    SELECT c.relkind INTO kind
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'entrerios' AND c.relname = r.vista;
    IF kind IS NOT NULL AND kind <> 'v' THEN
      RAISE NOTICE 'entrerios.% ya existe como tabla: no se reemplaza', r.vista;
      CONTINUE;
    END IF;

    -- Columnas originales (sin las que la vista ya define).
    SELECT string_agg(format('t.%I', column_name), ', ' ORDER BY ordinal_position)
    INTO extra
    FROM information_schema.columns
    WHERE table_schema = 'capas' AND table_name = r.tabla
      AND column_name NOT IN ('fid', 'geom', 'id', 'nombre', 'atributos');

    -- atributos: todas las columnas como JSONB; si hay other_tags (OSM en JSON),
    -- se aplanan para poder consultar atributos->>'amenity', ->>'water', etc.
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'capas' AND table_name = r.tabla
                 AND column_name = 'other_tags') THEN
      attrs := 'jsonb_strip_nulls(COALESCE(NULLIF(t.other_tags::text, '''')::jsonb, ''{}''::jsonb)'
               || ' || (to_jsonb(t) - ''geom'' - ''fid'' - ''other_tags''))';
    ELSE
      attrs := 'jsonb_strip_nulls(to_jsonb(t) - ''geom'' - ''fid'')';
    END IF;

    sql_vista := format(
      'CREATE OR REPLACE VIEW entrerios.%I AS SELECT t.fid AS id, t.%I::text AS nombre, %s AS atributos, t.geom%s FROM capas.%I t',
      r.vista, r.col_nombre, attrs,
      CASE WHEN extra IS NULL THEN '' ELSE ', ' || extra END,
      r.tabla);
    BEGIN
      EXECUTE sql_vista;
    EXCEPTION WHEN invalid_table_definition OR feature_not_supported OR datatype_mismatch THEN
      -- Cambiaron las columnas: recrear (falla si otras vistas dependen de ésta).
      EXECUTE format('DROP VIEW entrerios.%I', r.vista);
      EXECUTE sql_vista;
    END;
    EXECUTE format('COMMENT ON VIEW entrerios.%I IS %L', r.vista,
      format('Vista de compatibilidad sobre capas.%s (id, nombre, atributos, geom + columnas originales)', r.tabla));
    RAISE NOTICE 'entrerios.% -> capas.%', r.vista, r.tabla;
  END LOOP;
END $$;
