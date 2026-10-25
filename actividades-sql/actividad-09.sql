-- ============================================================================
-- ACTIVIDAD 9 COMPLETA
-- Materia: Bases de Datos Avanzadas - TP2 BD Geográficas
-- Departamento: Concordia
-- Sistema Métrico: EPSG:5347 (POSGAR 2007 / Argentina faja 5, meridiano central 60° O),
-- la faja que corresponde a Entre Ríos. Como la provincia está cerca de ese meridiano,
-- las distancias y superficies son prácticamente iguales a las medidas con geography.
-- ============================================================================
-- Incluye los subítems 9.1 a 9.4 y, al final, el bloque de validación.
-- ============================================================================


-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.1. Definición de una zona de riesgo (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Se proyecta a POSGAR 2007 (faja 5) para realizar cálculos métricos planos en metros, que no son posibles en los grados de EPSG:4326.
-- Justificación Funciones: ST_Buffer genera el radio de 2.000 m; ST_Union disuelve solapamientos y ST_Intersection acota al límite de Concordia.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista espacial para visualizar el área de riesgo en QGIS y consultar métricas
CREATE OR REPLACE VIEW entrerios.vw_act9_zona_riesgo_concordia AS
WITH 
concordia AS (
    SELECT ST_Transform(geom, 5347) AS geom_5347
    FROM entrerios.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
red_hidrica AS (
    SELECT ST_Transform(r.geom, 5347) AS geom_5347 FROM entrerios.rios r, concordia c WHERE ST_Intersects(r.geom, ST_Transform(c.geom_5347, 4326))
    UNION ALL
    SELECT ST_Transform(l.geom, 5347) AS geom_5347 FROM entrerios.lagunas l, concordia c WHERE ST_Intersects(l.geom, ST_Transform(c.geom_5347, 4326))
),
buffer_disuelto AS (
    SELECT ST_Union(ST_Buffer(geom_5347, 2000)) AS geom_buffer_5347 FROM red_hidrica
),
zona_recortada AS (
    SELECT ST_Intersection(b.geom_buffer_5347, c.geom_5347) AS geom_5347
    FROM buffer_disuelto b, concordia c
)
SELECT 
    1 AS id,
    'Concordia'::text AS departamento,
    ROUND((ST_Area(geom_5347) / 1000000.0)::numeric, 2) AS superficie_riesgo_km2,
    ST_Transform(geom_5347, 4326) AS geom
FROM zona_recortada;

-- Consulta de balance de superficie
SELECT 
    d.nam AS departamento,
    ROUND((ST_Area(ST_Transform(d.geom, 5347)) / 1000000.0)::numeric, 2) AS superficie_total_km2,
    z.superficie_riesgo_km2,
    ROUND((z.superficie_riesgo_km2 / (ST_Area(ST_Transform(d.geom, 5347)) / 1000000.0) * 100.0)::numeric, 2) AS porcentaje_en_riesgo
FROM entrerios.departamentos d, entrerios.vw_act9_zona_riesgo_concordia z
WHERE d.nam ILIKE 'Concordia';

-- Interpretación: Representa la superficie de Concordia ubicada a menos de 2 km de cursos de agua, base para evaluar la exposición territorial.


-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.2. Infraestructura sanitaria expuesta (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Permite calcular la distancia euclidiana precisa en metros desde cada efector hacia la hidrografía.
-- Justificación Funciones: ST_Intersects evalúa la pertenencia a la zona de riesgo y ST_Distance cuantifica la proximidad mínima al agua.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista espacial de hospitales y clínicas ubicados en zona inundable
CREATE OR REPLACE VIEW entrerios.vw_act9_salud_riesgo_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
salud_concordia AS (
    SELECT 
        s.id,
        COALESCE(s.name, 'Establecimiento sin nombre') AS nombre,
        COALESCE(s.amenity, s.healthcare, 'Salud')::text AS tipo_establecimiento,
        s.operator AS operador,
        s.geom AS geom_4326,
        ST_Transform(s.geom, 5347) AS geom_5347
    FROM entrerios.salud s, concordia c
    WHERE ST_Intersects(s.geom, c.geom)
),
red_hidrica_unificada AS (
    -- Ríos y lagunas en una sola fila: así cada centro aparece una sola vez.
    SELECT ST_Union(agua.geom_5347) AS geom_agua_5347
    FROM (
        SELECT ST_Transform(r.geom, 5347) AS geom_5347
        FROM entrerios.rios r, concordia c WHERE ST_Intersects(r.geom, c.geom)
        UNION ALL
        SELECT ST_Transform(l.geom, 5347) AS geom_5347
        FROM entrerios.lagunas l, concordia c WHERE ST_Intersects(l.geom, c.geom)
    ) AS agua
)
SELECT 
    sc.id,
    sc.nombre,
    sc.tipo_establecimiento,
    sc.operador,
    ROUND((ST_Distance(sc.geom_5347, a.geom_agua_5347))::numeric, 2) AS distancia_agua_metros,
    'Expuesto (< 2.000 m)'::text AS estado_vulnerabilidad,
    sc.geom_4326 AS geom
FROM salud_concordia sc
CROSS JOIN red_hidrica_unificada a
JOIN entrerios.vw_act9_zona_riesgo_concordia zr ON ST_Intersects(sc.geom_4326, zr.geom)
ORDER BY distancia_agua_metros ASC;

-- Consulta de diagnóstico y resumen cuantitativo
SELECT 
    COUNT(s.id) AS total_centros_salud_concordia,
    COUNT(exp.id) AS centros_en_zona_riesgo,
    COUNT(s.id) - COUNT(exp.id) AS centros_fuera_de_riesgo,
    ROUND((COUNT(exp.id)::numeric / NULLIF(COUNT(s.id), 0) * 100.0), 2) AS porcentaje_expuesto
FROM entrerios.salud s
JOIN entrerios.departamentos d ON ST_Intersects(s.geom, d.geom)
LEFT JOIN entrerios.vw_act9_salud_riesgo_concordia exp ON s.id = exp.id
WHERE d.nam ILIKE 'Concordia';

-- Interpretación: Identifica los centros de salud vulnerables a anegamientos para priorizar operativos de evacuación o refuerzo defensivo.


-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.3. Posibles situaciones de aislamiento (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Asegura mediciones ortogonales en metros para longitudes de trazas cortadas y radios de proximidad.
-- Justificación Funciones: ST_Intersection extrae los segmentos viales anegables y ST_Distance / ST_DWithin miden la separación al punto de corte.
-- ============================================================================

SET search_path TO entrerios, public;

-- 1. Vista de tramos viales principales comprometidos por inundación
CREATE OR REPLACE VIEW entrerios.vw_act9_rutas_afectadas_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
rutas_principales AS (
    SELECT 
        r.id,
        COALESCE(r.ref, r.name, 'Ruta sin denominación') AS identificador_ruta,
        r.highway AS jerarquia_vial,
        ST_Transform(r.geom, 5347) AS geom_5347
    FROM entrerios.rutas r, concordia c
    WHERE ST_Intersects(r.geom, c.geom)
      AND r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
),
zona_riesgo AS (
    SELECT ST_Transform(geom, 5347) AS geom_5347 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
)
SELECT 
    rp.id AS ruta_id,
    rp.identificador_ruta,
    rp.jerarquia_vial,
    ROUND((ST_Length(rp.geom_5347))::numeric, 2) AS longitud_total_m,
    ROUND((ST_Length(ST_Intersection(rp.geom_5347, zr.geom_5347)))::numeric, 2) AS longitud_afectada_m,
    ROUND((ST_Length(ST_Intersection(rp.geom_5347, zr.geom_5347)) / NULLIF(ST_Length(rp.geom_5347), 0) * 100.0)::numeric, 2) AS porcentaje_afectado,
    ST_Transform(ST_Intersection(rp.geom_5347, zr.geom_5347), 4326) AS geom
FROM rutas_principales rp
CROSS JOIN zona_riesgo zr
WHERE ST_Intersects(rp.geom_5347, zr.geom_5347);

-- 2. Vista de diagnóstico de aislamiento para localidades
CREATE OR REPLACE VIEW entrerios.vw_act9_localidades_aislamiento_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
localidades_concordia AS (
    SELECT loc.id, loc.name AS localidad, ST_Transform(loc.geom, 5347) AS geom_5347, loc.geom AS geom_4326
    FROM entrerios.localidades loc, concordia c
    WHERE ST_Intersects(loc.geom, c.geom)
),
cortes_viales AS (
    SELECT ST_Union(ST_Transform(geom, 5347)) AS geom_cortes_5347 FROM entrerios.vw_act9_rutas_afectadas_concordia
),
zona_riesgo AS (
    SELECT ST_Transform(geom, 5347) AS geom_5347 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
),
red_vial AS (
    SELECT ST_Union(ST_Transform(r.geom, 5347)) AS geom_red_5347
    FROM entrerios.rutas r, concordia c
    WHERE ST_Intersects(r.geom, c.geom) AND r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
)
SELECT 
    lc.id,
    lc.localidad,
    CASE WHEN ST_Intersects(lc.geom_5347, zr.geom_5347) THEN 'Sí' ELSE 'No' END AS casco_urbano_en_riesgo,
    ROUND((ST_Distance(lc.geom_5347, rv.geom_red_5347))::numeric, 2) AS distancia_ruta_principal_m,
    ROUND((ST_Distance(lc.geom_5347, cv.geom_cortes_5347))::numeric, 2) AS distancia_corte_mas_cercano_m,
    CASE 
        WHEN ST_Intersects(lc.geom_5347, zr.geom_5347) AND ST_DWithin(lc.geom_5347, cv.geom_cortes_5347, 3000) THEN 'Crítico (En riesgo y corte próximo)'
        WHEN ST_DWithin(lc.geom_5347, cv.geom_cortes_5347, 2000) THEN 'Vulnerable (Vía de acceso amenazada)'
        ELSE 'Bajo (Sin corte próximo según este criterio)'
    END AS nivel_aislamiento,
    lc.geom_4326 AS geom
FROM localidades_concordia lc
CROSS JOIN zona_riesgo zr
CROSS JOIN cortes_viales cv
CROSS JOIN red_vial rv
ORDER BY distancia_corte_mas_cercano_m ASC;

-- Consulta de reporte para el informe
SELECT localidad, casco_urbano_en_riesgo, distancia_ruta_principal_m, distancia_corte_mas_cercano_m, nivel_aislamiento
FROM entrerios.vw_act9_localidades_aislamiento_concordia;

-- Interpretación: Identifica localidades próximas a tramos de ruta expuestos.
-- No modela la red vial ni demuestra un único acceso, cortes reales o aislamiento.


-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.4. Departamentos con mayor exposición (Alcance Provincial - Umbral 30%)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Uniformiza el cálculo de áreas en km² para los 17 departamentos; al usar la misma proyección, los porcentajes son comparables entre sí.
-- Justificación Funciones: ST_Buffer genera el área de influencia de 2.000 m y ST_Intersection cuantifica la superposición con cada departamento.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista del ranking provincial de exposición hídrica
CREATE OR REPLACE VIEW entrerios.vw_act9_exposicion_provincial AS
WITH 
departamentos_proyectados AS (
    SELECT 
        d.id,
        d.nam AS departamento,
        d.geom AS geom_4326,
        ST_Transform(d.geom, 5347) AS geom_5347,
        (ST_Area(ST_Transform(d.geom, 5347)) / 1000000.0) AS area_total_km2
    FROM entrerios.departamentos d
),
buffer_por_departamento AS (
    SELECT dp.id AS dep_id, ST_Union(ST_Buffer(ST_Transform(r.geom, 5347), 2000)) AS geom_buffer_rios
    FROM departamentos_proyectados dp
    JOIN entrerios.rios r ON ST_Intersects(r.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_lagunas_por_departamento AS (
    SELECT dp.id AS dep_id, ST_Union(ST_Buffer(ST_Transform(l.geom, 5347), 2000)) AS geom_buffer_lagunas
    FROM departamentos_proyectados dp
    JOIN entrerios.lagunas l ON ST_Intersects(l.geom, dp.geom_4326)
    GROUP BY dp.id
),
buffer_consolidado AS (
    SELECT 
        dp.id AS dep_id,
        dp.departamento,
        dp.area_total_km2,
        dp.geom_4326,
        ST_Intersection(
            dp.geom_5347,
            ST_Union(
                COALESCE(br.geom_buffer_rios, 'POLYGON EMPTY'::geometry),
                COALESCE(bl.geom_buffer_lagunas, 'POLYGON EMPTY'::geometry)
            )
        ) AS geom_riesgo_5347
    FROM departamentos_proyectados dp
    LEFT JOIN buffer_por_departamento br ON dp.id = br.dep_id
    LEFT JOIN buffer_lagunas_por_departamento bl ON dp.id = bl.dep_id
)
SELECT 
    bc.dep_id AS id,
    bc.departamento,
    ROUND(bc.area_total_km2::numeric, 2) AS area_total_km2,
    ROUND((ST_Area(bc.geom_riesgo_5347) / 1000000.0)::numeric, 2) AS area_en_riesgo_km2,
    ROUND(((ST_Area(bc.geom_riesgo_5347) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0)::numeric, 2) AS porcentaje_expuesto,
    CASE 
        WHEN ((ST_Area(bc.geom_riesgo_5347) / 1000000.0) / NULLIF(bc.area_total_km2, 0) * 100.0) >= 30.0 THEN 'Sí'
        ELSE 'No'
    END AS supera_umbral_30_pct,
    CASE WHEN bc.departamento ILIKE 'Concordia' THEN 'Departamento en estudio' ELSE 'Provincial' END AS categoria_estudio,
    bc.geom_4326 AS geom
FROM buffer_consolidado bc
ORDER BY porcentaje_expuesto DESC;

-- Consulta de departamentos críticos que superan el umbral del 30%
SELECT 
    row_number() OVER (ORDER BY porcentaje_expuesto DESC) AS ranking,
    departamento,
    area_total_km2,
    area_en_riesgo_km2,
    porcentaje_expuesto,
    supera_umbral_30_pct,
    categoria_estudio
FROM entrerios.vw_act9_exposicion_provincial;

-- Interpretación: Demuestra la vulnerabilidad relativa de cada departamento; los fluviales y deltaicos superan holgadamente el 30% de exposición.


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
