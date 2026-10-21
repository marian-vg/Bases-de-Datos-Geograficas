-- ============================================================================
-- ACTIVIDAD 10 - FUNCIONES Y AUTOMATIZACIÓN MEDIANTE SQL
-- Sub-actividad 10.4: Agrupamiento de establecimientos sanitarios (K-Means)
--
-- Función PostGIS: ST_ClusterKMeans(geom, 3) OVER ()
-- Departamento: Concordia
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina 5)
-- ============================================================================

SET search_path TO entrerios, public;

-- ----------------------------------------------------------------------------
-- 1. Vista de Establecimientos con su Cluster Asignado (Para QGIS)
-- ----------------------------------------------------------------------------
-- Asigna a cada centro de salud de Concordia un identificador de cluster (0, 1 o 2).
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act10_clusters_salud_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act10_clusters_salud_concordia AS
WITH 
dep_concordia AS (
    SELECT geom FROM entrerios.departamentos WHERE nam ILIKE 'Concordia' LIMIT 1
),
salud_concordia AS (
    SELECT 
        s.id,
        COALESCE(s.name, 'Establecimiento sin nombre') AS nombre,
        COALESCE(s.amenity, s.healthcare, 'Salud') AS tipo,
        s.geom AS geom_4326,
        ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s
    JOIN dep_concordia d ON ST_Intersects(s.geom, d.geom)
)
SELECT 
    sc.id,
    sc.nombre,
    sc.tipo,
    -- Algoritmo K-Means proyectado en EPSG:5343 para distancias métricas ortogonales
    (ST_ClusterKMeans(sc.geom_5343, 3) OVER ()) + 1 AS cluster_id,
    sc.geom_4326 AS geom
FROM salud_concordia sc;

COMMENT ON VIEW entrerios.vw_act10_clusters_salud_concordia IS
'Establecimientos de salud de Concordia clasificados en 3 grupos mediante ST_ClusterKMeans.';

-- ----------------------------------------------------------------------------
-- 2. Vista de Centroides Estratégicos y Envolventes de los Clusters
-- ----------------------------------------------------------------------------
-- Calcula para cada uno de los 3 grupos:
-- a) Cantidad de efectores.
-- b) Listado de nombres.
-- c) Centroide óptimo (ST_Centroid de ST_Collect).
-- d) Área de cobertura (ST_ConvexHull) para visualizar en QGIS.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS entrerios.vw_act10_centroides_clusters_concordia CASCADE;

CREATE OR REPLACE VIEW entrerios.vw_act10_centroides_clusters_concordia AS
WITH 
clusters_agrupados AS (
    SELECT 
        cluster_id,
        COUNT(*) AS cantidad_efectores,
        string_agg(nombre, ' | ' ORDER BY nombre) AS establecimientos_integrantes,
        ST_Centroid(ST_Collect(ST_Transform(geom, 5343))) AS geom_centroide_5343,
        ST_ConvexHull(ST_Collect(ST_Transform(geom, 5343))) AS geom_hull_5343
    FROM entrerios.vw_act10_clusters_salud_concordia
    GROUP BY cluster_id
)
SELECT 
    cluster_id,
    'Cluster #' || cluster_id AS etiqueta_cluster,
    cantidad_efectores,
    establecimientos_integrantes,
    -- Coordenadas legibles del centroide
    ROUND(ST_Y(ST_Transform(geom_centroide_5343, 4326))::numeric, 5) AS latitud_centroide,
    ROUND(ST_X(ST_Transform(geom_centroide_5343, 4326))::numeric, 5) AS longitud_centroide,
    -- Geometría del centroide en EPSG:4326 para QGIS
    ST_Transform(geom_centroide_5343, 4326) AS geom_centroide,
    -- Geometría poligonal del cluster (envolvente convexa) en EPSG:4326
    ST_Transform(geom_hull_5343, 4326) AS geom_area_cobertura
FROM clusters_agrupados
ORDER BY cluster_id;

COMMENT ON VIEW entrerios.vw_act10_centroides_clusters_concordia IS
'Centroides logísticos y áreas de cobertura para los 3 clusters sanitarios de Concordia.';

-- ----------------------------------------------------------------------------
-- 3. Consulta de Reporte e Interpretación Logística
-- ----------------------------------------------------------------------------

SELECT 
    etiqueta_cluster,
    cantidad_efectores,
    latitud_centroide,
    longitud_centroide,
    establecimientos_integrantes
FROM entrerios.vw_act10_centroides_clusters_concordia;

/*
===============================================================================
INTERPRETACIÓN LOGÍSTICA DE LOS CENTROIDES:
===============================================================================
1. Minimización de tiempos de respuesta (Isócronas):
   - El centroide de cada cluster representa el baricentro geométrico óptimo que 
     minimiza la suma de las distancias euclidianas hacia todos los centros de salud 
     que componen ese grupo.

2. Aplicaciones prácticas en gestión de emergencias:
   a) Bases de Despliegue de Ambulancias:
      Establecer puestos de ambulancias en las coordenadas del centroide asegura 
      que los móviles alcancen cualquiera de los efectores del cluster con el 
      menor recorrido promedio posible.
   b) Puntos de Almacenamiento y Reparto de Medicamentos / Insumos:
      Frente a cortes de rutas o inundaciones, los 3 centroides actúan como nodos 
      logísticos intermedios para abastecer a los centros de salud periféricos 
      sin saturar el hospital cabecera central.
   c) Localización de Nuevos Centros de Salud de Atención Primaria (CAPS):
      Si un centroide presenta una alta distancia media respecto a sus efectores, 
      indica una zona desatendida con necesidad prioritaria de cobertura sanitaria.
===============================================================================
*/
