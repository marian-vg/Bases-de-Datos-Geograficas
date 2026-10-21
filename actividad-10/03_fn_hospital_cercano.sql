-- ============================================================================
-- ACTIVIDAD 10 - FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- Sub-actividad 10.3: Búsqueda del hospital más cercano
--
-- Función parametrizada: fn_hospital_cercano(lat, lon)
-- Simulación: Solicitud de asistencia de emergencia indicando posición.
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Definición de la Función PL/pgSQL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION entrerios.fn_hospital_cercano(
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION
)
RETURNS TABLE (
    nombre_establecimiento VARCHAR,
    distancia_metros NUMERIC,
    distancia_km NUMERIC,
    tipo_establecimiento VARCHAR
) AS $$
DECLARE
    v_punto_4326 geometry;
    v_punto_5343 geometry;
BEGIN
    -- 1. Validación de coherencia de coordenadas
    IF p_lat IS NULL OR p_lon IS NULL THEN
        RAISE EXCEPTION 'Parámetros inválidos: latitud y longitud no pueden ser nulos.';
    END IF;

    IF p_lat < -90.0 OR p_lat > 90.0 OR p_lon < -180.0 OR p_lon > 180.0 THEN
        RAISE EXCEPTION 'Coordenadas fuera de rango válido: Lat [%] debe pertenecer a [-90, 90] y Lon [%] a [-180, 180].', p_lat, p_lon;
    END IF;

    -- 2. Construcción del punto espacial (Longitud = X, Latitud = Y en PostGIS)
    v_punto_4326 := ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326);
    v_punto_5343 := ST_Transform(v_punto_4326, 5343);

    -- 3. Búsqueda optimizada del efector de salud más cercano
    -- Usamos pre-filtro de los 10 más cercanos por índice GiST (<->) y refinamos la distancia euclidiana en EPSG:5343
    RETURN QUERY
    WITH candidatos AS (
        SELECT 
            s.id,
            COALESCE(s.name, 'Establecimiento sin nombre formal') AS nombre,
            COALESCE(s.amenity, s.healthcare, 'Centro de Atención')::varchar AS tipo,
            ST_Transform(s.geom, 5343) AS geom_5343
        FROM entrerios.salud s
        ORDER BY s.geom <-> v_punto_4326
        LIMIT 10
    )
    SELECT 
        c.nombre::varchar AS nombre_establecimiento,
        ROUND((ST_Distance(c.geom_5343, v_punto_5343))::numeric, 2) AS distancia_metros,
        ROUND((ST_Distance(c.geom_5343, v_punto_5343) / 1000.0)::numeric, 3) AS distancia_km,
        c.tipo AS tipo_establecimiento
    FROM candidatos c
    ORDER BY ST_Distance(c.geom_5343, v_punto_5343) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION entrerios.fn_hospital_cercano(DOUBLE PRECISION, DOUBLE PRECISION) IS
'Devuelve el efector de salud más cercano y la distancia métrica a partir de una coordenada geográfica (latitud, longitud).';

-- ----------------------------------------------------------------------------
-- 2. Simulación de Casos de Emergencia en Concordia
-- ----------------------------------------------------------------------------

-- Caso 1: Persona solicita asistencia en la Plaza 25 de Mayo (Centro de Concordia)
-- Lat: -31.3929, Lon: -58.0209
SELECT 
    'Caso 1 - Centro de Concordia (Plaza 25 de Mayo)' AS escenario,
    h.*
FROM entrerios.fn_hospital_cercano(-31.3929, -58.0209) h;

-- Caso 2: Emergencia en el norte del ejido urbano (Villa Zorraquín)
-- Lat: -31.3250, Lon: -57.9950
SELECT 
    'Caso 2 - Villa Zorraquín' AS escenario,
    h.*
FROM entrerios.fn_hospital_cercano(-31.3250, -57.9950) h;

-- Caso 3: Persona accidentada en Ruta Nacional 14 (cruce con RP22)
-- Lat: -31.4280, Lon: -58.1150
SELECT 
    'Caso 3 - Cruce RN14 y RP22' AS escenario,
    h.*
FROM entrerios.fn_hospital_cercano(-31.4280, -58.1150) h;
