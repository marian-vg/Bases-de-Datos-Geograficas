-- ============================================================================
-- TRABAJO PRÁCTICO NRO. 2: BASES DE DATOS GEOGRÁFICAS
-- ACTIVIDAD 14: Ubicación para Centro de Atención Sanitaria de Emergencia
-- Autor: Daniel / Damián
-- Departamento de estudio: Concordia
-- Sistema Métrico: EPSG:5343 (POSGAR 07 / Argentina Faja 5)
-- Esquema: capas (con total compatibilidad en entrerios)
-- ============================================================================

WITH 
-- 1. Polígono de Concordia reproyectado a EPSG:5343 (desde capas del profesor)
departamento AS (
    SELECT fid AS id, nam AS nombre, geom AS geom_4326, ST_Transform(geom, 5343) AS geom_5343
    FROM capas.departamentos
    WHERE nam = 'Concordia'
    LIMIT 1
),

-- 2. Efectores de salud reales (hospitales y clínicas en Concordia, excluyendo laboratorios/kinesiología)
salud_efectiva AS (
    SELECT s.fid AS id, COALESCE(s.name, '(sin nombre)') AS nombre, ST_Transform(s.geom, 5343) AS geom_5343
    FROM capas.salud s
    JOIN departamento d ON ST_Intersects(s.geom, d.geom_4326)
    WHERE s.amenity IN ('hospital', 'clinic')
      AND COALESCE(s.name, '') !~* 'laborator|kine'
),

-- 3. Localidades de Concordia con menor accesibilidad sanitaria (> 5 km de un hospital/clínica según criterio Punto 8.5)
localidades_desatendidas AS (
    SELECT l.fid AS id, COALESCE(l.name, '(sin nombre)') AS nombre, ST_Transform(l.geom, 5343) AS geom_5343
    FROM capas.ciudades l
    JOIN departamento d ON ST_Intersects(l.geom, d.geom_4326)
    WHERE NOT EXISTS (
        SELECT 1 FROM salud_efectiva s
        WHERE ST_DWithin(ST_Transform(l.geom, 5343), s.geom_5343, 5000)
    )
),

-- 4. Corredor de accesibilidad vial: Buffer de 1.000 m sobre rutas principales (motorway, trunk, primary, secondary)
corredor_vial AS (
    SELECT ST_Union(ST_Buffer(ST_Intersection(ST_Transform(r.geom, 5343), d.geom_5343), 1000, 'quad_segs=4')) AS geom_5343
    FROM capas.rutas r
    JOIN departamento d ON ST_Intersects(r.geom, d.geom_4326)
    WHERE r.highway IN ('motorway', 'trunk', 'primary', 'secondary')
),

-- 5. Zona de Riesgo Hídrico y Cuerpos de Agua: Buffer de 2.000 m sobre ríos/arroyos (capas.rios) y lagunas (capas.lagunas)
-- Nota de optimización espacial: ST_SimplifyPreserveTopology con 20m preserva la silueta física a escala 1:100.000
-- reduciendo vértices masivos del embalse Salto Grande / Río Uruguay y acelerando el cómputo topológico.
zona_exclusion_hidrica AS (
    SELECT ST_Union(geom_buf) AS geom_5343
    FROM (
        SELECT ST_Buffer(ST_SimplifyPreserveTopology(ST_Intersection(ST_Transform(ri.geom, 5343), d.geom_5343), 20), 2000, 'quad_segs=4') AS geom_buf
        FROM capas.rios ri
        JOIN departamento d ON ST_Intersects(ri.geom, d.geom_4326)
        WHERE ri.waterway IN ('river', 'stream')
        UNION ALL
        SELECT ST_Buffer(ST_SimplifyPreserveTopology(ST_Intersection(ST_Transform(la.geom, 5343), d.geom_5343), 20), 2000, 'quad_segs=4') AS geom_buf
        FROM capas.lagunas la
        JOIN departamento d ON ST_Intersects(la.geom, d.geom_4326)
    ) sub
),

-- 6. Suelo NO agrícola (preservando tierras de alta aptitud agrícola según índice de productividad ipc <= 55)
suelo_apto AS (
    SELECT 
        s.fid AS suelo_id,
        COALESCE(s.nombre, s.pais_nomb, 'Unidad de suelo') AS unidad_suelo,
        COALESCE(s.ipc, 0) AS ipc,
        ST_Intersection(ST_Transform(s.geom, 5343), d.geom_5343) AS geom_5343
    FROM capas.suelo s
    JOIN departamento d ON ST_Intersects(s.geom, d.geom_4326)
    WHERE COALESCE(s.ipc, 0) <= 55
),

-- 7. Álgebra espacial: (Suelo Apto ∩ Corredor Vial 1km) - Zona de Riesgo Hídrico 2km
poligonos_candidatos AS (
    SELECT 
        sa.suelo_id,
        sa.unidad_suelo,
        sa.ipc,
        (ST_Dump(
            ST_CollectionExtract(
                ST_Difference(
                    ST_Intersection(sa.geom_5343, cv.geom_5343),
                    COALESCE(zh.geom_5343, 'POLYGON EMPTY'::geometry)
                ), 3
            )
        )).geom AS geom_5343
    FROM suelo_apto sa
    JOIN corredor_vial cv ON ST_Intersects(sa.geom_5343, cv.geom_5343)
    CROSS JOIN zona_exclusion_hidrica zh
),

-- 8. Evaluación multicriterio: Superficie >= 5 ha (50.000 m2) y cobertura de localidades desatendidas en un radio de 15 km
ranking_candidatos AS (
    SELECT 
        row_number() OVER () AS id_parcela,
        p.suelo_id,
        p.unidad_suelo,
        p.ipc,
        ROUND((ST_Area(p.geom_5343) / 10000.0)::numeric, 2) AS superficie_ha,
        COUNT(ld.id) AS localidades_vulnerables_cubiertas,
        COALESCE(STRING_AGG(ld.nombre, ', ' ORDER BY ld.nombre), 'Ninguna en <15km') AS detalle_localidades,
        ROUND((AVG(ST_Distance(p.geom_5343, ld.geom_5343)) / 1000.0)::numeric, 2) AS dist_media_localidades_km,
        p.geom_5343
    FROM poligonos_candidatos p
    LEFT JOIN localidades_desatendidas ld ON ST_DWithin(p.geom_5343, ld.geom_5343, 15000)
    WHERE NOT ST_IsEmpty(p.geom_5343)
      AND ST_Area(p.geom_5343) >= 50000 -- Mínimo 5 hectáreas
    GROUP BY p.suelo_id, p.unidad_suelo, p.ipc, p.geom_5343
)

-- 9. Selección de los 5 mejores sitios candidatos con su polígono y coordenada de emplazamiento puntual
SELECT 
    row_number() OVER (
        ORDER BY localidades_vulnerables_cubiertas DESC, dist_media_localidades_km ASC, superficie_ha DESC
    ) AS puesto,
    id_parcela,
    unidad_suelo,
    ipc AS indice_productividad_inta,
    superficie_ha,
    localidades_vulnerables_cubiertas,
    detalle_localidades,
    dist_media_localidades_km,
    ROUND(ST_Y(ST_Transform(ST_PointOnSurface(geom_5343), 4326))::numeric, 5) AS latitud_sugerida,
    ROUND(ST_X(ST_Transform(ST_PointOnSurface(geom_5343), 4326))::numeric, 5) AS longitud_sugerida,
    ST_Multi(ST_Transform(geom_5343, 4326))::geometry(MultiPolygon, 4326) AS geom_poligono,
    ST_Transform(ST_PointOnSurface(geom_5343), 4326)::geometry(Point, 4326) AS geom_punto
FROM ranking_candidatos
ORDER BY puesto
LIMIT 5;