-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 8: Rutas y accesibilidad sanitaria (Departamento Concordia)
-- Subpunto 8.1: Red vial principal que atraviesa el departamento
-- Autor: Grigolato
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- ============================================================================

-- Objetivo:
-- Identificar las rutas nacionales y provinciales que atraviesan el departamento Concordia.
-- Se realiza la intersección espacial entre la red de rutas y el polígono departamental.

WITH depto_concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam ILIKE 'Concordia'
    LIMIT 1
),
rutas_candidatas AS (
    SELECT 
        r.fid,
        r.highway AS categoria,
        COALESCE(r.ref, r.name, 'Sin Denominación') AS identificador_ruta,
        r.name AS nombre_tramo,
        r.ref AS codigo_oficial,
        r.geom
    FROM capas.rutas r
    JOIN depto_concordia d ON ST_Intersects(r.geom, d.geom)
)
SELECT 
    identificador_ruta,
    categoria,
    COUNT(*) AS cantidad_tramos,
    CASE 
        WHEN identificador_ruta ILIKE 'RN%' OR identificador_ruta ILIKE 'Ruta Nacional%' OR codigo_oficial ILIKE 'RN%' THEN 'Ruta Nacional'
        WHEN identificador_ruta ILIKE 'RP%' OR identificador_ruta ILIKE 'Ruta Provincial%' OR codigo_oficial ILIKE 'RP%' THEN 'Ruta Provincial'
        WHEN identificador_ruta ILIKE 'A%' THEN 'Acceso Nacional / Autovía'
        ELSE 'Red Vial Principal / Enlace'
    END AS jurisdiccion
FROM rutas_candidatas
GROUP BY identificador_ruta, categoria, codigo_oficial
ORDER BY jurisdiccion DESC, cantidad_tramos DESC;
