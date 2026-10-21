-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.1. Clasificación del riesgo de una localidad (fn_riesgo_localidad)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Proporciona unidades métricas uniformes para categorizar los umbrales de 1 km y 3 km.
-- Justificación Funciones: ST_Distance computa la cercanía mínima al agua y ST_DWithin pre-filtra por índice GiST para optimizar la respuesta.
-- ============================================================================

SET search_path TO entrerios, public;

-- Función de clasificación de riesgo hídrico según distancia al agua
CREATE OR REPLACE FUNCTION entrerios.fn_riesgo_localidad(p_nombre_localidad TEXT)
RETURNS TEXT AS $$
DECLARE
    v_loc_geom geometry;
    v_min_dist numeric;
BEGIN
    -- 1. Obtener la geometría de la localidad
    SELECT geom INTO v_loc_geom
    FROM entrerios.localidades
    WHERE name ILIKE trim(p_nombre_localidad)
    LIMIT 1;

    IF NOT FOUND OR v_loc_geom IS NULL THEN
        RETURN 'Localidad no encontrada';
    END IF;

    -- 2. Distancia mínima en metros hacia ríos o lagunas (filtro GiST de 0.1° para rendimiento)
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

    -- 3. Clasificación según consigna
    IF v_min_dist IS NULL OR v_min_dist > 3000.0 THEN
        RETURN 'Bajo';
    ELSIF v_min_dist < 1000.0 THEN
        RETURN 'Alto';
    ELSE
        RETURN 'Medio';
    END IF;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION entrerios.fn_riesgo_localidad(TEXT) IS 
'Clasifica el riesgo de una localidad: Alto (< 1 km), Medio (1-3 km) o Bajo (> 3 km) respecto a ríos y lagunas.';

-- Casos de prueba en el Departamento Concordia
SELECT 
    loc.name AS localidad,
    loc.place AS categoria,
    entrerios.fn_riesgo_localidad(loc.name) AS nivel_riesgo
FROM entrerios.localidades loc
JOIN entrerios.departamentos dep ON ST_Intersects(loc.geom, dep.geom)
WHERE dep.nam ILIKE 'Concordia'
ORDER BY loc.name;

-- Interpretación: Automatiza la evaluación de vulnerabilidad de cualquier asentamiento urbano frente a crecidas de ríos o desbordes de lagunas.
