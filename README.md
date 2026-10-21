# Bases de Datos Geográficas — entorno listo

PostGIS y pgAdmin funcionan en Docker; QGIS está instalado en Linux Mint.
Fuente de verdad: [enunciado del TP](TP2_2026_BDGeograficas.md).

## Arrancar y consultar

Desde este directorio, con Docker y Compose disponibles:

```bash
./scripts/preparar.sh              # inicia servicios; crea .env si falta
./scripts/importar.sh              # carga los archivos locales de shapes/
./chipa-actividades/importar-capas-profe.sh  # carga Capas_Profe/ aparte (usa ogr2ogr)
./scripts/psql.sh                  # consola SQL; salir con \q
./scripts/psql.sh < mi-consulta.sql
./scripts/psql.sh < sql/verificar.sql
```

```sql
SELECT nombre FROM entrerios.departamentos;
SELECT nombre, atributos->>'amenity' AS tipo FROM entrerios.salud LIMIT 10;
```

## Conexión

Base: **`bdg_entrerios`** · Usuario: **`postgres`**.
Contraseña: **`POSTGRES_PASSWORD` en `.env`**. No compartir ese archivo.

| Cliente | Servidor | Puerto |
|---|---|---|
| QGIS / psql del host | `127.0.0.1` | `5434` |
| pgAdmin dentro de Docker | `postgres` | `5432` |

- **pgAdmin:** <http://127.0.0.1:5050> → servidor **TP Bases Geograficas** → contraseña PostgreSQL → base → **Tools → Query Tool**. Modo escritorio local, sin login; no exponerlo a otras máquinas.
- **QGIS:** ejecutar `qgis` → **Administrador de fuentes de datos → PostgreSQL → Nueva** → completar conexión → agregar tablas de `entrerios` (`geom`). También se pueden arrastrar `.geojson` y `.gpkg` de `shapes/`.
- **Aviso conocido de QGIS:** «Open Sans font installation failed». QGIS abre; el aviso no fue investigado ni corregido.

## Datos: lo importante

- Trabajo en **`entrerios`**: columnas `id`, `nombre`, `atributos` (JSONB) y `geom`; no coinciden exactamente con el dump antiguo. Consultar atributos con `atributos->>'campo'`. Originales preservados en **`fuentes`**.
- Las capas usan **EPSG:4326**. Para metros o superficies usar `geom::geography` o reproyectar; no calcular en grados. Control inicial: sin geometrías nulas ni inválidas.
- `entrerios.departamentos` conserva solo Concordia y `entrerios.calles` sigue vacía. Las capas nuevas del profesor están separadas en **`fuentes_profe`**: 17 departamentos, 162 ciudades, ríos, calles y rutas. Las actividades 7/13 usan estos límites y ríos, junto a salud/lagunas de `entrerios`.
- El SHP suelto de `shapes/` sigue incompleto. El conjunto completo de `Capas_Profe/` permite importar los 17 departamentos con CRS declarado y nombres originales. Algunos límites tienen micro-solapes: advertencias y diagnóstico en `actividad-7.sql`, sin repararlos automáticamente.
- Localidades poligonales pasan a punto interior; áreas se reparan con `ST_MakeValid`. Tres líneas del export de lagunas quedan solo en `fuentes`, no se convierten en superficie. La carga no recorta al departamento.
- **Reimportar conserva tablas existentes:** no duplica, sobrescribe ni actualiza fuentes modificadas. Para recargar, respaldar y decidir qué reemplazar. Si se interrumpe la carga, comprobar registros antes de reutilizarla.
- Copiar `shapes/` y `Capas_Profe/` al replicar el entorno. No ejecutar ciegamente los SQL antiguos: incluyen locale Windows y recreación del esquema.

Para las actividades, ejecutar `actividad-7.sql` y `actividad-13.sql` de `chipa-actividades/`; abrir luego `concordia.qgz` en QGIS. Las explicaciones y limitaciones están comentadas en los SQL.

## Apagar y conservar

```bash
docker compose stop               # conserva los datos
./scripts/preparar.sh              # vuelve a iniciar sin perder volúmenes
docker compose ps                 # comprueba estado
mkdir -p backups
docker compose exec -T postgres pg_dump -U postgres -d bdg_entrerios -Fc > "backups/bdg_$(date +%F_%H%M%S).dump"
```

Datos persistentes en `bd-geograficas_postgres_data` y `bd-geograficas_pgadmin_data`.
`docker compose down` elimina contenedores, pero conserva los volúmenes; `./scripts/preparar.sh` los reutiliza.
**No usar `docker compose down -v`: borra los volúmenes y la base.**
Conservar `.env`; editarla no cambia la contraseña de una base ya inicializada.
Puertos accesibles solo desde esta máquina; ajustables en `.env` si hay conflicto.
