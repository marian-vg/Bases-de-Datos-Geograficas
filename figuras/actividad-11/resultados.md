# Actividad 11 — resultados y criterio

Resultados del 25/10/2026 sobre `bdg_entrerios`, con 35.299 calles provinciales
integradas. Consultas: `actividades-sql/actividad-11.sql`.

## 11.1. Comparación departamental

Concordia tiene **2433,566 km** de calles registradas, frente a un promedio
aritmético de **2143,036 km** entre los **17 departamentos**, incluido Concordia.
Se recortó cada línea al departamento antes de medirla en EPSG:5347.
Las calles sin `highway` también participan. Los tramos sobre límites pueden
contribuir a ambos departamentos. No es una medición de todos los caminos reales.

## 11.2. Densidad por localidad

Se utilizaron las áreas urbanas cartografiadas por INTA como aproximación a la
superficie de las localidades. El ranking corresponde a las áreas identificadas
en esa fuente; las localidades sin correspondencia no pudieron evaluarse.

Las partes de una misma área se unieron antes de calcular la superficie
(Concordia tiene siete). Tanto el área como las calles se recortaron al
departamento. El indicador es km de calles dentro del área / km² de esa misma
área. Se ordenó por la densidad sin redondear.

| Localidad OSM | Área (km²) | Calles (km) | Densidad (km/km²) |
|---|---:|---:|---:|
| La Criolla | 0,5993 | 11,433 | 19,075 |
| Colonia Ayui | 0,1746 | 3,247 | 18,597 |
| Los Charrúas | 2,0440 | 30,532 | 14,937 |
| Concordia | 40,4542 | 575,122 | 14,217 |
| Osvaldo Magnasco | 0,4056 | 5,654 | 13,938 |
| Puerto Yeruá | 2,2669 | 31,129 | 13,732 |
| Nueva Escocia | 0,9222 | 11,123 | 12,061 |
| Pedernal | 0,2467 | 2,785 | 11,289 |
| Yeruá | 0,2307 | 1,905 | 8,257 |
| Calabacillas | 0,2641 | 2,033 | 7,699 |
| Benito Legerén | 0,9746 | 6,670 | 6,844 |

**La Criolla tiene la mayor densidad del universo evaluado**, no un máximo
demostrado entre las 14 localidades sin excepciones.

Correspondencias por nombre y ubicación: Calabacillas → Calabacilla,
Colonia Ayui → Colonia Ayuí y Yeruá → Estación Yeruá. Los puntos de Benito
Legerén y Pedernal están apenas fuera de sus polígonos homónimos (unos 157 m
y 3 m), por lo que no se exigió contención exacta del punto.

**Sin área propia identificada:** Estancia Grande, Villa Adela y Las Tejas.
Las últimas dos caen dentro de polígonos llamados Concordia: no se les asignó
esa superficie compartida como si fueran áreas independientes. La ausencia de
área queda como `NULL`, nunca como densidad cero. Las áreas INTA sin localidad
OSM correspondiente no se agregan al ranking.

## 11.3. Categorías registradas

- `primary`: **32,784 km**.
- `secondary`: **96,271 km**.
- Dentro de Concordia hay **22 de 3796 tramos sin highway**, equivalentes a
  **34,719 km**. No se les inventó categoría ni se los excluyó de 11.1 o 11.2.

## 11.4. Comparación visual con Argenmap

Se generaron tres composiciones con calles de la base en magenta, tramos con
`bridge = yes` en azul y Argenmap como fondo, consultado el 25/10/2026:

- **Centro urbano:** las cuadrículas coinciden en gran parte a esta escala.
  Hay diferencias de detalle en conexiones y vías menores. La superposición no
  permite establecer por sí sola cuál representación tiene mayor precisión.
- **Entorno rural de Pedernal:** se ven caminos con separación y trazado
  irregulares. Argenmap muestra además la RN14 sin la superposición magenta de
  `calles`. Es una diferencia entre la selección de capas: las rutas principales
  también se estudian por separado en `entrerios.rutas`, no prueba que OSM omita
  la ruta. No todas las líneas visibles del fondo son calles: hay ferrocarril.
- **Puente Alvear:** el tramo azul acompaña el cruce del arroyo Yuquerí Grande
  representado en el fondo. Esto permite ubicar el cruce, no comprobar el estado
  del puente, su capacidad ni la seguridad del paso.

Las diferencias pueden depender de selección, fecha, escala de visualización y
generalización cartográfica. Argenmap acredita IGN + OpenStreetMap: no son
necesariamente dos fuentes totalmente independientes. No se establece un ranking
de calidad ni se valida precisión absoluta con esta comparación.

Servicio y atribución: [geoservicios del IGN](https://www.ign.gob.ar/NuestrasActividades/InformacionGeoespacial/ServiciosOGC).
El proyecto usa el servicio XYZ/TMS en línea, sin importarlo a PostGIS. Los PNG
conservan la evidencia aunque el servicio no esté disponible posteriormente.

## Archivos y regeneración

`actividad-11-composiciones.qgz` usa `actividad-11-resultados.gpkg` por ruta
relativa y Argenmap en línea. Las áreas INTA evaluadas quedan disponibles como
capa para inspección. Hay tres PNG: `actividad-11-argenmap-urbano.png`,
`actividad-11-argenmap-rural.png` y `actividad-11-argenmap-puente.png`.

Desde la raíz, con Docker y la base cargada:

```powershell
$env:DOCKER_EXE = (Get-Command docker).Source
& A:/QGIS/bin/python-qgis-ltr.bat -X utf8 figuras/actividad-11/renderizar-actividad-11.py
```

Adaptar la ruta de QGIS a la instalación. En Linux, usar el Python con PyQGIS:
`QT_QPA_PLATFORM=offscreen python3 figuras/actividad-11/renderizar-actividad-11.py`.
Se reutiliza `figuras/mapas.py` intacto. No se guardan credenciales en el proyecto.

### Carga provincial

Con autorización específica se actualizó `scripts/importar.sh`: conserva las
35.246 geometrías de `shapes/calles_er.gpkg`, toma etiquetas fiables por ID de
`highways_er_completo.gpkg` y da prioridad a las etiquetas disponibles en el
GeoJSON de Concordia, agregando sus 53 líneas exclusivas. No toma los atributos
desplazados de `calles_er` ni agrega el resto de las geometrías de `highways`.
La integración se hace dentro del contenedor GDAL con un archivo temporal,
sin modelos paralelos ni instalación adicional en el host.

El importador conserva las tablas no vacías: no transforma automáticamente una
carga antigua de solo Concordia en provincial. Para una carga desde cero se
usa el procedimiento habitual del repositorio. La base actual se conservó.

Verificación: carga nueva con `PGDATABASE=bdg_recarga_1382`, controles de la
actividad 6, ejecución de los dos scripts nuevos y reejecución del importador
sin duplicaciones. Las 35.299 filas completas de calles, incluidas geometrías
y atributos, tienen la misma huella que la base original. Cada bloque nuevo
también se probó de forma independiente y de solo lectura. Se revisaron los
tres PNG y se abrió una copia trasladada del proyecto con capas válidas.
