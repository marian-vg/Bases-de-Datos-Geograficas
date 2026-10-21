CREATE EXTENSION IF NOT EXISTS postgis;
CREATE SCHEMA IF NOT EXISTS entrerios;
CREATE SCHEMA IF NOT EXISTS fuentes;
ALTER DATABASE bdg_entrerios SET search_path TO entrerios, public;
