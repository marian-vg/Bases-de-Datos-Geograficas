-- ============================================================================
-- TRABAJO PRÁCTICO N° 2: BASES DE DATOS GEOGRÁFICAS
-- Creación del Esquema Espacial
-- Base de datos: bdg_entrerios
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS entrerios
    AUTHORIZATION postgres;

COMMENT ON SCHEMA entrerios IS 
'Esquema principal para el Trabajo Práctico N° 2 de Bases de Datos Geográficas (Entre Ríos).';
