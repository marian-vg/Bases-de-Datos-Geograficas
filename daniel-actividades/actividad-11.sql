-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 11: Calles, OpenStreetMap y Argenmap
-- Autor: Daniel / Damián
-- Departamento de referencia: Concordia
-- Sistema métrico proyectado: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- Esquema principal: capas (con compatibilidad en entrerios)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 11.1. DENSIDAD DE LA RED VIAL DEPARTAMENTAL
-- Enunciado: Calcular la longitud total de calles del departamento seleccionado.
-- Comparar este valor con el promedio correspondiente al conjunto de departamentos
-- de Entre Ríos.
-- ----------------------------------------------------------------------------
WITH calles_por_depto AS (
    SELECT 
        d.gid,
        d.nam AS departamento,
        COUNT(c.fid) AS cantidad_tramos,
        ROUND((SUM(ST_Length(ST_Transform(c.geom, 5343))) / 1000.0)::numeric, 2) AS longitud_calles_km,
        ROUND((ST_Area(ST_Transform(d.geom, 5343)) / 1000000.0)::numeric, 2) AS superficie_depto_km2
    FROM capas.departamentos d
    LEFT JOIN capas.calles c ON ST_Intersects(c.geom, d.geom)
    GROUP BY d.gid, d.nam, d.geom
),
promedios AS (
    SELECT 
        ROUND(AVG(longitud_calles_km)::numeric, 2) AS prom_provincial_km,
        ROUND(SUM(longitud_calles_km)::numeric, 2) AS total_provincial_km
    FROM calles_por_depto
)
SELECT 
    row_number() OVER (ORDER BY cd.longitud_calles_km DESC) AS ranking,
    cd.departamento,
    cd.cantidad_tramos,
    cd.longitud_calles_km,
    p.prom_provincial_km,
    ROUND((cd.longitud_calles_km - p.prom_provincial_km)::numeric, 2) AS diferencia_vs_promedio_km,
    ROUND(((cd.longitud_calles_km - p.prom_provincial_km) / p.prom_provincial_km * 100.0)::numeric, 2) AS porcentaje_vs_promedio,
    ROUND((cd.longitud_calles_km / cd.superficie_depto_km2)::numeric, 3) AS densidad_lineal_km_por_km2,
    CASE 
        WHEN cd.departamento = 'Concordia' THEN '--> SELECCIONADO' 
        ELSE '' 
    END AS nota
FROM calles_por_depto cd
CROSS JOIN promedios p
ORDER BY cd.longitud_calles_km DESC;


-- ----------------------------------------------------------------------------
-- 11.2. DENSIDAD VIAL POR LOCALIDAD (DEPARTAMENTO CONCORDIA)
-- Enunciado: Determinar qué localidad presenta la mayor densidad vial.
-- Para ello se podrá utilizar como indicador:
--     longitud total de calles / superficie de la localidad
-- 
-- Decisión metodológica:
-- Las localidades provienen de OpenStreetMap (capas.ciudades / place=city|town|village)
-- y están georreferenciadas mediante geometrías puntuales (centroides urbanos).
-- Ante la inexistencia de límites censales/catastrales poligonales oficiales, se adopta
-- un buffer circular estandarizado de radio R = 2.000 m (área de 12,49 km²) alrededor de
-- cada centro urbano.
-- Esto permite comparar de manera uniforme y no sesgada la concentración de trama vial urbana
-- de cada asentamiento:
--     Densidad vial (km/km²) = Longitud de calles interceptadas (km) / Área analizada (12,49 km²)
-- ----------------------------------------------------------------------------
WITH loc_concordia AS (
    SELECT 
        c.fid AS localidad_id,
        c.name AS localidad,
        c.geom AS geom_punto,
        ST_Buffer(ST_Transform(c.geom, 5343), 2000) AS geom_urbana_5343
    FROM capas.ciudades c
    JOIN capas.departamentos d ON ST_Intersects(c.geom, d.geom)
    WHERE d.nam = 'Concordia'
)
SELECT 
    row_number() OVER (
        ORDER BY (SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))) / ST_Area(lc.geom_urbana_5343)) DESC
    ) AS ranking,
    lc.localidad,
    ROUND(ST_Y(lc.geom_punto)::numeric, 5) AS latitud,
    ROUND(ST_X(lc.geom_punto)::numeric, 5) AS longitud,
    ROUND((ST_Area(lc.geom_urbana_5343) / 1000000.0)::numeric, 2) AS superficie_analizada_km2,
    COUNT(ca.fid) AS cantidad_tramos_calles,
    ROUND((SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))) / 1000.0)::numeric, 2) AS longitud_calles_km,
    ROUND(((SUM(ST_Length(ST_Intersection(ST_Transform(ca.geom, 5343), lc.geom_urbana_5343))) / 1000.0) / (ST_Area(lc.geom_urbana_5343) / 1000000.0))::numeric, 2) AS densidad_vial_km_km2
FROM loc_concordia lc
LEFT JOIN capas.calles ca ON ST_Intersects(ca.geom, ST_Transform(lc.geom_urbana_5343, 4326))
GROUP BY lc.localidad_id, lc.localidad, lc.geom_punto, lc.geom_urbana_5343
ORDER BY densidad_vial_km_km2 DESC;


-- ----------------------------------------------------------------------------
-- 11.3. CATEGORÍAS DE CALLES (PRIMARY Y SECONDARY)
-- Enunciado: Identificar las calles clasificadas como primary y secondary,
-- y calcular cuántos kilómetros corresponden a cada categoría.
-- 
-- Nota de fuentes:
-- En OpenStreetMap, las vías clasificadas jerárquicamente como primary y secondary
-- integran la red de rutas y avenidas principales (almacenadas en capas.rutas / 
-- highways_er_completo.gpkg).
-- Se presenta el análisis consolidado a nivel provincial y específico para Concordia.
-- ----------------------------------------------------------------------------

-- A) Resumen comparativo de longitud por categoría (Provincia vs Concordia)
WITH concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343 
    FROM capas.departamentos 
    WHERE nam = 'Concordia'
)
SELECT 
    r.highway AS categoria_calle,
    COUNT(*) AS cantidad_tramos_provincia,
    ROUND((SUM(ST_Length(ST_Transform(r.geom, 5343))) / 1000.0)::numeric, 2) AS longitud_provincial_km,
    COUNT(CASE WHEN ST_Intersects(r.geom, c.geom) THEN 1 END) AS cantidad_tramos_concordia,
    ROUND((SUM(CASE WHEN ST_Intersects(r.geom, c.geom) 
                    THEN ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343)) 
                    ELSE 0 END) / 1000.0)::numeric, 2) AS longitud_concordia_km,
    ROUND(((SUM(CASE WHEN ST_Intersects(r.geom, c.geom) 
                     THEN ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343)) 
                     ELSE 0 END) / 
            NULLIF(SUM(ST_Length(ST_Transform(r.geom, 5343))), 0)) * 100.0)::numeric, 2) AS pct_en_concordia
FROM capas.rutas r
CROSS JOIN concordia c
WHERE r.highway IN ('primary', 'secondary')
GROUP BY r.highway
ORDER BY r.highway;

-- B) Detalle de corredores viales en Concordia clasificados como primary y secondary
WITH concordia AS (
    SELECT geom, ST_Transform(geom, 5343) AS geom_5343 
    FROM capas.departamentos 
    WHERE nam = 'Concordia'
)
SELECT 
    r.highway AS categoria,
    COALESCE(r.ref, r.name, '(sin denominación)') AS denominacion,
    COUNT(*) AS cantidad_tramos,
    ROUND((SUM(ST_Length(ST_Intersection(ST_Transform(r.geom, 5343), c.geom_5343))) / 1000.0)::numeric, 2) AS longitud_km
FROM capas.rutas r
JOIN concordia c ON ST_Intersects(r.geom, c.geom)
WHERE r.highway IN ('primary', 'secondary')
GROUP BY r.highway, COALESCE(r.ref, r.name, '(sin denominación)')
ORDER BY r.highway, longitud_km DESC;
