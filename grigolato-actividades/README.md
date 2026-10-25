# Actividades 8 y 11 — Grigolato

Este directorio contiene la resolución completa de las actividades asignadas para el **Trabajo Práctico N° 2 de Bases de Datos Geográficas** (Cátedra Bases de Datos Avanzadas - Lic. en Sistemas de Información).

* **Departamento de Estudio:** Concordia
* **Sistema Métrico de Referencia:** EPSG:5343 (POSGAR 07 / Argentina Faja 5)
* **Esquemas utilizados:** `capas` y `entrerios`

---

## Estructura de Archivos

```text
grigolato-actividades/
├── README.md                               # Este instructivo general
├── actividad-8/                            # Rutas y accesibilidad sanitaria
│   ├── 01_red_vial_principal.sql          # 8.1. Rutas nacionales y provinciales
│   ├── 02_longitud_rutas.sql               # 8.2. Kilómetros por ruta y vista espacial
│   ├── 03_establecimientos_salud.sql       # 8.3. Centros de salud y distribución
│   ├── 04_localidad_mas_alejada.sql        # 8.4. Localidad más aislada (cálculo métrico)
│   ├── 05_cobertura_sanitaria.sql          # 8.5. Buffer 5 km y localidades excluidas
│   ├── actividad_8_completa.sql            # Script unificado de la Actividad 8
│   ├── test_actividad_8.sql                # Pruebas automatizadas de integridad
│   ├── actividad_8_mapa.png                # Mapa cartográfico de la Actividad 8
│   └── INFORME_ACTIVIDAD_8.md              # Documentación técnica e informe para PDF
└── actividad-11/                           # Calles, OpenStreetMap y Argenmap
    ├── 01_densidad_vial_departamental.sql  # 11.1. Comparación con promedio provincial
    ├── 02_densidad_vial_localidad.sql      # 11.2. Densidad vial con buffer de 2 km
    ├── 03_categorias_calles.sql            # 11.3. Vías primary y secondary
    ├── 04_comparacion_argenmap.sql         # 11.4. Cruces hídricos y comparativa IGN
    ├── actividad_11_completa.sql           # Script unificado de la Actividad 11
    ├── test_actividad_11.sql               # Pruebas automatizadas de integridad
    ├── actividad_11_mapa1.png              # Mapa 1: Trama vial y densidades urbanas
    ├── actividad_11_mapa2.png              # Mapa 2: Superposición con Argenmap (IGN)
    └── INFORME_ACTIVIDAD_11.md             # Documentación técnica e informe para PDF
```

---

## Cómo ejecutar las consultas

### Opción A: Desde pgAdmin (Recomendada)
1. Abrir pgAdmin y conectarse a la base de datos `bdg_entrerios`.
2. Abrir la herramienta de consultas (**Tools → Query Tool**).
3. Abrir y ejecutar:
   - `actividad-8/actividad_8_completa.sql`
   - `actividad-11/actividad_11_completa.sql`
4. Para validar la correcta ejecución, abrir y correr los scripts de prueba:
   - `actividad-8/test_actividad_8.sql`
   - `actividad-11/test_actividad_11.sql`
   *(En la pestaña "Messages" deberán figurar todos los mensajes de `TEST OK`).*

### Opción B: Desde la consola bash / PowerShell
Si tenés el contenedor de PostgreSQL iniciado:
```bash
# Para la actividad 8
./scripts/psql.sh < grigolato-actividades/actividad-8/actividad_8_completa.sql
./scripts/psql.sh < grigolato-actividades/actividad-8/test_actividad_8.sql

# Para la actividad 11
./scripts/psql.sh < grigolato-actividades/actividad-11/actividad_11_completa.sql
./scripts/psql.sh < grigolato-actividades/actividad-11/test_actividad_11.sql
```

---

## Vistas Espaciales disponibles para QGIS

Al ejecutar los scripts, se generan automáticamente en el esquema `entrerios` las siguientes vistas listas para arrastrar y soltar al lienzo de QGIS:

### Actividad 8
* `entrerios.vw_act8_rutas_concordia`: Rutas recortadas a los límites de Concordia.
* `entrerios.vw_act8_salud_concordia`: Puntos de hospitales y clínicas.
* `entrerios.vw_act8_lineas_aislamiento`: Vectores que unen cada localidad con su hospital más próximo.
* `entrerios.vw_act8_buffer_salud_5km`: Polígono de cobertura sanitaria de 5 km.
* `entrerios.vw_act8_localidades_fuera_cobertura`: Puntos de localidades aisladas fuera del buffer.

### Actividad 11
* `entrerios.vw_act11_densidad_localidades`: Polígonos de 2 km alrededor de cada pueblo coloreables por densidad de calles.
* `entrerios.vw_act11_primary_secondary_concordia`: Red vial principal y secundaria.
* `entrerios.vw_act11_calles_concordia`: Malla vial completa de Concordia.
* `entrerios.vw_act11_cruces_hidricos_concordia`: Puntos donde las vías cruzan ríos o arroyos (puentes y pasos).
