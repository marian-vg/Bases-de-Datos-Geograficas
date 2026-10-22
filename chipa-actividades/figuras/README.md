# Activity 13 — QGIS figures

Open `actividad-13-composiciones.qgz` in QGIS. It contains three native print
layouts, in report order: department locator, query 1, and query 2.

Keep the project together with `actividad-13-resultados.gpkg` and `norte.svg`.
All layer paths are relative; opening the project does not require database
credentials or a running PostGIS server.

The PNGs are exports of those layouts at 360 dpi. The former composite
`actividad-13-derivacion-sanitaria.png` is superseded and is not in the report.

To regenerate data, project, and PNGs from the current SQL, start the repository's
existing PostGIS service and run:

```sh
QT_QPA_PLATFORM=offscreen /usr/bin/python3 chipa-actividades/figuras/renderizar-actividad-13.py
```

The renderer requires the system PyQGIS installation. It executes the two
queries in `chipa-actividades/actividad-13.sql` inside read-only transactions and
writes only artifacts in this directory. It does not alter the existing
`chipa-actividades/concordia.qgz` project or SQL scripts.

Distance checks from the three chosen receiving centers to the nearest
intersecting Río Uruguay segment (geography): MEDICEF 2,134.11 m; DIMEC 2,303.37 m;
Instituto Médico Quirúrgico Garat 2,349.38 m. These explain the apparent proximity
to the 2 km boundary in the query 1 map; they are not travel distances.

The orientation symbol is the unmodified QGIS stock `NorthArrow_07.svg`, a
cardinal compass rose rendered black with native picture settings. See
`PROCEDENCIA-SVG.md` and `LICENCIA-QGIS-SVG.txt` for provenance and license.
