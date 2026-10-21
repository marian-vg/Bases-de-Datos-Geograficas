## UNIVERSIDAD AUTÓNOMA DE ENTRE RÍOS

## Catedra: BASES DE DATOS AVANZADAS. 4to. Año. Carrera: Licenciatura en Sistemas de Información. Facultad de Ciencia y Tecnología.

## TRABAJO PRÁCTICO Nro. 2

Tema: Bases de Datos Geográficas.

Docentes

Lic. Sebastián Trossero Ing. Jorge Schmukler

## Trabajo Práctico:

## Riesgo Hídrico y Accesibilidad Sanitaria en Entre Ríos.

## 1\. Introducción

Entre Ríos tiene una característica que la diferencia de muchas otras provincias: el agua forma parte de manera permanente de su territorio.

Los ríos Paraná y Uruguay, junto con una gran cantidad de arroyos, lagos y cursos de agua menores, tienen un fuerte impacto sobre las actividades económicas, la población y las comunicaciones.

En este trabajo se propone utilizar herramientas de Bases de Datos Espaciales para estudiar parte de este problema en la provincia de Entre Ríos.

Cada grupo deberá seleccionar un departamento de referencia. A partir de esa elección, deberá construir una base de datos espacial utilizando PostgreSQL/PostGIS, incorporar información proveniente de diferentes fuentes y utilizar QGIS para visualizar y analizar los resultados.

Algunas actividades se desarrollarán sobre el departamento seleccionado, mientras que otras tendrán alcance provincial.

La idea no es solamente obtener mapas o ejecutar consultas SQL. El objetivo es utilizar la información espacial para responder preguntas que podrían resultar útiles frente a una situación real de emergencia.

## 2\. Objetivos

- Construir una base de datos espacial en PostgreSQL/PostGIS a partir de información geográfica disponible en fuentes abiertas.  
- Importar, organizar y relacionar diferentes tipos de información espacial.  
- Realizar consultas espaciales utilizando geometrías y relaciones topológicas.  
- Trabajar con distancias, áreas, buffers, intersecciones, diferencias y agrupamientos espaciales.  
- Analizar la relación entre hidrografía, rutas, localidades y establecimientos de salud.  
- Incorporar información proveniente de servicios geográficos externos.  
- Comparar información proveniente de organismos oficiales con datos colaborativos.  
- Utilizar QGIS como herramienta de exploración y representación de resultados.  
- Investigar y seleccionar funciones de PostGIS de acuerdo con un problema concreto.  
- Interpretar los resultados obtenidos y explicar sus posibles aplicaciones.

## 3\. Organización del trabajo

Cada grupo deberá seleccionar:

- Un departamento de la provincia de Entre Ríos.  
- Una localidad de referencia ubicada dentro de ese departamento.

La idea es que los grupos trabajen con departamentos diferentes.

El departamento seleccionado será el área principal de trabajo del grupo.

Hay ítems a resolver que deberán realizarse sobre toda la provincia de Entre Ríos, permitiendo comparar el departamento elegido con el resto de los departamentos.

## 4\. Fuentes de información

Para el desarrollo del trabajo se utilizarán principalmente las siguientes fuentes.

## 4.1. Instituto Geográfico Nacional (IGN)

## Departamentos de Entre Ríos

Se utilizará la información geográfica disponible en formato SHP correspondiente a los departamentos de la provincia.

También podrá utilizarse el servicio de Argenmap como mapa base para la visualización en QGIS.

## Servicio TMS:

[https://wms.ign.gob.ar/geoserver/gwc/service/tms/1.0.0/capabaseargenmap@EPSG%3A3857@png/{z}/{x}/{-](https://wms.ign.gob.ar/geoserver/gwc/service/tms/1.0.0/capabaseargenmap@EPSG%3A3857@png/{z}/{x}/{-) y}.png

El mapa base de Argenmap se utilizará principalmente para visualización y comparación. No es

necesario almacenarlo en PostGIS.

## 4.2. OpenStreetMap

La información de OpenStreetMap podrá obtenerse mediante el complemento QuickOSM de QGIS.

Como referencia, se pueden utilizar las siguientes consultas.

Localidades

place \= city, town, village

Rutas principales

highway \= primary, secondary, trunk, motorway

Calles

highway \= primary, secondary, tertiary, residential, unclassified

Ríos y arroyos

waterway \= river, stream

Lagos y lagunas

natural \= water

y, cuando corresponda:

water \= lake, pond, lagoon

Establecimientos de salud

amenity \= hospital, clinic

Verificar que los resultados obtenidos sean razonables para el área seleccionada.

## 4.3. INTA

Se incorporarán datos provenientes de los geoservicios del INTA correspondientes a la Región Entre Ríos.

## WMS

[https://geo-nodo03.inta.gob.ar/geoserver/wms](https://geo-nodo03.inta.gob.ar/geoserver/wms)

WFS

[https://geo-nodo03.inta.gob.ar/geoserver/wfs](https://geo-nodo03.inta.gob.ar/geoserver/wfs)

Cada grupo deberá seleccionar una capa relacionada con uso o aptitud del suelo, siempre que la información disponible resulte adecuada para el análisis propuesto.

## 5\. Sistemas de referencia y cálculos métricos

Las capas utilizadas deberán estar correctamente georreferenciadas y ser compatibles entre sí.

Como criterio general, se podrá trabajar con:

## EPSG:4326 – WGS84

Para cálculos de distancias, superficies o longitudes se deberá tener en cuenta que los grados no son una unidad métrica.

Por lo tanto, podrán utilizarse alternativas como:

- el tipo geography;  
- una reproyección a un sistema de coordenadas proyectado apropiado para la zona de estudio, por ejemplo EPSG:5343.

Se deberá justificar brevemente la alternativa utilizada para realizar los cálculos métricos.

Es posible considerar otro origen alternativo a OSM, lo pueden utilizar, la elección es libre de cada grupo.

## 6\. Construcción de la base de datos espacial

Crear una base de datos PostgreSQL con la extensión PostGIS habilitada.

Dentro de ella deberá crearse el esquema:

entrerios

Como mínimo deberán existir las siguientes tablas:

- departamentos  
- localidades  
- rutas  
- rios  
- lagunas  
- calles  
- salud

Los datos podrán incorporarse utilizando QGIS o herramientas como:

- shp2pgsql  
- ogr2ogr

Una vez cargadas las capas, deberán realizarse controles para comprobar que la información fue importada correctamente.

Entre otros aspectos, verificar:

- tipo de geometría;  
- SRID;  
- cantidad de registros;  
- existencia de geometrías nulas;  
- existencia de geometrías inválidas.

Cuando sea necesario, deberán aplicarse herramientas de corrección como ST\_MakeValid.

El informe deberá incluir ejemplos de estas verificaciones.

## 7\. Hidrografía y características del departamento&nbsp;

A partir del departamento elegido, realizar los siguientes análisis.

## 7.1. Departamentos vecinos

Identificar cuáles son los departamentos que limitan con el departamento seleccionado.

## 7.2. Frontera común

Seleccionar al menos uno de los departamentos vecinos y obtener la geometría correspondiente a la frontera compartida.

El resultado deberá poder visualizarse posteriormente en QGIS.

## 7.3. Presencia de cuerpos de agua

Realizar un ranking de los departamentos de Entre Ríos según la cantidad de lagunas y otros cuerpos de agua identificados en las fuentes utilizadas.

Explicar brevemente qué limitaciones puede tener este ranking debido a la fuente de información utilizada.

## 7.4. Superficie cubierta por agua

Calcular, para el departamento seleccionado:

- superficie total;  
- superficie correspondiente a lagunas o cuerpos de agua;  
- superficie restante;  
- porcentaje de superficie ocupada por agua.

Los resultados deberán expresarse en km².

## 7.5. Cursos de agua

Identificar los ríos y arroyos que atraviesan el departamento seleccionado y calcular la longitud total de estos cursos de agua dentro del departamento.

Presentar los resultados en metros.

## 8\. Rutas y accesibilidad sanitaria&nbsp;

En este punto se analizará qué tan accesibles son los servicios sanitarios desde las distintas localidades del departamento.

## 8.1. Red vial principal

Identificar las rutas nacionales y provinciales que atraviesan el departamento seleccionado.

## 8.2. Longitud de las rutas

Calcular cuántos kilómetros de cada ruta se encuentran dentro del departamento.

Los resultados deberán presentarse en forma de tabla y acompañarse, cuando sea posible, con una representación cartográfica.

## 8.3. Establecimientos de salud

Identificar los hospitales y clínicas registrados en OpenStreetMap dentro del departamento.

Analizar su distribución espacial.

## 8.4. Localidad más alejada

Determinar qué localidad del departamento presenta la mayor distancia respecto de un establecimiento de salud.

El grupo deberá explicar el criterio utilizado para determinar dicha distancia.

## 8.5. Área de cobertura sanitaria

Generar un área de influencia de 5 km alrededor de los establecimientos de salud.

A partir de esta información, determinar cuántas localidades del departamento quedan fuera de dicha cobertura.

Representar el resultado en QGIS y explicar qué podría significar esta situación desde el punto de vista de la accesibilidad sanitaria.

## 9\. Gestión del riesgo hídrico \- mariano

En este punto la idea es combinar diferentes capas para construir una primera aproximación al riesgo asociado a la presencia de cursos y cuerpos de agua.

## 9.1. Definición de una zona de riesgo

Generar una zona de influencia de 2 km alrededor de los ríos, arroyos y lagunas del departamento seleccionado.

Para este trabajo se considerará dicha área como una:

## Zona de Riesgo Hídrico

Esta definición constituye una simplificación realizada exclusivamente para fines académicos y no representa un mapa oficial de riesgo de inundación.

## 9.2. Infraestructura sanitaria expuesta

Determinar si existen establecimientos de salud ubicados dentro de la zona definida como de riesgo hídrico.

Identificar cuáles son y representar los resultados en un mapa.

## 9.3. Posibles situaciones de aislamiento

Analizar la relación entre:

- localidades;  
- rutas;  
- cursos de agua.

Buscar situaciones en las cuales la presencia de un curso de agua pueda generar dificultades de conexión entre una localidad y la red vial principal.

El análisis deberá incluir una explicación de la metodología utilizada.

Se recomienda investigar el uso de funciones como:

ST\_Intersects

ST\_DWithin

y otras funciones espaciales que puedan resultar útiles.

## 9.4. Departamentos con mayor exposición

Realizar un análisis a escala provincial para identificar departamentos con una mayor proporción de superficie relacionada con cuerpos de agua o zonas de influencia hídrica.

Para este ejercicio se utilizará como referencia un 30 % de superficie.

## 10\. Funciones y automatización mediante SQL

## 10.1. Clasificación del riesgo de una localidad

Crear una función denominada:

fn\_riesgo\_localidad(nombre\_localidad)

La función deberá recibir el nombre de una localidad y devolver una clasificación:

- Alto: distancia inferior a 1 km de un río, arroyo o laguna.  
- Medio: distancia entre 1 y 3 km.  
- Bajo: distancia superior a 3 km.

Además de desarrollar la función, deberán probarla utilizando varias localidades y analizar los resultados.

## 10.2. MBR de Entre Ríos

Obtener el Mínimo Rectángulo Delimitador (MBR) correspondiente al territorio de Entre Ríos

utilizando ST\_Envelope.

Calcular además la superficie de dicha envolvente y compararla con la superficie real de la provincia.

Explicar por qué ambas superficies son diferentes.

## 10.3. Hospital más cercano

Crear una función parametrizada:

fn\_hospital\_cercano(lat, lon)

La función deberá recibir una coordenada geográfica y devolver:

- nombre del establecimiento de salud más cercano;  
- distancia hasta el mismo.

La consulta deberá simular la situación de una persona que solicita asistencia indicando únicamente su posición.

## 10.4. Agrupamiento de establecimientos sanitarios

Utilizar ST\_ClusterKMeans para agrupar los establecimientos de salud del departamento seleccionado en 3 grupos.

Para cada grupo:

- identificar los establecimientos que lo integran;  
- obtener su centroide;  
- representar los resultados en QGIS.

Finalmente, interpretar los centroides obtenidos como posibles ubicaciones para mejorar la distribución de ambulancias, medicamentos o futuros centros de atención.

## 11\. Calles, OpenStreetMap y Argenmap \- damian

Incorporar las calles obtenidas desde OpenStreetMap a la base de datos como tabla:

calles

## 11.1. Densidad de la red vial

Calcular la longitud total de calles del departamento seleccionado.

Comparar este valor con el promedio correspondiente al conjunto de departamentos de Entre Ríos.

## 11.2. Densidad vial por localidad

Determinar qué localidad presenta la mayor densidad vial.

Para ello se podrá utilizar como indicador:

&nbsp;

longitud total de calles / superficie de la localidad

Explicar las decisiones tomadas para realizar el cálculo.

## 11.3. Categorías de calles

Identificar las calles clasificadas como:

- primary  
- secondary

y calcular cuántos kilómetros corresponden a cada categoría.

## 11.4. Comparación con Argenmap

Visualizar simultáneamente la información de calles de OpenStreetMap y el mapa base de Argenmap.

Realizar una breve comparación teniendo en cuenta:

- cobertura;  
- ubicación de las vías;  
- diferencias entre ambas fuentes;  
- sectores rurales;  
- zonas cercanas a ríos y arroyos;  
- presencia y ubicación de puentes.

El objetivo no es determinar simplemente cuál fuente es "mejor", sino analizar por qué pueden existir diferencias entre dos fuentes de información geográfica.

## 12\. Información del INTA y uso del suelo

Conectar QGIS al servicio WFS del INTA y seleccionar una capa relacionada con el uso o aptitud del suelo que resulte útil para el área seleccionada.

La capa elegida deberá incorporarse al proyecto y posteriormente almacenarse en PostGIS como:

entrerios.suelo

## 12.1. Uso del suelo

Determinar qué porcentaje del departamento corresponde a:

- áreas agrícolas;  
- otros usos.

La clasificación concreta dependerá de la información disponible en la capa seleccionada.

## 12.2. Áreas agrícolas expuestas

Identificar sectores de uso agrícola que se encuentren dentro de la Zona de Riesgo Hídrico definida anteriormente.

El objetivo será realizar una primera aproximación a las posibles áreas productivas expuestas.

## 12.3. Corredores productivos

Calcular la intersección entre las principales rutas y las áreas agrícolas.

Identificar aquellos sectores donde exista una relación directa entre:

&nbsp;

producción agrícola \+ red vial

y analizar su posible importancia como corredores productivos.

## 13\. Consulta agregada.&nbsp;

Cada grupo deberá plantear y resolver una situación que podría presentarse durante una emergencia real.

No deberá limitarse a repetir alguna de las consultas anteriores.

Algunos ejemplos posibles son:

- una ruta principal queda inutilizada por una inundación;  
- una localidad queda parcialmente aislada;  
- se necesita determinar qué localidades deberían ser evacuadas primero;  
- se debe encontrar una ubicación adecuada para instalar un hospital de campaña;  
- se necesita determinar el establecimiento sanitario alternativo más cercano;  
- se debe seleccionar una zona para instalar un centro de distribución de medicamentos;  
- se necesita encontrar una ruta alternativa para conectar una localidad con un hospital.

## La consulta deberá:

1. plantear claramente el problema;  
   2. explicar qué información espacial resulta necesaria;  
   3. utilizar al menos tres tipos diferentes de información geográfica;  
   4. desarrollar la consulta SQL correspondiente;  
   5. mostrar el resultado en QGIS;  
   6. explicar qué decisión podría tomarse a partir del resultado.

Se recomienda combinar información de:

## OSM \+ IGN \+ INTA

aunque también podrá incorporarse otra fuente de información abierta, por ejemplo, datos de población del INDEC.

## 14\. Problema

La idea en este punto es que cada grupo deberá resolver un problema para el cual no se proporcionará una consulta SQL modelo ni una secuencia de funciones a utilizar.

## Problema propuesto

El gobierno provincial necesita seleccionar una ubicación para instalar un:

## Centro de Atención Sanitaria de Emergencia

El lugar seleccionado debería cumplir, en la medida de lo posible, con las siguientes condiciones:

- encontrarse fuera de la Zona de Riesgo Hídrico;  
- estar próximo a una ruta principal;  
- permitir atender a localidades que actualmente presentan menor accesibilidad sanitaria;  
- encontrarse fuera de determinadas áreas de uso agrícola;  
- disponer de una superficie adecuada;  
- no encontrarse dentro de cuerpos de agua;  
- encontrarse en una posición que permita atender a varias localidades;  
- presentar condiciones razonables de accesibilidad.

El grupo deberá definir su propia metodología para encontrar uno o más lugares candidatos.

No se indicará qué funciones de PostGIS deben utilizarse.

La idea es investigar cuáles son las herramientas espaciales necesarias, justificar la elección y documentar el procedimiento utilizado.

## El análisis deberá incluir

- definición del problema;  
- criterios utilizados;  
- datos necesarios;  
- funciones de PostGIS investigadas;  
- procedimiento seguido;  
- consulta o consultas SQL desarrolladas;  
- resultados obtenidos;  
- representación cartográfica;  
- análisis de los candidatos encontrados;  
- conclusión final.

Explicar por qué considera que la ubicación propuesta es adecuada.

## 15\. Funciones espaciales sugeridas

Durante el desarrollo podrán utilizarse, según las necesidades de cada consulta, funciones como:

- ST\_Intersects  
- ST\_Intersection  
- ST\_DWithin  
- ST\_Distance  
- ST\_ClosestPoint  
- ST\_Buffer  
- ST\_Area  
- ST\_Length  
- ST\_Envelope  
- ST\_MakeValid  
- ST\_GeometryType  
- ST\_SRID  
- ST\_ClusterKMeans

Esta lista no es exhaustiva.

La idea es que los grupos investiguen y utilicen otras funciones cuando resulten necesarias para resolver los problemas planteados.

## 16\. Entregables

## 16.1. Informe en PDF

Cada resultado deberá estar acompañado por una explicación que permita comprender:

qué se obtuvo, cómo se obtuvo y qué significa.

## 16.2. Script SQL

Archivo .sql que contenga:

- creación del esquema;  
- creación de tablas, cuando corresponda;  
- consultas;  
- funciones;  
- procedimientos o scripts utilizados;  
- análisis realizados.

El script deberá estar organizado y correctamente comentado.

## 16.3. Proyecto QGIS

Archivo. qgz que contenga:

- capas utilizadas;  
- conexión a PostGIS;  
- simbología;  
- mapas elaborados;  
- composiciones cartográficas, cuando corresponda.

Las capas deberán estar correctamente organizadas e identificadas.