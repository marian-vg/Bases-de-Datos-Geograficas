-- ============================================================================
-- ACTIVIDAD 10 - FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- Sub-actividad 10.2: MBR (Minimum Bounding Rectangle) de Entre Ríos
--
-- Función PostGIS: ST_Envelope
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista Espacial del MBR y Territorio Provincial para QGIS
-- ----------------------------------------------------------------------------
-- Permite superponer en QGIS el límite real de Entre Ríos junto con su MBR.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act10_mbr_entre_rios CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act10_mbr_entre_rios AS
WITH 
provincia_unificada AS (
    SELECT 
        ST_Union(ST_Transform(geom, 5343)) AS geom_provincia_5343
    FROM entrerios.departamentos
),
mbr_calculado AS (
    SELECT 
        geom_provincia_5343,
        ST_Envelope(geom_provincia_5343) AS geom_mbr_5343
    FROM provincia_unificada
)
SELECT 
    1 AS id,
    'Territorio Real de Entre Ríos'::text AS capa,
    ROUND((ST_Area(geom_provincia_5343) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_provincia_5343, 4326) AS geom
FROM mbr_calculado
UNION ALL
SELECT 
    2 AS id,
    'MBR (ST_Envelope) de Entre Ríos'::text AS capa,
    ROUND((ST_Area(geom_mbr_5343) / 1000000.0)::numeric, 2) AS superficie_km2,
    ST_Transform(geom_mbr_5343, 4326) AS geom
FROM mbr_calculado;

COMMENT ON VIEW entrerios.vw_act10_mbr_entre_rios IS
'Capas del contorno provincial real y su envolvente rectangular mínima (MBR) en EPSG:4326.';

-- ----------------------------------------------------------------------------
-- 2. Consulta Comparativa de Superficies y Métricas
-- ----------------------------------------------------------------------------

WITH 
provincia AS (
    SELECT ST_Union(ST_Transform(geom, 5343)) AS geom_5343
    FROM entrerios.departamentos
),
calculos AS (
    SELECT 
        ST_Area(geom_5343) / 1000000.0 AS area_real_km2,
        ST_Area(ST_Envelope(geom_5343)) / 1000000.0 AS area_mbr_km2
    FROM provincia
)
SELECT 
    ROUND(area_real_km2::numeric, 2) AS superficie_real_provincia_km2,
    ROUND(area_mbr_km2::numeric, 2) AS superficie_mbr_envolvente_km2,
    ROUND((area_mbr_km2 - area_real_km2)::numeric, 2) AS diferencia_superficie_km2,
    ROUND((area_real_km2 / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_ocupacion_real,
    ROUND(((area_mbr_km2 - area_real_km2) / area_mbr_km2 * 100.0)::numeric, 2) AS porcentaje_espacio_vacio
FROM calculos;

-- ----------------------------------------------------------------------------
-- 3. Justificación Conceptual / Explicación del Resultado para el Informe
-- ----------------------------------------------------------------------------
/*
===============================================================================
JUSTIFICACIÓN TÉCNICA: ¿POR QUÉ AMBAS SUPERFICIES SON DIFERENTES?
===============================================================================
1. Geometría real vs. Bounding Box:
   - La provincia de Entre Ríos presenta una morfología irregular y cóncava, 
     delimitada por los meandros y cauces de los ríos Paraná y Uruguay.
   - El MBR (calculado mediante ST_Envelope) genera la caja mínima delimitadora 
     alineada a los ejes ortogonales X e Y: [X_min, X_max] x [Y_min, Y_max].

2. Vacíos espaciales y áreas extra-provinciales:
   - El rectángulo del MBR engloba inevitablemente vastas extensiones que no 
     forman parte del suelo provincial, tales como:
     a) Cuerpos de agua limítrofes (Río de la Plata, Río Paraná, Río Uruguay).
     b) Porciones de provincias vecinas (Corrientes al norte, Santa Fe al oeste, 
        Buenos Aires al sur) e incluso parte del territorio uruguayo al este.

3. Aplicación en Bases de Datos Espaciales:
   - En PostGIS y SIG, el MBR se utiliza como filtro primario de bajo costo 
     (Index Scan mediante operadores && en índices GiST R-Tree) antes de ejecutar 
     operaciones geométricas exactas (ST_Intersects, ST_Contains), que son 
     computacionalmente más costosas.
===============================================================================
*/
