# Actividad 8 — resultados y criterio

Resultados del 25/10/2026 sobre `bdg_entrerios`. Consultas: `actividades-sql/actividad-08.sql`.

## 8.1–8.2. Rutas

Se identificaron siete referencias nacionales/provinciales por `ref` o nombre.
Los 203 tramos restantes de la capa no tienen identificación suficiente para
asignarlos a una ruta. No se los clasifica por `highway` ni por cercanía.

| Ruta | Longitud dentro de Concordia (km) |
|---|---:|
| RN14 | 141,282 |
| RN18 | 28,151 |
| RNA015 | 19,139 |
| RP22 | 35,558 |
| RP4 | 23,795 |
| RPA05 | 9,680 |
| RPA06 | 9,892 |

Las líneas se recortaron al departamento y se midieron en EPSG:5347. Son
kilómetros de red registrada: las calzadas distintas se suman por separado,
no representan necesariamente el kilometraje de un itinerario único.

## 8.3. Salud

Hay 15 establecimientos con `amenity = hospital` o `clinic`. Predomina la
concentración en el área de Concordia, con presencia también hacia Los Charrúas
y el norte del área urbana. Se conservan todas las etiquetas solicitadas por
la consigna, sin descartar especialidades por su nombre. El registro OSM no
demuestra capacidad, disponibilidad ni horarios de atención.

## 8.4. Localidad más alejada

**Pedernal**, a **35,632 km** del establecimiento elegible más cercano.
Se calculó la menor distancia directa desde cada punto de localidad a las
geometrías de los centros departamentales, y luego se eligió la mayor de esas
distancias, antes de redondear. No es un recorrido por caminos. Podría existir
atención más próxima fuera del departamento, que no integra este universo.

## 8.5. Cobertura potencial

**9 de 14 localidades** quedan a más de 5 km de todos los centros elegibles:
Benito Legerén, Calabacillas, Colonia Ayui, Estancia Grande, La Criolla,
Nueva Escocia, Pedernal, Puerto Yeruá y Yeruá.

El borde de 5000 m está incluido y cada localidad se cuenta una sola vez,
aunque varios buffers la alcancen. Los buffers se recortan al departamento.
Estar fuera señala una posible dificultad de acceso, no ausencia comprobada de
atención. Estar dentro tampoco garantiza transitabilidad ni atención efectiva.
Las cruces del mapa representan puntos interiores de los establecimientos,
solo para dibujarlos: los cálculos usan sus geometrías originales.

## Archivos y regeneración

- `actividad-08-composiciones.qgz`: proyecto portable, con capas del GeoPackage
  relativo y composiciones de rutas y cobertura.
- `actividad-08-resultados.gpkg`: resultados exportados, no otra base de entrada.
- `actividad-08-rutas.png`, `actividad-08-longitudes.png`, `actividad-08-cobertura.png`.

Desde la raíz del repositorio, con Docker y la base cargada:

```powershell
$env:DOCKER_EXE = (Get-Command docker).Source
& A:/QGIS/bin/python-qgis-ltr.bat -X utf8 figuras/actividad-08/renderizar-actividad-08.py
```

Adaptar la ruta de QGIS si está instalado en otra ubicación. En Linux, usar el
Python que tenga PyQGIS: `QT_QPA_PLATFORM=offscreen python3 figuras/actividad-08/renderizar-actividad-08.py`.
Se reutiliza `figuras/mapas.py` sin modificarlo. Los mapas se leen sin conexión
a PostGIS y no guardan contraseñas.

Verificación: cada bloque SQL se ejecutó de forma independiente en una
transacción de solo lectura. El script completo también se ejecutó en una
base nueva cargada desde `shapes/` con el importador. Se revisaron los tres
PNG y se abrió una copia trasladada del proyecto con todas sus capas válidas.
