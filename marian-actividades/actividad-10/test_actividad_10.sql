-- ============================================================================
-- SCRIPT DE VALIDACIÓN E INTEGRIDAD: ACTIVIDAD 10
-- Ejecución manual / automatizada mediante bloques DO $$ en PostgreSQL
-- ============================================================================

SET search_path TO entrerios, public;

DO $$
DECLARE
    v_res_varchar varchar;
    v_count integer;
    v_area_real numeric;
    v_area_mbr numeric;
    v_hosp_nom varchar;
    v_hosp_dist numeric;
    v_clusters_count integer;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'INICIANDO PRUEBAS DE INTEGRIDAD - ACTIVIDAD 10';
    RAISE NOTICE '=====================================================';

    -- ------------------------------------------------------------------------
    -- Test 10.1: Función fn_riesgo_localidad
    -- ------------------------------------------------------------------------
    -- 1. Probar con localidad existente
    SELECT entrerios.fn_riesgo_localidad('Concordia') INTO v_res_varchar;
    IF v_res_varchar NOT IN ('Alto', 'Medio', 'Bajo') THEN
        RAISE EXCEPTION 'TEST 10.1 FALLIDO: Resultado inesperado para Concordia: %', v_res_varchar;
    END IF;
    RAISE NOTICE 'TEST 10.1.a OK: fn_riesgo_localidad(''Concordia'') -> %', v_res_varchar;

    -- 2. Probar con localidad inexistente
    SELECT entrerios.fn_riesgo_localidad('LocalidadFicticiaInexistente_123') INTO v_res_varchar;
    IF v_res_varchar <> 'Localidad no encontrada' THEN
        RAISE EXCEPTION 'TEST 10.1 FALLIDO: No manejó correctamente localidad inexistente: %', v_res_varchar;
    END IF;
    RAISE NOTICE 'TEST 10.1.b OK: Manejo de caso borde localidad inexistente validado.';

    -- ------------------------------------------------------------------------
    -- Test 10.2: MBR de Entre Ríos
    -- ------------------------------------------------------------------------
    SELECT 
        MAX(CASE WHEN id = 1 THEN superficie_km2 END),
        MAX(CASE WHEN id = 2 THEN superficie_km2 END)
    INTO v_area_real, v_area_mbr
    FROM entrerios.vw_act10_mbr_entre_rios;

    IF v_area_real IS NULL OR v_area_mbr IS NULL THEN
        RAISE EXCEPTION 'TEST 10.2 FALLIDO: La vista vw_act10_mbr_entre_rios no devolvió las áreas esperadas.';
    END IF;

    IF v_area_mbr <= v_area_real THEN
        RAISE EXCEPTION 'TEST 10.2 FALLIDO: El área del MBR (%) debe ser estrictamente mayor a la real (%).', v_area_mbr, v_area_real;
    END IF;
    RAISE NOTICE 'TEST 10.2 OK: MBR validado (Área Real: % km2, Área MBR: % km2)', v_area_real, v_area_mbr;

    -- ------------------------------------------------------------------------
    -- Test 10.3: Función fn_hospital_cercano
    -- ------------------------------------------------------------------------
    -- Coordenada de prueba: Plaza 25 de Mayo Concordia (-31.3929, -58.0209)
    SELECT nombre_establecimiento, distancia_metros 
    INTO v_hosp_nom, v_hosp_dist
    FROM entrerios.fn_hospital_cercano(-31.3929, -58.0209);

    IF v_hosp_nom IS NULL OR v_hosp_dist IS NULL OR v_hosp_dist < 0 THEN
        RAISE EXCEPTION 'TEST 10.3 FALLIDO: fn_hospital_cercano devolvió valores inválidos (% - % m).', v_hosp_nom, v_hosp_dist;
    END IF;
    RAISE NOTICE 'TEST 10.3 OK: fn_hospital_cercano validada (Hospital: %, Distancia: % m)', v_hosp_nom, v_hosp_dist;

    -- ------------------------------------------------------------------------
    -- Test 10.4: Clustering K-Means y Centroides
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_clusters_count 
    FROM entrerios.vw_act10_centroides_clusters_concordia;

    IF v_clusters_count <> 3 THEN
        RAISE EXCEPTION 'TEST 10.4 FALLIDO: Se esperaban exactamente 3 clusters pero se obtuvieron %.', v_clusters_count;
    END IF;
    RAISE NOTICE 'TEST 10.4 OK: K-Means validado (Se generaron exactamente % clusters con sus centroides).', v_clusters_count;

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'TODAS LAS PRUEBAS DE LA ACTIVIDAD 10 PASARON CON ÉXITO';
    RAISE NOTICE '=====================================================';
END $$;
