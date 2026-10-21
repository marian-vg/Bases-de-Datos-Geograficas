-- ============================================================================
-- ACTIVIDAD 9 - GESTIÓN DEL RIESGO HÍDRICO
-- Sub-actividad 9.3: Posibles situaciones de aislamiento
--
-- Departamento seleccionado: Concordia
-- Metodología: Análisis de corte topológico entre Red Vial Principal, 
--              Cursos de Agua / Zona de Riesgo y Localidades.
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista de Tramos de Rutas Afectados / Cortados por Riesgo Hídrico
-- ----------------------------------------------------------------------------
-- Identifica qué secciones de rutas principales (primarias, secundarias,
-- troncales o autopistas como la RN14 y RP28/RP22) quedan inmersas en
-- la zona de riesgo hídrico o intersectan cursos de agua.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act9_rutas_afectadas_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act9_rutas_afectadas_concordia AS
WITH 
dep_concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
rutas_principales AS (
    SELECT 
        r.id,
        COALESCE(r.ref, r.name, 'Ruta sin denominación') AS identificador_ruta,
        r.highway AS categoria_vial,
        ST_Transform(r.geom, 5343) AS geom_5343,
        r.geom AS geom_4326
    FROM entrerios.rutas r
    JOIN dep_concordia d ON ST_Intersects(r.geom, d.geom)
    WHERE r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
),
zona_riesgo AS (
    SELECT geom_5343 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
)
SELECT 
    rp.id AS ruta_id,
    rp.identificador_ruta,
    rp.categoria_vial,
    -- Longitud total de la traza dentro del departamento (en metros)
    ROUND((ST_Length(rp.geom_5343))::numeric, 2) AS longitud_total_m,
    -- Longitud del tramo anegable o dentro del buffer de riesgo (en metros)
    ROUND((ST_Length(ST_Intersection(rp.geom_5343, zr.geom_5343)))::numeric, 2) AS longitud_en_riesgo_m,
    -- Porcentaje de la ruta comprometido
    ROUND((ST_Length(ST_Intersection(rp.geom_5343, zr.geom_5343)) / NULLIF(ST_Length(rp.geom_5343), 0) * 100.0)::numeric, 2) AS porcentaje_comprometido,
    -- Geometría del tramo crítico en EPSG:4326 para representar en QGIS
    ST_Transform(ST_Intersection(rp.geom_5343, zr.geom_5343), 4326) AS geom_corte
FROM rutas_principales rp
CROSS JOIN zona_riesgo zr
WHERE ST_Intersects(rp.geom_5343, zr.geom_5343);

COMMENT ON VIEW entrerios.vw_act9_rutas_afectadas_concordia IS
'Secciones de rutas principales de Concordia cortadas o inmersas en la zona de riesgo hídrico.';

-- ----------------------------------------------------------------------------
-- 2. Vista de Localidades y Diagnóstico de Aislamiento
-- ----------------------------------------------------------------------------
-- Evalúa para cada localidad de Concordia:
-- a) Si la localidad misma está dentro de la zona de riesgo hídrico.
-- b) Distancia a la red vial principal.
-- c) Distancia al punto de anegamiento vial más cercano (usando ST_Distance).
-- d) Clasificación de riesgo de aislamiento.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act9_localidades_aislamiento_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act9_localidades_aislamiento_concordia AS
WITH 
dep_concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
localidades_concordia AS (
    SELECT 
        loc.id,
        loc.name AS localidad,
        loc.geom AS geom_4326,
        ST_Transform(loc.geom, 5343) AS geom_5343
    FROM entrerios.localidades loc
    JOIN dep_concordia d ON ST_Intersects(loc.geom, d.geom)
),
cortes_viales AS (
    SELECT ST_Union(ST_Transform(geom_corte, 5343)) AS geom_cortes_5343
    FROM entrerios.vw_act9_rutas_afectadas_concordia
),
zona_riesgo AS (
    SELECT geom_5343 FROM entrerios.vw_act9_zona_riesgo_concordia LIMIT 1
),
rutas_concordia AS (
    SELECT ST_Union(ST_Transform(r.geom, 5343)) AS geom_red_5343
    FROM entrerios.rutas r
    JOIN dep_concordia d ON ST_Intersects(r.geom, d.geom)
    WHERE r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
)
SELECT 
    lc.id,
    lc.localidad,
    -- ¿El casco urbano se encuentra dentro del buffer de 2 km?
    CASE 
        WHEN ST_Intersects(lc.geom_5343, zr.geom_5343) THEN 'SI (En zona inundable)'
        ELSE 'NO'
    END AS casco_urbano_en_riesgo,
    -- Distancia en metros a la ruta principal más cercana
    ROUND((ST_Distance(lc.geom_5343, rc.geom_red_5343))::numeric, 2) AS distancia_ruta_principal_m,
    -- Distancia en metros al tramo de corte de ruta más cercano
    ROUND((ST_Distance(lc.geom_5343, cv.geom_cortes_5343))::numeric, 2) AS distancia_corte_vial_m,
    -- Diagnóstico cualitativo de aislamiento
    CASE 
        WHEN ST_Intersects(lc.geom_5343, zr.geom_5343) 
             AND ST_DWithin(lc.geom_5343, cv.geom_cortes_5343, 3000) THEN 'ALTO - Riesgo directo y corte próximo'
        WHEN ST_DWithin(lc.geom_5343, cv.geom_cortes_5343, 2000) THEN 'MEDIO - Acceso vial amenazado por agua'
        ELSE 'BAJO - Acceso vial despejado'
    END AS diagnostico_aislamiento,
    lc.geom_4326 AS geom
FROM localidades_concordia lc
CROSS JOIN zona_riesgo zr
CROSS JOIN cortes_viales cv
CROSS JOIN rutas_concordia rc
ORDER BY distancia_corte_vial_m ASC;

COMMENT ON VIEW entrerios.vw_act9_localidades_aislamiento_concordia IS
'Análisis de aislamiento de localidades en Concordia respecto a rutas principales y zonas anegables.';

-- ----------------------------------------------------------------------------
-- 3. Consulta de Resultados para el Informe
-- ----------------------------------------------------------------------------
SELECT 
    localidad,
    casco_urbano_en_riesgo,
    distancia_ruta_principal_m,
    distancia_corte_vial_m,
    diagnostico_aislamiento
FROM entrerios.vw_act9_localidades_aislamiento_concordia;
