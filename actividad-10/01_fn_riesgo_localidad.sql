-- ============================================================================
-- ACTIVIDAD 10 - FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- Sub-actividad 10.1: Clasificación del riesgo de una localidad
--
-- Función: fn_riesgo_localidad(nombre_localidad)
-- Criterio:
--   - Alto:  distancia < 1 km (< 1000 m) a un río, arroyo o laguna.
--   - Medio: distancia entre 1 y 3 km [1000 m, 3000 m].
--   - Bajo:  distancia > 3 km (> 3000 m).
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Definición de la Función PL/pgSQL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION entrerios.fn_riesgo_localidad(p_nombre_localidad VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    v_loc_geom geometry;
    v_min_dist numeric;
    v_clasificacion varchar;
BEGIN
    -- 1. Buscar la geometría de la localidad (insensible a mayúsculas/minúsculas)
    SELECT geom INTO v_loc_geom
    FROM entrerios.localidades
    WHERE name ILIKE trim(p_nombre_localidad)
    LIMIT 1;

    -- Si la localidad no existe en la base de datos
    IF NOT FOUND OR v_loc_geom IS NULL THEN
        RETURN 'Localidad no encontrada';
    END IF;

    -- 2. Calcular la distancia mínima en metros hacia ríos o lagunas
    -- Se utiliza un filtro inicial en grados (0.1° ~ 11 km) para aprovechar
    -- el índice espacial GiST en 4326 y garantizar alta performance.
    WITH agua_cercana AS (
        SELECT ST_Transform(r.geom, 5343) AS geom_5343
        FROM entrerios.rios r
        WHERE ST_DWithin(r.geom, v_loc_geom, 0.1)
        UNION ALL
        SELECT ST_Transform(l.geom, 5343) AS geom_5343
        FROM entrerios.lagunas l
        WHERE ST_DWithin(l.geom, v_loc_geom, 0.1)
    )
    SELECT MIN(ST_Distance(ST_Transform(v_loc_geom, 5343), geom_5343))
    INTO v_min_dist
    FROM agua_cercana;

    -- Si no hay cursos de agua en un radio de 11 km, la distancia supera holgadamente los 3 km
    IF v_min_dist IS NULL THEN
        RETURN 'Bajo';
    END IF;

    -- 3. Clasificación según consigna
    IF v_min_dist < 1000.0 THEN
        v_clasificacion := 'Alto';
    ELSIF v_min_dist <= 3000.0 THEN
        v_clasificacion := 'Medio';
    ELSE
        v_clasificacion := 'Bajo';
    END IF;

    RETURN v_clasificacion;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION entrerios.fn_riesgo_localidad(VARCHAR) IS
'Devuelve la clasificación de riesgo hídrico (Alto, Medio, Bajo) según la distancia mínima de una localidad a ríos y lagunas (EPSG:5343).';

-- ----------------------------------------------------------------------------
-- 2. Función complementaria informativa (Devuelve clasificación y distancia exacta)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION entrerios.fn_riesgo_localidad_detalle(p_nombre_localidad VARCHAR)
RETURNS TABLE (
    localidad VARCHAR,
    distancia_minima_metros NUMERIC,
    nivel_riesgo VARCHAR
) AS $$
DECLARE
    v_loc_geom geometry;
    v_min_dist numeric;
BEGIN
    SELECT geom INTO v_loc_geom
    FROM entrerios.localidades
    WHERE name ILIKE trim(p_nombre_localidad)
    LIMIT 1;

    IF NOT FOUND OR v_loc_geom IS NULL THEN
        RETURN QUERY SELECT p_nombre_localidad, NULL::numeric, 'Localidad no encontrada'::varchar;
        RETURN;
    END IF;

    WITH agua_cercana AS (
        SELECT ST_Transform(r.geom, 5343) AS geom_5343
        FROM entrerios.rios r
        WHERE ST_DWithin(r.geom, v_loc_geom, 0.1)
        UNION ALL
        SELECT ST_Transform(l.geom, 5343) AS geom_5343
        FROM entrerios.lagunas l
        WHERE ST_DWithin(l.geom, v_loc_geom, 0.1)
    )
    SELECT MIN(ST_Distance(ST_Transform(v_loc_geom, 5343), geom_5343))
    INTO v_min_dist
    FROM agua_cercana;

    IF v_min_dist IS NULL THEN
        v_min_dist := 99999.0;
    END IF;

    RETURN QUERY 
    SELECT 
        p_nombre_localidad,
        ROUND(v_min_dist::numeric, 2),
        entrerios.fn_riesgo_localidad(p_nombre_localidad);
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- 3. Pruebas y Análisis con Localidades de Concordia y Alrededores
-- ----------------------------------------------------------------------------
-- Probar la función con diversas localidades reales
SELECT 
    loc.name AS localidad,
    entrerios.fn_riesgo_localidad(loc.name) AS riesgo_hidrico
FROM entrerios.localidades loc
JOIN entrerios.departamentos dep ON ST_Intersects(loc.geom, dep.geom)
WHERE dep.nam ILIKE 'Concordia'
ORDER BY loc.name;

-- Detalle métrico de prueba para validar distancias
SELECT d.*
FROM entrerios.localidades loc
JOIN entrerios.departamentos dep ON ST_Intersects(loc.geom, dep.geom)
CROSS JOIN LATERAL entrerios.fn_riesgo_localidad_detalle(loc.name) d
WHERE dep.nam ILIKE 'Concordia'
ORDER BY d.distancia_minima_metros ASC;
