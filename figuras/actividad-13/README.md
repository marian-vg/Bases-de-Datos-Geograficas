# Activity 13 — QGIS figures

Open `actividad-13-composiciones.qgz` in QGIS. It contains three native print
layouts, in report order: department locator, query 1, and query 2.

Keep the project together with `actividad-13-resultados.gpkg` and
`../norte.svg`. All layer paths are relative; opening the project does not
require database credentials or a running PostGIS server.

The PNGs are exports of those layouts at 360 dpi.

To regenerate data, project, and PNGs from the current SQL, start the
repository's PostGIS service (with `shapes/` loaded) and run:

```sh
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/actividad-13/renderizar-actividad-13.py
```

The renderer requires the system PyQGIS installation. It executes the two
queries in `actividades-sql/actividad-13.sql` inside read-only transactions and
writes only artifacts in this directory.

The Río Uruguay is drawn as the OSM water surface `relation/1101792`
(`entrerios.lagunas`), clipped to Concordia. Distance checks from the three
chosen receiving centers to that surface (geography): Asistencia Municipal
2,011.32 m; Instituto Médico Quirúrgico Garat 2,020.31 m; DIMEC 2,139.32 m.
These explain the apparent proximity to the 2 km boundary in the query 1 map;
they are not travel distances.

The orientation symbol is the shared `figuras/norte.svg`; see
`figuras/PROCEDENCIA-SVG.md` and `figuras/LICENCIA-QGIS-SVG.txt`.
