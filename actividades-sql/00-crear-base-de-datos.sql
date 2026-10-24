-- ============================================================================
-- TRABAJO PRÁCTICO N° 2: BASES DE DATOS GEOGRÁFICAS
-- Creación de la Base de Datos Espacial
-- Base de datos: bdg_entrerios
-- ============================================================================

-- Solo para trabajar SIN Docker: con Docker la base la crea el contenedor
-- (variable POSTGRES_DB) y este script no hace falta.
-- Orden: 00 (conectado a la base postgres) -> 01 y 02 (conectado a bdg_entrerios)
-- -> carga de shapes/ -> actividad-06.sql.

-- 1. Creación de la base de datos (ejecutar conectado a la base postgres/mantenimiento)
CREATE DATABASE bdg_entrerios
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

COMMENT ON DATABASE bdg_entrerios IS 
'Base de datos espacial para el Trabajo Práctico N° 2 de Bases de Datos Geográficas (UADER - FCyT).';

-- 2. PostGIS y el esquema se habilitan en 01-crear-esquema.sql.
