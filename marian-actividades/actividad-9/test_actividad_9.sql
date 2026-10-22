-- ============================================================================
-- SCRIPT DE VALIDACIÓN E INTEGRIDAD: ACTIVIDAD 9
-- Ejecución manual / automatizada mediante bloques DO $$ en PostgreSQL
-- ============================================================================

SET search_path TO entrerios, public;

DO $$
DECLARE
    v_count integer;
    v_area numeric;
    v_valida boolean;
    v_max_dist numeric;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'INICIANDO PRUEBAS DE INTEGRIDAD - ACTIVIDAD 9';
    RAISE NOTICE '=====================================================';

    -- ------------------------------------------------------------------------
    -- Test 9.1: Zona de Riesgo Concordia
    -- ------------------------------------------------------------------------
    SELECT COUNT(*), COALESCE(MAX(superficie_riesgo_km2), 0), bool_and(ST_IsValid(geom))
    INTO v_count, v_area, v_valida
    FROM entrerios.vw_act9_zona_riesgo_concordia;

    IF v_count = 0 THEN
        RAISE EXCEPTION 'TEST 9.1 FALLIDO: La vista vw_act9_zona_riesgo_concordia no devuelve filas.';
    END IF;

    IF v_area <= 0 THEN
        RAISE EXCEPTION 'TEST 9.1 FALLIDO: La superficie de riesgo calculada es <= 0 km2.';
    END IF;

    IF NOT v_valida THEN
        RAISE EXCEPTION 'TEST 9.1 FALLIDO: La geometría resultante del buffer no es topológicamente válida.';
    END IF;

    RAISE NOTICE 'TEST 9.1 OK: Zona de riesgo generada correctamente (Superficie: % km2, Validez: %)', v_area, v_valida;

    -- ------------------------------------------------------------------------
    -- Test 9.2: Hospitales en Riesgo
    -- ------------------------------------------------------------------------
    SELECT COUNT(*), COALESCE(MAX(distancia_agua_metros), 0)
    INTO v_count, v_max_dist
    FROM entrerios.vw_act9_salud_riesgo_concordia;

    IF v_max_dist > 2000.01 THEN
        RAISE EXCEPTION 'TEST 9.2 FALLIDO: Se detectó un hospital con distancia % m (> 2000 m).', v_max_dist;
    END IF;

    RAISE NOTICE 'TEST 9.2 OK: Hospitales en riesgo evaluados (Cantidad: %, Distancia máxima al agua: % m)', v_count, v_max_dist;

    -- ------------------------------------------------------------------------
    -- Test 9.3: Aislamiento y Red Vial
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count FROM entrerios.vw_act9_rutas_afectadas_concordia;
    RAISE NOTICE 'TEST 9.3 OK: Tramos de rutas evaluados en zona inundable (Tramos afectados: %)', v_count;

    -- ------------------------------------------------------------------------
    -- Test 9.4: Exposición Provincial
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count FROM entrerios.vw_act9_exposicion_provincial;
    
    IF v_count < 10 THEN
        RAISE EXCEPTION 'TEST 9.4 FALLIDO: Se esperaba evaluar la totalidad de departamentos provinciales (se encontraron %)', v_count;
    END IF;

    -- Validar rangos porcentuales [0, 100]
    SELECT COUNT(*) INTO v_count 
    FROM entrerios.vw_act9_exposicion_provincial 
    WHERE porcentaje_expuesto < 0 OR porcentaje_expuesto > 100;

    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 9.4 FALLIDO: Existen departamentos con porcentajes fuera del rango [0, 100].';
    END IF;

    RAISE NOTICE 'TEST 9.4 OK: Ranking provincial generado y validado en rango [0, 100].';
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'TODAS LAS PRUEBAS DE LA ACTIVIDAD 9 PASARON CON ÉXITO';
    RAISE NOTICE '=====================================================';
END $$;
