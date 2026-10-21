-- ============================================================================
-- ACTIVIDAD 10: FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- 10.4. Agrupamiento de establecimientos sanitarios (ST_ClusterKMeans)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Asegura distancias ortogonales en el espacio métrico euclidiano para la convergencia del algoritmo K-Means.
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
        ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s, concordia c
    WHERE ST_Intersects(s.geom, c.geom)
)
SELECT 
    sc.id,
    sc.nombre,
    sc.tipo,
    (ST_ClusterKMeans(sc.geom_5343, 3) OVER ()) + 1 AS grupo_cluster_id,
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
        ST_Centroid(ST_Collect(ST_Transform(geom, 5343))) AS geom_centroide_5343,
        ST_ConvexHull(ST_Collect(ST_Transform(geom, 5343))) AS geom_hull_5343
    FROM entrerios.vw_act10_clusters_salud_concordia
    GROUP BY grupo_cluster_id
)
SELECT 
    grupo_cluster_id,
    'Grupo #' || grupo_cluster_id AS identificador_cluster,
    total_efectores,
    ROUND(ST_Y(ST_Transform(geom_centroide_5343, 4326))::numeric, 5) AS latitud_centroide,
    ROUND(ST_X(ST_Transform(geom_centroide_5343, 4326))::numeric, 5) AS longitud_centroide,
    integrantes,
    ST_Transform(geom_centroide_5343, 4326) AS geom_centroide,
    ST_Transform(geom_hull_5343, 4326) AS geom_cobertura
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
