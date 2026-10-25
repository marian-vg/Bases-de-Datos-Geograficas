-- ============================================================================
-- SCRIPT DE VALIDACIÓN E INTEGRIDAD: ACTIVIDAD 8
-- Autor: Grigolato
-- Verificación automática de vistas y cálculos espaciales mediante bloque DO $$
-- ============================================================================

SET search_path TO entrerios, capas, public;

DO $$
DECLARE
    v_rutas_count integer;
    v_rutas_km numeric;
    v_salud_count integer;
    v_aisladas_count integer;
    v_buffer_count integer;
    v_buffer_area numeric;
    v_buffer_valido boolean;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'INICIANDO PRUEBAS DE INTEGRIDAD - ACTIVIDAD 8';
    RAISE NOTICE '=====================================================';

    -- Test 8.1 y 8.2: Rutas recortadas a Concordia
    SELECT COUNT(*), COALESCE(SUM(longitud_km), 0)
    INTO v_rutas_count, v_rutas_km
    FROM entrerios.vw_act8_rutas_concordia;

    IF v_rutas_count = 0 THEN
        RAISE EXCEPTION 'TEST 8.2 FALLIDO: La vista vw_act8_rutas_concordia no devuelve tramos.';
    END IF;

    IF v_rutas_km <= 0 THEN
        RAISE EXCEPTION 'TEST 8.2 FALLIDO: La longitud acumulada de rutas es menor o igual a 0 km.';
    END IF;

    RAISE NOTICE 'TEST 8.1 y 8.2 OK: % tramos de rutas en Concordia (Longitud total: % km)', v_rutas_count, v_rutas_km;

    -- Test 8.3: Establecimientos de Salud
    SELECT COUNT(*)
    INTO v_salud_count
    FROM entrerios.vw_act8_salud_concordia;

    IF v_salud_count = 0 THEN
        RAISE EXCEPTION 'TEST 8.3 FALLIDO: No se encontraron centros de salud en Concordia.';
    END IF;

    RAISE NOTICE 'TEST 8.3 OK: % establecimientos de salud detectados.', v_salud_count;

    -- Test 8.4: Líneas de aislamiento y cálculo de distancias
    SELECT COUNT(*)
    INTO v_aisladas_count
    FROM entrerios.vw_act8_lineas_aislamiento;

    IF v_aisladas_count = 0 THEN
        RAISE EXCEPTION 'TEST 8.4 FALLIDO: No se pudieron calcular las distancias mínimas a la salud.';
    END IF;

    RAISE NOTICE 'TEST 8.4 OK: Conexiones calculadas para % localidades.', v_aisladas_count;

    -- Test 8.5: Buffer de salud de 5 km
    SELECT COUNT(*), COALESCE(MAX(superficie_cubierta_km2), 0), bool_and(ST_IsValid(geom))
    INTO v_buffer_count, v_buffer_area, v_buffer_valido
    FROM entrerios.vw_act8_buffer_salud_5km;

    IF v_buffer_count = 0 OR v_buffer_area <= 0 THEN
        RAISE EXCEPTION 'TEST 8.5 FALLIDO: El buffer de 5 km no posee superficie válida.';
    END IF;

    IF NOT v_buffer_valido THEN
        RAISE EXCEPTION 'TEST 8.5 FALLIDO: La geometría resultante del buffer no es topológicamente válida.';
    END IF;

    RAISE NOTICE 'TEST 8.5 OK: Cobertura sanitaria de 5 km generada (Área: % km2, Válida: %)', v_buffer_area, v_buffer_valido;

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'TODOS LOS TESTS DE LA ACTIVIDAD 8 COMPLETADOS CON ÉXITO';
    RAISE NOTICE '=====================================================';
END $$;
