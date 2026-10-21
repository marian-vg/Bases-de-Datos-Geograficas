-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.3. Búsqueda del hospital más cercano (fn_hospital_cercano)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Permite calcular la distancia euclidiana exacta en metros entre la persona y el efector de salud.
-- Justificación Funciones: ST_MakePoint construye el punto geográfico y el operador <-> acelera la vecindad más próxima mediante el índice GiST.
-- ============================================================================

SET search_path TO entrerios, public;

-- Función parametrizada que simula el despacho de asistencia ante una emergencia
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
    IF p_lat IS NULL OR p_lon IS NULL THEN
        RAISE EXCEPTION 'Latitud y longitud son obligatorias.';
    END IF;

    -- Longitud = eje X, Latitud = eje Y en PostGIS
    v_punto_4326 := ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326);
    v_punto_5343 := ST_Transform(v_punto_4326, 5343);

    RETURN QUERY
    WITH candidatos AS (
        SELECT 
            COALESCE(s.name, 'Establecimiento sin nombre formal') AS nombre,
            COALESCE(s.amenity, s.healthcare, 'Centro de Atención')::varchar AS tipo,
            ST_Transform(s.geom, 5343) AS geom_5343
        FROM entrerios.salud s
        ORDER BY s.geom <-> v_punto_4326
        LIMIT 10
    )
    SELECT 
        c.nombre::varchar,
        ROUND((ST_Distance(c.geom_5343, v_punto_5343))::numeric, 2),
        ROUND((ST_Distance(c.geom_5343, v_punto_5343) / 1000.0)::numeric, 3),
        c.tipo
    FROM candidatos c
    ORDER BY ST_Distance(c.geom_5343, v_punto_5343) ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION entrerios.fn_hospital_cercano(DOUBLE PRECISION, DOUBLE PRECISION) IS
'Retorna el hospital más cercano y la distancia métrica a partir de una posición geográfica (latitud, longitud).';

-- Simulaciones de emergencias reales en el Departamento Concordia
SELECT 'Plaza 25 de Mayo (Centro)' AS escenario, h.* FROM entrerios.fn_hospital_cercano(-31.3929, -58.0209) h
UNION ALL
SELECT 'Zona Norte (Villa Zorraquín)' AS escenario, h.* FROM entrerios.fn_hospital_cercano(-31.3250, -57.9950) h
UNION ALL
SELECT 'Acceso Autovía RN14 y RP22' AS escenario, h.* FROM entrerios.fn_hospital_cercano(-31.4280, -58.1150) h;

-- Interpretación: Automatiza la derivación hospitalaria inmediata de accidentados o pacientes críticos al centro asistencial con menor tiempo de acceso.
