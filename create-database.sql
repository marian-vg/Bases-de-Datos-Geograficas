-- ============================================================================
-- TRABAJO PRÁCTICO N° 2: BASES DE DATOS GEOGRÁFICAS
-- Creación de la Base de Datos Espacial
-- Base de datos: bdg_entrerios
-- ============================================================================

-- 1. Creación de la base de datos (ejecutar conectado a la base postgres/mantenimiento)
CREATE DATABASE bdg_entrerios
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE bdg_entrerios IS 
'Base de datos espacial para el Trabajo Práctico N° 2 de Bases de Datos Geográficas (UADER - FCyT).';

-- 2. Habilitación de PostGIS y configuración de búsqueda:
-- \c bdg_entrerios
-- CREATE EXTENSION IF NOT EXISTS postgis;
-- ALTER DATABASE bdg_entrerios SET search_path TO "$user", public, entrerios;
