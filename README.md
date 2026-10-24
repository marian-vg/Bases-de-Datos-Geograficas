# Bases de Datos Geográficas — TP2

Fuente de verdad: [enunciado del TP](TP2_2026_BDGeograficas.md).
Una sola base (`bdg_entrerios`) y un solo modelo de datos: el esquema `entrerios`
definido en `actividades-sql/02-crear-tablas.sql`, cargado con las capas de `shapes/`.

## Estructura

| Carpeta | Contenido |
|---|---|
| `actividades-sql/` | `00`–`02`: creación de base, esquema y tablas. `actividad-NN.sql`: un script por actividad con todos sus subítems. |
| `shapes/` | Capas fuente (OSM, IGN, INTA) que se cargan en `entrerios`. |
| `scripts/` | `preparar.sh` (levanta Docker), `importar.sh` (carga `shapes/` + actividad 6), `psql.sh` (consola). |
| `figuras/` | Proyectos QGIS, mapas y scripts que los regeneran, por actividad. |
| `docker/` | Inicialización del contenedor: crea el modelo con `01` y `02`. |

## Con Docker

```bash
./scripts/preparar.sh                                  # levanta PostGIS y pgAdmin; crea .env si falta
./scripts/importar.sh                                  # carga shapes/ y ejecuta la actividad 6
./scripts/psql.sh < actividades-sql/actividad-07.sql   # ejecutar una actividad
./scripts/psql.sh                                      # consola SQL; salir con \q
```

## Sin Docker

Con PostgreSQL + PostGIS propios, en este orden:

1. `00-crear-base-de-datos.sql` conectado a la base `postgres`.
2. `01-crear-esquema.sql` y `02-crear-tablas.sql` conectado a `bdg_entrerios`.
3. Cargar `shapes/` en las tablas existentes con los mismos `ogr2ogr -append` de `scripts/importar.sh`.
4. `actividad-06.sql` (controles y `ST_MakeValid`) y luego el resto de las actividades.

## Conexión

Base: **`bdg_entrerios`** · Usuario: **`postgres`** · Contraseña: **`POSTGRES_PASSWORD` en `.env`** (no compartir).

| Cliente | Servidor | Puerto |
|---|---|---|
| QGIS / psql del host | `127.0.0.1` | `5434` |
| pgAdmin dentro de Docker | `postgres` | `5432` |

- **pgAdmin:** <http://127.0.0.1:5050> → servidor **TP Bases Geograficas** → **Tools → Query Tool**.
- **QGIS:** **Administrador de fuentes de datos → PostgreSQL → Nueva**, con los datos de arriba; capas del esquema `entrerios`.

## Datos

- Todas las capas están en **EPSG:4326**. Para metros usar `geom::geography` o reproyectar.
- Localidades: `ciudades_er.gpkg` de la cátedra, porque el export OSM propio no cubría Concordia.
- Calles: solo departamento Concordia.
- El Río Uruguay en Concordia es la superficie de agua `relation/1101792` de `entrerios.lagunas`.
- Al cargar se descartan 3 líneas del export de lagunas; la actividad 6 corrige 2 lagunas y 7 polígonos de suelo inválidos.

## Apagar y conservar

```bash
docker compose stop                # conserva los datos
docker compose exec -T postgres pg_dump -U postgres -d bdg_entrerios -Fc > "backups/bdg_$(date +%F_%H%M%S).dump"
```

`docker compose down -v` **borra la base**. Para recrearla desde cero: `down -v`, `preparar.sh`, `importar.sh`.
