-- ============================================================================
-- TRABAJO PRÁCTICO N° 2: BASES DE DATOS GEOGRÁFICAS
-- Creación del Esquema Espacial
-- Base de datos: bdg_entrerios
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS entrerios
    AUTHORIZATION postgres;

COMMENT ON SCHEMA entrerios IS
'Esquema principal para el Trabajo Práctico N° 2 de Bases de Datos Geográficas (Entre Ríos).';

-- Permite escribir las tablas sin el prefijo entrerios. en pgAdmin y QGIS.
ALTER DATABASE bdg_entrerios SET search_path TO entrerios, public;
