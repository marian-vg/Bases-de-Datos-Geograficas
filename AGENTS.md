Repositorio para el trabajo práctico de Bases de Datos Geográficas 

Ante cualquier duda, consultar como fuente de la verdad [el enunciado del trabajo práctico](/TP2_2026_BDGeograficas.md) 

Se requiere QGis y PostGis para trabajar en el tp

Realizar cualquier consulta por el usuario de forma más simple y sencilla. No se busca el mayor performance, se busca la mejor legibilidad y que el código sea lo más educativo posible.
No abusar de vistas a no ser que la consigna solicite lo contrario, mantener consultas independientes por actividad, relacionadas si cabe, y mantener un estilo básico de SQL sin aplicar funciones raras o muy avanzadas.

El trabajo práctico no solo consta de entregar estos scripts, también anexa un [informe de entrega](https://docs.google.com/document/d/1Zs542p1WipYRjF2moDrR_z9TG0KFjmQ1CMxL_4-9h6w/edit?tab=t.0#heading=h.sldcxxtnkx91), el cual tenés disponible su enlace en caso de que el usuario te solicite revisarlo o modificarlo. Solo si el usuario lo pide.

## Modelo de datos (único)

- Hay **una sola base** (`bdg_entrerios`) y **un solo modelo**: el esquema `entrerios` de `actividades-sql/02-crear-tablas.sql`, con las columnas originales de cada capa (`nam`, `name`, `amenity`, `highway`, `ref`, `waterway`, `ipc`, ...).
- Toda actividad consulta **solo** las tablas `entrerios.*`: `departamentos`, `localidades`, `rutas`, `rios`, `lagunas`, `calles`, `salud`, `suelo`. No crear otros esquemas (`capas`, `fuentes`, por integrante, etc.) ni tablas paralelas con otro formato.
- Los datos se cargan **únicamente** desde `shapes/`. Si falta información, se agrega el archivo a `shapes/` y su carga a `scripts/importar.sh`; nunca se importa por fuera ni se adapta el modelo a una capa local.
- Si una capa necesita columnas nuevas, se cambian en `02-crear-tablas.sql` (y se recrea la base), no con tablas aparte.

## Organización

- `actividades-sql/`: `00`–`02` crean base, esquema y tablas; `actividad-NN.sql` es **un script por actividad** con todos sus subítems. No crear carpetas por integrante.
- `figuras/actividad-NN/`: proyectos QGIS, PNG y el script que los regenera desde la base.
- Antes de commitear, cada script de `actividades-sql/` debe ejecutarse sin errores contra una base recién creada.

## Cómo levantar la base

- **Con Docker:** `./scripts/preparar.sh` (el contenedor crea la base y ejecuta `01` y `02`) y luego `./scripts/importar.sh` (carga `shapes/` y ejecuta `actividad-06.sql`). Para empezar de cero: `docker compose down -v`.
- **Sin Docker:** ejecutar `00` conectado a `postgres`; `01` y `02` conectado a `bdg_entrerios`; cargar `shapes/` con los mismos `ogr2ogr -append` de `scripts/importar.sh` (o QGIS, en las tablas existentes); luego `actividad-06.sql`.



