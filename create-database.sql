-- Database: bdg_entrerios

-- DROP DATABASE IF EXISTS bdg_entrerios;

CREATE DATABASE bdg_entrerios
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'Spanish_Argentina.1252'
    LC_CTYPE = 'Spanish_Argentina.1252'
    LOCALE_PROVIDER = 'libc'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

ALTER DATABASE bdg_entrerios
    SET search_path TO "$user", public, topology, tiger;