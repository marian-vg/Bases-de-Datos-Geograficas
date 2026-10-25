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

## Proyecto QGIS de entrega

Abrir **`figuras/TP2-Concordia.qgz`**. Reúne las capas y las 16 composiciones
cartográficas de las actividades; los proyectos individuales también se conservan.
Los siete GeoPackages de resultados, el símbolo de norte y su documentación de
licencia están adjuntos dentro del QGZ: no hacen falta carpetas auxiliares para
visualizar las capas locales.

- **Capas PostGIS:** las ocho tablas originales de `entrerios`, agrupadas y en
  modo de solo lectura. Para utilizarlas, levantar y cargar la base siguiendo los
  pasos anteriores. QGIS solicitará la contraseña; no está guardada en el proyecto.
  Si se usa otro servidor o puerto, ajustar la fuente de esas capas en QGIS.
- **Resultados por actividad:** 39 capas locales de los GPKG adjuntos, con su
  simbología y mapas. Se pueden consultar sin ejecutar SQL ni acceder a PostgreSQL.
  Argenmap requiere Internet.
- La conexión PostGIS consulta la base actual; los GPKG conservan los resultados
  exportados. No se actualizan automáticamente al cambiar los datos de la base.

Para visualizarlo: descomprimir la entrega, abrir el QGZ con **Ctrl+O**, desplegar
un grupo de actividad y activar solo ese grupo. Usar **Zoom a la capa** desde el
menú contextual de una capa para ajustar la vista.
Para abrir los mapas guardados, usar **Proyecto → Administrador de Composiciones…**.
Si la conexión PostGIS no está disponible, conservar esas capas como no disponibles
en el diálogo de QGIS; las capas locales y las composiciones siguen dentro del archivo.

Para volver a reunir los proyectos existentes, sin recalcular las actividades:

```bash
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/ensamblar-proyecto.py
```

Requiere PyQGIS. Conserva las conexiones PostGIS del proyecto existente; si se
genera por primera vez, necesita la base disponible. Usa la contraseña de `.env`
solo durante la ejecución. No compartir `.env` ni incluirlo en la entrega.

## Datos

- Todas las capas están en **EPSG:4326**. Para metros usar `geom::geography` o reproyectar.
- Localidades: `ciudades_er.gpkg` de la cátedra, porque el export OSM propio no cubría Concordia.
- Calles: base provincial, con etiquetas de `highways_er_completo.gpkg` y un
  suplemento de Concordia; se integran mediante `scripts/importar.sh`.
- El Río Uruguay en Concordia es la superficie de agua `relation/1101792` de `entrerios.lagunas`.
- Al cargar se descartan 3 líneas del export de lagunas; la actividad 6 corrige 2 lagunas y 7 polígonos de suelo inválidos.

## Apagar y conservar

```bash
docker compose stop                # conserva los datos
docker compose exec -T postgres pg_dump -U postgres -d bdg_entrerios -Fc > "backups/bdg_$(date +%F_%H%M%S).dump"
```

`docker compose down -v` **borra la base**. Para recrearla desde cero: `down -v`, `preparar.sh`, `importar.sh`.
