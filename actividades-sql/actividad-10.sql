-- ============================================================================
-- ACTIVIDAD 10 COMPLETA
-- Materia: Bases de Datos Avanzadas - TP2 BD Geográficas
-- Departamento: Concordia
-- Sistema Métrico: EPSG:5347 (POSGAR 2007 / Argentina faja 5, meridiano central 60° O),
-- la faja que corresponde a Entre Ríos. Como la provincia está cerca de ese meridiano,
-- las distancias y superficies son prácticamente iguales a las medidas con geography.
-- ============================================================================
-- Incluye los subítems 10.1 a 10.4 y, al final, el bloque de validación.
-- ============================================================================


-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.1. Clasificación del riesgo de una localidad (fn_riesgo_localidad)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Proporciona unidades métricas uniformes para categorizar los umbrales de 1 km y 3 km.
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
        SELECT ST_Transform(r.geom, 5347) AS geom_5347
        FROM entrerios.rios r
        WHERE ST_DWithin(r.geom, v_loc_geom, 0.1)
        UNION ALL
        SELECT ST_Transform(l.geom, 5347) AS geom_5347
        FROM entrerios.lagunas l
        WHERE ST_DWithin(l.geom, v_loc_geom, 0.1)
    )
    SELECT MIN(ST_Distance(ST_Transform(v_loc_geom, 5347), geom_5347))
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


-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.2. MBR (Minimum Bounding Rectangle) de Entre Ríos (ST_Envelope)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Permite calcular en km² las dos superficies con la misma proyección, por lo que su comparación es válida.
-- Justificación Funciones: ST_Envelope genera el rectángulo mínimo delimitador y ST_Union disuelve las divisiones departamentales.
-- ============================================================================

SET search_path TO entrerios, public;

-- Vista para contrastar cartográficamente el contorno real vs el MBR en QGIS
CREATE OR REPLACE VIEW entrerios.vw_act10_mbr_entre_rios AS
WITH 
provincia AS (
    SELECT ST_Union(ST_Transform(geom, 5347)) AS geom_provincia_5347
    FROM entrerios.departamentos
),
geometrias AS (
    SELECT geom_provincia_5347, ST_Envelope(geom_provincia_5347) AS geom_mbr_5347 FROM provincia
)
SELECT 
    1 AS id,
    'Territorio Real Provincial'::text AS capa,
    ROUND((ST_Area(geom_provincia_5347) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_provincia_5347, 4326) AS geom
FROM geometrias
UNION ALL
SELECT 
    2 AS id,
    'MBR (ST_Envelope) Provincial'::text AS capa,
    ROUND((ST_Area(geom_mbr_5347) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_mbr_5347, 4326) AS geom
FROM geometrias;

-- Consulta comparativa de superficies y ratio de ocupación
WITH 
provincia AS (
    SELECT ST_Union(ST_Transform(geom, 5347)) AS geom_5347 FROM entrerios.departamentos
),
areas AS (
    SELECT 
        ST_Area(geom_5347) / 1000000.0 AS area_real_km2,
        ST_Area(ST_Envelope(geom_5347)) / 1000000.0 AS area_mbr_km2
    FROM provincia
)
SELECT 
    ROUND(area_real_km2::numeric, 2) AS superficie_real_provincia_km2,
    ROUND(area_mbr_km2::numeric, 2) AS superficie_mbr_km2,
    ROUND((area_mbr_km2 - area_real_km2)::numeric, 2) AS diferencia_superficie_km2,
    ROUND((area_real_km2 / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_ocupacion_real,
    ROUND(((area_mbr_km2 - area_real_km2) / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_espacio_vacio
FROM areas;

-- Justificación técnica de la diferencia: El MBR genera un rectángulo ortogonal que abarca del extremo norte-sur y este-oeste, englobando ríos limítrofes y suelo de provincias vecinas que la forma cóncava provincial no ocupa.


-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.3. Búsqueda del hospital más cercano (fn_hospital_cercano)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Permite calcular la distancia euclidiana exacta en metros entre la persona y el efector de salud.
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
    v_punto_5347 geometry;
BEGIN
    IF p_lat IS NULL OR p_lon IS NULL THEN
        RAISE EXCEPTION 'Latitud y longitud son obligatorias.';
    END IF;

    -- Longitud = eje X, Latitud = eje Y en PostGIS
    v_punto_4326 := ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326);
    v_punto_5347 := ST_Transform(v_punto_4326, 5347);

    RETURN QUERY
    WITH candidatos AS (
        SELECT 
            COALESCE(s.name, 'Establecimiento sin nombre formal') AS nombre,
            COALESCE(s.amenity, s.healthcare, 'Centro de Atención')::varchar AS tipo,
            ST_Transform(s.geom, 5347) AS geom_5347
        FROM entrerios.salud s
        ORDER BY s.geom <-> v_punto_4326
        LIMIT 10
    )
    SELECT 
        c.nombre::varchar,
        ROUND((ST_Distance(c.geom_5347, v_punto_5347))::numeric, 2),
        ROUND((ST_Distance(c.geom_5347, v_punto_5347) / 1000.0)::numeric, 3),
        c.tipo
    FROM candidatos c
    ORDER BY ST_Distance(c.geom_5347, v_punto_5347) ASC
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


-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.4. Agrupamiento de establecimientos sanitarios (ST_ClusterKMeans)
-- ============================================================================
-- Justificación CRS (EPSG:5347): Asegura distancias ortogonales en el espacio métrico euclidiano para la convergencia del algoritmo K-Means.
-- Justificación Funciones: ST_ClusterKMeans particiona en k=3 grupos y ST_Centroid calcula el baricentro geométrico óptimo de cobertura.
-- ============================================================================

SET search_path TO entrerios, public;

-- 1. Vista de centros de salud con su grupo asignado para QGIS
CREATE OR REPLACE VIEW entrerios.vw_act10_clusters_salud_concordia AS
WITH 
concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
salud_concordia AS (
    SELECT 
        s.id,
        COALESCE(s.name, 'Establecimiento sin nombre') AS nombre,
        COALESCE(s.amenity, s.healthcare, 'Salud') AS tipo,
        s.geom AS geom_4326,
        ST_Transform(s.geom, 5347) AS geom_5347
    FROM entrerios.salud s, concordia c
    WHERE ST_Intersects(s.geom, c.geom)
)
SELECT 
    sc.id,
    sc.nombre,
    sc.tipo,
    (ST_ClusterKMeans(sc.geom_5347, 3) OVER ()) + 1 AS grupo_cluster_id,
    sc.geom_4326 AS geom
FROM salud_concordia sc;

-- 2. Vista de centroides óptimos y envolventes convexas de cobertura
CREATE OR REPLACE VIEW entrerios.vw_act10_centroides_clusters_concordia AS
WITH 
grupos AS (
    SELECT 
        grupo_cluster_id,
        COUNT(*) AS total_efectores,
        string_agg(nombre, ' | ' ORDER BY nombre) AS integrantes,
        ST_Centroid(ST_Collect(ST_Transform(geom, 5347))) AS geom_centroide_5347,
        ST_ConvexHull(ST_Collect(ST_Transform(geom, 5347))) AS geom_hull_5347
    FROM entrerios.vw_act10_clusters_salud_concordia
    GROUP BY grupo_cluster_id
)
SELECT 
    grupo_cluster_id,
    'Grupo #' || grupo_cluster_id AS identificador_cluster,
    total_efectores,
    ROUND(ST_Y(ST_Transform(geom_centroide_5347, 4326))::numeric, 5) AS latitud_centroide,
    ROUND(ST_X(ST_Transform(geom_centroide_5347, 4326))::numeric, 5) AS longitud_centroide,
    integrantes,
    ST_Transform(geom_centroide_5347, 4326) AS geom_centroide,
    ST_Transform(geom_hull_5347, 4326) AS geom_cobertura
FROM grupos
ORDER BY grupo_cluster_id;

-- Consulta de reporte para el informe
SELECT 
    identificador_cluster,
    total_efectores,
    latitud_centroide,
    longitud_centroide,
    integrantes
FROM entrerios.vw_act10_centroides_clusters_concordia;

-- Interpretación logística: Los centroides representan los baricentros que minimizan la distancia media hacia los efectores, ideales para bases de ambulancias o acopio de insumos.


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
