-- ============================================================================
-- ACTIVIDAD 9: GESTIÓN DEL RIESGO HÍDRICO
-- 9.2. Infraestructura sanitaria expuesta (Departamento Concordia)
-- ============================================================================
-- Justificación CRS (EPSG:5343): Permite calcular la distancia euclidiana precisa en metros desde cada efector hacia la hidrografía.
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
        ST_Transform(s.geom, 5343) AS geom_5343
    FROM entrerios.salud s, concordia c
    WHERE ST_Intersects(s.geom, c.geom)
),
red_hidrica_unificada AS (
    SELECT ST_Union(ST_Transform(r.geom, 5343)) AS geom_agua_5343
    FROM entrerios.rios r, concordia c WHERE ST_Intersects(r.geom, c.geom)
    UNION ALL
    SELECT ST_Union(ST_Transform(l.geom, 5343)) AS geom_agua_5343
    FROM entrerios.lagunas l, concordia c WHERE ST_Intersects(l.geom, c.geom)
)
SELECT 
    sc.id,
    sc.nombre,
    sc.tipo_establecimiento,
    sc.operador,
    ROUND((ST_Distance(sc.geom_5343, a.geom_agua_5343))::numeric, 2) AS distancia_agua_metros,
    'Expuesto (< 2.000 m)'::text AS estado_vulnerabilidad,
    sc.geom_4326 AS geom
FROM salud_concordia sc
CROSS JOIN red_hidrica_unificada a
JOIN entrerios.vw_act9_zona_riesgo_concordia zr ON ST_Intersects(sc.geom_4326, zr.geom)
ORDER BY distancia_al_agua_metros ASC;

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
