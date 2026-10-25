-- ============================================================================
-- SCRIPT DE VALIDACIÓN E INTEGRIDAD: ACTIVIDAD 11
-- Autor: Grigolato
-- Verificación automática de vistas y cálculos espaciales mediante bloque DO $$
-- ============================================================================

SET search_path TO entrerios, capas, public;

DO $$
DECLARE
    v_deptos_count integer;
    v_concordia_calles_km numeric;
    v_densidad_loc_count integer;
    v_primary_count integer;
    v_calles_concordia_count integer;
    v_cruces_count integer;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'INICIANDO PRUEBAS DE INTEGRIDAD - ACTIVIDAD 11';
    RAISE NOTICE '=====================================================';

    -- Test 11.1: Longitud de calles y departamentos
    SELECT COUNT(*), COALESCE(SUM(longitud_km), 0)
    INTO v_calles_concordia_count, v_concordia_calles_km
    FROM (
        SELECT (ST_Length(ST_Transform(c.geom, 5343)) / 1000.0) AS longitud_km
        FROM capas.calles c
        JOIN capas.departamentos d ON ST_Intersects(c.geom, d.geom)
        WHERE d.nam ILIKE 'Concordia'
    ) sub;

    IF v_calles_concordia_count = 0 THEN
        RAISE EXCEPTION 'TEST 11.1 FALLIDO: No se encontraron tramos de calles para Concordia.';
    END IF;

    RAISE NOTICE 'TEST 11.1 OK: Concordia posee % tramos de calles (Total: % km)', v_calles_concordia_count, v_concordia_calles_km;

    -- Test 11.2: Vista de densidad vial por localidad
    SELECT COUNT(*)
    INTO v_densidad_loc_count
    FROM entrerios.vw_act11_densidad_localidades;

    IF v_densidad_loc_count = 0 THEN
        RAISE EXCEPTION 'TEST 11.2 FALLIDO: La vista vw_act11_densidad_localidades está vacía.';
    END IF;

    RAISE NOTICE 'TEST 11.2 OK: Densidad calculada para % localidades en Concordia.', v_densidad_loc_count;

    -- Test 11.3: Vías primary y secondary en Concordia
    SELECT COUNT(*)
    INTO v_primary_count
    FROM entrerios.vw_act11_primary_secondary_concordia;

    IF v_primary_count = 0 THEN
        RAISE EXCEPTION 'TEST 11.3 FALLIDO: No se recuperaron vías primary/secondary en Concordia.';
    END IF;

    RAISE NOTICE 'TEST 11.3 OK: % tramos de vías primary y secondary identificados en Concordia.', v_primary_count;

    -- Test 11.4: Vista de calles y cruces hídricos
    SELECT COUNT(*)
    INTO v_cruces_count
    FROM entrerios.vw_act11_cruces_hidricos_concordia;

    RAISE NOTICE 'TEST 11.4 OK: % cruces viales sobre cursos de agua detectados en Concordia.', v_cruces_count;

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'TODOS LOS TESTS DE LA ACTIVIDAD 11 COMPLETADOS CON ÉXITO';
    RAISE NOTICE '=====================================================';
END $$;
