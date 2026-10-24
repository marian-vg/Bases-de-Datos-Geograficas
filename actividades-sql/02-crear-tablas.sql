-- ============================================================================
-- TRABAJO PRÁCTICO N° 2: BASES DE DATOS GEOGRÁFICAS
-- Creación del Modelo de Datos Espacial (Esquema entrerios)
-- Base de datos: bdg_entrerios | PostgreSQL con extensión PostGIS
-- ============================================================================

-- Aseguramos la existencia de PostGIS y el esquema de trabajo
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS entrerios;
SET search_path TO entrerios, public;

-- ============================================================================
-- 1. SECUENCIAS
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS entrerios.departamentos_id_seq AS integer START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE IF NOT EXISTS entrerios.suelo_id_seq AS integer START WITH 1 INCREMENT BY 1;

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.departamentos
-- Descripción: Límites político-administrativos departamentales del IGN
-- Geometría: MultiPolygon (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.departamentos (
    id integer NOT NULL,
    geom geometry(MultiPolygon,4326),
    fid bigint,
    gid integer,
    objeto character varying(254),
    fna character varying(254),
    gna character varying(254),
    nam character varying(254),
    in1 character varying(254),
    fdc character varying(254),
    sag character varying(254)
);

-- Clave primaria e índices espaciales para departamentos
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'departamentos_pkey') THEN
        ALTER TABLE entrerios.departamentos ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_departamentos_geom ON entrerios.departamentos USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.localidades
-- Descripción: Poblaciones, ciudades, pueblos y comunas (OpenStreetMap)
-- Geometría: Point (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.localidades (
    id character varying NOT NULL,
    geom geometry(Point,4326),
    "@id" character varying,
    "addr:postcode" character varying,
    alt_name character varying,
    capital character varying,
    "contact:facebook" character varying,
    "contact:website" character varying,
    fixme character varying,
    "is_in:country" character varying,
    "is_in:country_code" character varying,
    "is_in:province" character varying,
    "is_in:state" character varying,
    loc_name character varying,
    name character varying,
    "name:an" character varying,
    "name:ar" character varying,
    "name:ay" character varying,
    "name:azb" character varying,
    "name:be" character varying,
    "name:bg" character varying,
    "name:bn" character varying,
    "name:br" character varying,
    "name:ca" character varying,
    "name:ce" character varying,
    "name:cs" character varying,
    "name:da" character varying,
    "name:de" character varying,
    "name:el" character varying,
    "name:en" character varying,
    "name:eo" character varying,
    "name:es" character varying,
    "name:etymology" character varying,
    "name:eu" character varying,
    "name:fa" character varying,
    "name:fi" character varying,
    "name:fr" character varying,
    "name:gl" character varying,
    "name:gn" character varying,
    "name:he" character varying,
    "name:hi" character varying,
    "name:hr" character varying,
    "name:hu" character varying,
    "name:hy" character varying,
    "name:id" character varying,
    "name:io" character varying,
    "name:it" character varying,
    "name:ja" character varying,
    "name:jv" character varying,
    "name:ka" character varying,
    "name:kk" character varying,
    "name:kn" character varying,
    "name:ko" character varying,
    "name:ky" character varying,
    "name:la" character varying,
    "name:lo" character varying,
    "name:lt" character varying,
    "name:lv" character varying,
    "name:mg" character varying,
    "name:mi" character varying,
    "name:ml" character varying,
    "name:mn" character varying,
    "name:mr" character varying,
    "name:ms" character varying,
    "name:nb" character varying,
    "name:nl" character varying,
    "name:oc" character varying,
    "name:os" character varying,
    "name:pl" character varying,
    "name:pnb" character varying,
    "name:pt" character varying,
    "name:qu" character varying,
    "name:ro" character varying,
    "name:ru" character varying,
    "name:si" character varying,
    "name:sk" character varying,
    "name:sr" character varying,
    "name:sv" character varying,
    "name:th" character varying,
    "name:tl" character varying,
    "name:tr" character varying,
    "name:tt" character varying,
    "name:uk" character varying,
    "name:ur" character varying,
    "name:uz" character varying,
    "name:vi" character varying,
    "name:vo" character varying,
    "name:wal" character varying,
    "name:zh" character varying,
    official_name character varying,
    "official_name:ar" character varying,
    "official_name:uk" character varying,
    old_name character varying,
    "old_name:etymology:wikidata" character varying,
    operator character varying,
    place character varying,
    population character varying,
    "population:2010" character varying,
    "population:date" character varying,
    "population:source" character varying,
    postal_code character varying,
    "ref:locode" character varying,
    "ref:uy:ine:codlocalidadcensal" character varying,
    reg_name character varying,
    short_name character varying,
    source character varying,
    "source:name:oc" character varying,
    "source:population" character varying,
    source_ref character varying,
    "source_ref:population" character varying,
    start_date date,
    website character varying,
    wikidata character varying,
    wikimedia_commons character varying,
    wikipedia character varying
);

-- Clave primaria e índices espaciales para localidades
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'localidades_pkey') THEN
        ALTER TABLE entrerios.localidades ADD CONSTRAINT localidades_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_localidades_geom ON entrerios.localidades USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.salud
-- Descripción: Infraestructura sanitaria: hospitales, clínicas y CAPS (OpenStreetMap)
-- Geometría: Point (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.salud (
    id character varying CONSTRAINT hospitales_id_not_null NOT NULL,
    geom geometry(Point,4326),
    "@id" character varying,
    "addr:city" character varying,
    "addr:country" character varying,
    "addr:full" character varying,
    "addr:housenumber" character varying,
    "addr:postcode" character varying,
    "addr:street" character varying,
    aeroway character varying,
    alt_name character varying,
    amenity character varying,
    beds character varying,
    building character varying,
    "building:levels" character varying,
    "building:material" character varying,
    check_date date,
    "contact:email" character varying,
    "contact:facebook" character varying,
    "contact:instagram" character varying,
    "contact:phone" character varying,
    "contact:website" character varying,
    "contact:whatsapp" character varying,
    cuisine character varying,
    description character varying,
    door character varying,
    email character varying,
    emergency character varying,
    fax character varying,
    fixme character varying,
    healthcare character varying,
    "healthcare:speciality" character varying,
    name character varying,
    "name:de" character varying,
    "name:en" character varying,
    "name:es" character varying,
    "name:fr" character varying,
    "name:pt" character varying,
    official_name character varying,
    opening_hours character varying,
    operator character varying,
    "operator:type" character varying,
    "operator:wikidata" character varying,
    "operator:wikipedia" character varying,
    phone character varying,
    "ref:sisa_codigo" character varying,
    "ref:sisa_tipologia" character varying,
    "roof:shape" character varying,
    short_name character varying,
    source character varying,
    website character varying,
    wheelchair character varying,
    wikidata character varying,
    "@geometry" character varying
);

-- Clave primaria e índices espaciales para salud
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'hospitales_pkey') THEN
        ALTER TABLE entrerios.salud ADD CONSTRAINT hospitales_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_salud_geom ON entrerios.salud USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.rios
-- Descripción: Red hidrográfica: ríos, arroyos y cursos de agua (OpenStreetMap)
-- Geometría: LineString (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.rios (
    id character varying NOT NULL,
    geom geometry(LineString,4326),
    "@id" character varying,
    "addr:city" character varying,
    "addr:postcode" character varying,
    admin_level character varying,
    alt_name character varying,
    boat character varying,
    boundary character varying,
    canoe character varying,
    description character varying,
    fixme character varying,
    intermittent character varying,
    kayak character varying,
    layer character varying,
    motorboat character varying,
    name character varying,
    "name:br" character varying,
    "name:ca" character varying,
    "name:cy" character varying,
    "name:en" character varying,
    "name:eu" character varying,
    "name:fr" character varying,
    "name:he" character varying,
    "name:kn" character varying,
    riesgos character varying,
    route character varying,
    seasonal character varying,
    ship character varying,
    short_name character varying,
    source character varying,
    "source:boundary" character varying,
    tidal character varying,
    tunnel character varying,
    waterway character varying,
    width character varying,
    wikidata character varying,
    wikipedia character varying
);

-- Clave primaria e índices espaciales para rios
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rios_pkey') THEN
        ALTER TABLE entrerios.rios ADD CONSTRAINT rios_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_rios_geom ON entrerios.rios USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.lagunas
-- Descripción: Cuerpos de agua superficiales: lagunas, lagos y embalses (OpenStreetMap)
-- Geometría: MultiPolygon (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.lagunas (
    id character varying NOT NULL,
    geom geometry(MultiPolygon,4326),
    "@id" character varying,
    access character varying,
    "addr:city" character varying,
    "addr:postcode" character varying,
    "addr:street" character varying,
    alt_name character varying,
    "alt_name:cs" character varying,
    basin character varying,
    boat character varying,
    canoe character varying,
    check_date date,
    description character varying,
    destination character varying,
    fixme character varying,
    golf character varying,
    intermittent character varying,
    landuse character varying,
    leisure character varying,
    length character varying,
    lit character varying,
    location character varying,
    man_made character varying,
    name character varying,
    "name:af" character varying,
    "name:ar" character varying,
    "name:ca" character varying,
    "name:cs" character varying,
    "name:de" character varying,
    "name:el" character varying,
    "name:en" character varying,
    "name:eo" character varying,
    "name:es" character varying,
    "name:fa" character varying,
    "name:fr" character varying,
    "name:he" character varying,
    "name:hi" character varying,
    "name:hu" character varying,
    "name:it" character varying,
    "name:ja" character varying,
    "name:ko" character varying,
    "name:nl" character varying,
    "name:pa" character varying,
    "name:pt" character varying,
    "name:ru" character varying,
    "name:uk" character varying,
    "name:zh" character varying,
    "natural" character varying,
    note character varying,
    official_name character varying,
    operator character varying,
    place character varying,
    reservoir_type character varying,
    salt character varying,
    "seamark:harbour:category" character varying,
    "seamark:type" character varying,
    ship character varying,
    "short_name:cs" character varying,
    "short_name:hu" character varying,
    source character varying,
    "source:position" character varying,
    "source:tracer" character varying,
    "source:zoomlevel" character varying,
    swimming_pool character varying,
    tidal character varying,
    type character varying,
    water character varying,
    "@relations" json,
    wetland character varying,
    wikidata character varying,
    wikimedia_commons character varying,
    wikipedia character varying
);

-- Clave primaria e índices espaciales para lagunas
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'lagunas_pkey') THEN
        ALTER TABLE entrerios.lagunas ADD CONSTRAINT lagunas_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_lagunas_geom ON entrerios.lagunas USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.rutas
-- Descripción: Red vial principal: autopistas, autovías, rutas nacionales y provinciales (OpenStreetMap)
-- Geometría: LineString (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.rutas (
    id character varying NOT NULL,
    geom geometry(LineString,4326),
    "@id" character varying,
    access character varying,
    admin_level character varying,
    alt_name character varying,
    bicycle character varying,
    boundary character varying,
    bridge character varying,
    "bridge:name" character varying,
    "bridge:structure" character varying,
    "bridge:support" character varying,
    "change:lanes" character varying,
    "change:lanes:backward" character varying,
    "change:lanes:forward" character varying,
    "check_date:surface" date,
    "construction:highway" character varying,
    covered character varying,
    cutting character varying,
    cycleway character varying,
    "cycleway:left" character varying,
    "cycleway:right" character varying,
    description character varying,
    destination character varying,
    "destination:backward" character varying,
    "destination:forward" character varying,
    "destination:lanes" character varying,
    "destination:lanes:backward" character varying,
    "destination:lanes:forward" character varying,
    "destination:ref" character varying,
    electrified character varying,
    email character varying,
    embankment character varying,
    embedded_rails character varying,
    fixme character varying,
    foot character varying,
    gauge character varying,
    hazard character varying,
    hgv character varying,
    highway character varying,
    horse character varying,
    int_name character varying,
    junction character varying,
    lane_markings character varying,
    lanes character varying,
    "lanes:backward" character varying,
    "lanes:forward" character varying,
    layer character varying,
    lit character varying,
    loc_name character varying,
    maxheight character varying,
    "maxheight:signed" character varying,
    maxspeed character varying,
    "maxspeed:bus" character varying,
    "maxspeed:conditional" character varying,
    "maxspeed:forward" character varying,
    "maxspeed:hgv" character varying,
    "maxspeed:lanes" character varying,
    "maxspeed:lanes:backward" character varying,
    "maxspeed:lanes:forward" character varying,
    "maxspeed:type" character varying,
    "maxweight:signed" character varying,
    minspeed character varying,
    motorroad character varying,
    name character varying,
    "name:en" character varying,
    note character varying,
    official_name character varying,
    old_name character varying,
    old_ref character varying,
    oneway character varying,
    "oneway:bicycle" character varying,
    overtaking character varying,
    parking character varying,
    "parking:both" character varying,
    "parking:lane:both" character varying,
    "parking:lane:left" character varying,
    "parking:lane:right" character varying,
    "parking:lane:right:parallel" character varying,
    "parking:left" character varying,
    "parking:right" character varying,
    "parking:right:orientation" character varying,
    placement character varying,
    "placement:forward" character varying,
    railway character varying,
    ref character varying,
    "seamark:bridge:category" character varying,
    short_name character varying,
    shoulder character varying,
    sidewalk character varying,
    "sidewalk:left" character varying,
    "sidewalk:right" character varying,
    smoothness character varying,
    source character varying,
    "source:maxspeed" character varying,
    "source:minspeed" character varying,
    "source:surface" character varying,
    surface character varying,
    toll character varying,
    "toll:backward" character varying,
    traffic_calming character varying,
    trail_visibility character varying,
    transit character varying,
    "transit:lanes" character varying,
    tunnel character varying,
    "turn:lanes" character varying,
    "turn:lanes:backward" character varying,
    "turn:lanes:forward" character varying,
    usage character varying,
    width character varying,
    wikidata character varying,
    wikipedia character varying
);

-- Clave primaria e índices espaciales para rutas
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'rutas_pkey') THEN
        ALTER TABLE entrerios.rutas ADD CONSTRAINT rutas_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_rutas_geom ON entrerios.rutas USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.calles
-- Descripción: Red vial urbana y secundaria (OpenStreetMap)
-- Geometría: LineString (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.calles (
    id character varying NOT NULL,
    geom geometry(LineString,4326),
    "@id" character varying,
    access character varying,
    admin_level character varying,
    alt_name character varying,
    bicycle character varying,
    boundary character varying,
    bridge character varying,
    "check_date:surface" date,
    covered character varying,
    cycleway character varying,
    "cycleway:left" character varying,
    "cycleway:right" character varying,
    description character varying,
    email character varying,
    embankment character varying,
    fixme character varying,
    foot character varying,
    highway character varying,
    horse character varying,
    incline character varying,
    junction character varying,
    lane_markings character varying,
    lanes character varying,
    layer character varying,
    lit character varying,
    loc_name character varying,
    locked character varying,
    man_made character varying,
    maxheight character varying,
    maxspeed character varying,
    "maxspeed:type" character varying,
    name character varying,
    noname character varying,
    note character varying,
    official_name character varying,
    old_name character varying,
    old_ref character varying,
    oneway character varying,
    "parking:both:fee:conditional" character varying,
    "parking:lane:both" character varying,
    ref character varying,
    short_name character varying,
    sidewalk character varying,
    smoothness character varying,
    sorting_name character varying,
    source character varying,
    "source:surface" character varying,
    surface character varying,
    width character varying
);

-- Clave primaria e índices espaciales para calles
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'calles_pkey') THEN
        ALTER TABLE entrerios.calles ADD CONSTRAINT calles_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_calles_geom ON entrerios.calles USING gist (geom);

-- ----------------------------------------------------------------------------
-- Tabla: entrerios.suelo
-- Descripción: Aptitud y cobertura de uso del suelo (INTA)
-- Geometría: MultiPolygon (EPSG:4326)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS entrerios.suelo (
    id integer NOT NULL,
    geom geometry(MultiPolygon,4326),
    ogc_fid integer,
    layer character varying,
    map_name character varying,
    id_0 bigint,
    simb character varying,
    nombre character varying,
    serie_1 character varying,
    serie_2 character varying,
    serie_3 character varying,
    serie_4 character varying,
    serie_5 character varying,
    serie_6 character varying,
    serie_7 character varying,
    fase_1 character varying,
    fase_2 character varying,
    fase_3 character varying,
    fase_4 character varying,
    fase_5 character varying,
    fase_6 character varying,
    fase_7 character varying,
    t_1 character varying,
    t_2 character varying,
    t_3 character varying,
    t_4 character varying,
    t_5 character varying,
    t_6 character varying,
    t_7 character varying,
    porc_1 bigint,
    porc_2 bigint,
    porc_3 bigint,
    porc_4 bigint,
    porc_5 bigint,
    porc_6 bigint,
    porc_7 bigint,
    pais_simb character varying,
    pais_nomb character varying,
    pos_1 character varying,
    pos_2 character varying,
    pos_3 character varying,
    pos_4 character varying,
    pos_5 character varying,
    pos_6 character varying,
    pos_7 character varying,
    l_1 character varying,
    l_2 character varying,
    l_3 character varying,
    l_4 character varying,
    l_5 character varying,
    l_6 character varying,
    l_7 character varying,
    ipc bigint,
    ipcp bigint,
    eros_act character varying,
    eros_pot character varying,
    depart character varying,
    link_ser_1 character varying,
    link_ser_2 character varying,
    link_ser_3 character varying,
    link_ser_4 character varying,
    link_ser_5 character varying,
    link_ser_6 character varying,
    closed character varying,
    border_sty character varying,
    border_col character varying,
    border_wid integer,
    fill_style character varying,
    link_ser_7 character varying,
    uso_suelo character varying(20)
);

-- Clave primaria e índices espaciales para suelo
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'suelo_pkey') THEN
        ALTER TABLE entrerios.suelo ADD CONSTRAINT suelo_pkey PRIMARY KEY (id);
    END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_suelo_geom ON entrerios.suelo USING gist (geom);
CREATE INDEX IF NOT EXISTS sidx_suelo_geom ON entrerios.suelo USING gist (geom);
