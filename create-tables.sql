--
-- PostgreSQL database dump
--

\restrict VJsHDDDlaAfpBHTqmwFD2zGH3feFCPwHC77h3jlC7ay9zkSQqNTmUAqN4y8aYN1

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.0

-- Started on 2026-10-06 02:07:37

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 24 (class 2615 OID 67638)
-- Name: entrerios; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA entrerios;


ALTER SCHEMA entrerios OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 356 (class 1259 OID 68093)
-- Name: calles; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.calles (
    id character varying NOT NULL,
    geom public.geometry(LineString,4326),
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


ALTER TABLE entrerios.calles OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 67699)
-- Name: departamentos; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.departamentos (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
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


ALTER TABLE entrerios.departamentos OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 67698)
-- Name: departamentos_id_seq; Type: SEQUENCE; Schema: entrerios; Owner: postgres
--

CREATE SEQUENCE entrerios.departamentos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE entrerios.departamentos_id_seq OWNER TO postgres;

--
-- TOC entry 15159 (class 0 OID 0)
-- Dependencies: 350
-- Name: departamentos_id_seq; Type: SEQUENCE OWNED BY; Schema: entrerios; Owner: postgres
--

ALTER SEQUENCE entrerios.departamentos_id_seq OWNED BY entrerios.departamentos.id;


--
-- TOC entry 354 (class 1259 OID 67984)
-- Name: lagunas; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.lagunas (
    id character varying NOT NULL,
    geom public.geometry(MultiPolygon,4326),
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


ALTER TABLE entrerios.lagunas OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 67688)
-- Name: localidades; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.localidades (
    id character varying NOT NULL,
    geom public.geometry(Point,4326),
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


ALTER TABLE entrerios.localidades OWNER TO postgres;

--
-- TOC entry 353 (class 1259 OID 67760)
-- Name: rios; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.rios (
    id character varying NOT NULL,
    geom public.geometry(LineString,4326),
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


ALTER TABLE entrerios.rios OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 67747)
-- Name: rutas; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.rutas (
    id character varying NOT NULL,
    geom public.geometry(LineString,4326),
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


ALTER TABLE entrerios.rutas OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 68082)
-- Name: salud; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.salud (
    id character varying CONSTRAINT hospitales_id_not_null NOT NULL,
    geom public.geometry(Point,4326),
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


ALTER TABLE entrerios.salud OWNER TO postgres;

--
-- TOC entry 358 (class 1259 OID 68116)
-- Name: suelo; Type: TABLE; Schema: entrerios; Owner: postgres
--

CREATE TABLE entrerios.suelo (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
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


ALTER TABLE entrerios.suelo OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 68115)
-- Name: suelo_id_seq; Type: SEQUENCE; Schema: entrerios; Owner: postgres
--

CREATE SEQUENCE entrerios.suelo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE entrerios.suelo_id_seq OWNER TO postgres;

--
-- TOC entry 15160 (class 0 OID 0)
-- Dependencies: 357
-- Name: suelo_id_seq; Type: SEQUENCE OWNED BY; Schema: entrerios; Owner: postgres
--

ALTER SEQUENCE entrerios.suelo_id_seq OWNED BY entrerios.suelo.id;


--
-- TOC entry 14972 (class 2604 OID 67702)
-- Name: departamentos id; Type: DEFAULT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.departamentos ALTER COLUMN id SET DEFAULT nextval('entrerios.departamentos_id_seq'::regclass);


--
-- TOC entry 14973 (class 2604 OID 68119)
-- Name: suelo id; Type: DEFAULT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.suelo ALTER COLUMN id SET DEFAULT nextval('entrerios.suelo_id_seq'::regclass);


--
-- TOC entry 14993 (class 2606 OID 68100)
-- Name: calles calles_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.calles
    ADD CONSTRAINT calles_pkey PRIMARY KEY (id);


--
-- TOC entry 14978 (class 2606 OID 67705)
-- Name: departamentos departamentos_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.departamentos
    ADD CONSTRAINT departamentos_pkey PRIMARY KEY (id);


--
-- TOC entry 14990 (class 2606 OID 68089)
-- Name: salud hospitales_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.salud
    ADD CONSTRAINT hospitales_pkey PRIMARY KEY (id);


--
-- TOC entry 14988 (class 2606 OID 67991)
-- Name: lagunas lagunas_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.lagunas
    ADD CONSTRAINT lagunas_pkey PRIMARY KEY (id);


--
-- TOC entry 14976 (class 2606 OID 67695)
-- Name: localidades localidades_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.localidades
    ADD CONSTRAINT localidades_pkey PRIMARY KEY (id);


--
-- TOC entry 14985 (class 2606 OID 67767)
-- Name: rios rios_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.rios
    ADD CONSTRAINT rios_pkey PRIMARY KEY (id);


--
-- TOC entry 14982 (class 2606 OID 67754)
-- Name: rutas rutas_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.rutas
    ADD CONSTRAINT rutas_pkey PRIMARY KEY (id);


--
-- TOC entry 14998 (class 2606 OID 68122)
-- Name: suelo suelo_pkey; Type: CONSTRAINT; Schema: entrerios; Owner: postgres
--

ALTER TABLE ONLY entrerios.suelo
    ADD CONSTRAINT suelo_pkey PRIMARY KEY (id);


--
-- TOC entry 14994 (class 1259 OID 68113)
-- Name: idx_calles_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_calles_geom ON entrerios.calles USING gist (geom);


--
-- TOC entry 14979 (class 1259 OID 68108)
-- Name: idx_departamentos_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_departamentos_geom ON entrerios.departamentos USING gist (geom);


--
-- TOC entry 14986 (class 1259 OID 68112)
-- Name: idx_lagunas_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_lagunas_geom ON entrerios.lagunas USING gist (geom);


--
-- TOC entry 14974 (class 1259 OID 68109)
-- Name: idx_localidades_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_localidades_geom ON entrerios.localidades USING gist (geom);


--
-- TOC entry 14983 (class 1259 OID 68111)
-- Name: idx_rios_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_rios_geom ON entrerios.rios USING gist (geom);


--
-- TOC entry 14980 (class 1259 OID 68110)
-- Name: idx_rutas_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_rutas_geom ON entrerios.rutas USING gist (geom);


--
-- TOC entry 14991 (class 1259 OID 68114)
-- Name: idx_salud_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_salud_geom ON entrerios.salud USING gist (geom);


--
-- TOC entry 14995 (class 1259 OID 86844)
-- Name: idx_suelo_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX idx_suelo_geom ON entrerios.suelo USING gist (geom);


--
-- TOC entry 14996 (class 1259 OID 86792)
-- Name: sidx_suelo_geom; Type: INDEX; Schema: entrerios; Owner: postgres
--

CREATE INDEX sidx_suelo_geom ON entrerios.suelo USING gist (geom);


-- Completed on 2026-10-06 02:07:37

--
-- PostgreSQL database dump complete
--

\unrestrict VJsHDDDlaAfpBHTqmwFD2zGH3feFCPwHC77h3jlC7ay9zkSQqNTmUAqN4y8aYN1

