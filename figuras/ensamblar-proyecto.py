#!/usr/bin/env python3
"""Reúne proyectos y adjunta sus datos cartográficos dentro de un único QGZ.

Conserva también las ocho capas originales de PostGIS y Argenmap.
No ejecuta consultas de las actividades ni modifica sus GeoPackages originales.
Ejecutar con PyQGIS (crear las capas PostGIS por primera vez requiere la base):
QT_QPA_PLATFORM=offscreen /usr/bin/python3 figuras/ensamblar-proyecto.py
"""
import copy
from contextlib import contextmanager
import os
from pathlib import Path
import shlex
import shutil
import tempfile
import xml.etree.ElementTree as ET
from zipfile import ZIP_DEFLATED, ZipFile

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')

from qgis.core import (
    QgsApplication, QgsCoordinateReferenceSystem, QgsDataSourceUri, QgsProject,
    QgsLayoutItemPicture, QgsVectorLayer,
)

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent
DESTINO = OUT / 'TP2-Concordia.qgz'
TABLAS = ('departamentos', 'localidades', 'rutas', 'rios', 'lagunas', 'calles',
          'salud', 'suelo')
ACTIVIDADES = (7, 8, 9, 10, 11, 13, 14)


def leer_proyecto(ruta):
    with ZipFile(ruta) as archivo:
        nombre = next(n for n in archivo.namelist() if n.endswith('.qgs'))
        return ET.fromstring(archivo.read(nombre))


def reubicar_rutas(raiz, carpeta_origen):
    """Las capas y el SVG pasan a ser relativos a figuras/, no a actividad-NN/."""
    def relativa(valor):
        ruta, separador, opciones = valor.partition('|')
        if Path(ruta).suffix.lower() not in ('.gpkg', '.svg'):
            return valor
        absoluta = (carpeta_origen / ruta).resolve()
        return './' + os.path.relpath(absoluta, OUT) + separador + opciones

    for elemento in raiz.iter():
        if elemento.text:
            elemento.text = relativa(elemento.text)
        for atributo, valor in elemento.attrib.items():
            elemento.set(atributo, relativa(valor))


@contextmanager
def credenciales_postgis():
    """PGPASSWORD se usa en memoria; las URI del proyecto no incluyen contraseña."""
    clave_anterior = os.environ.get('PGPASSWORD')
    if clave_anterior is None and (ROOT / '.env').exists():
        for linea in (ROOT / '.env').read_text().splitlines():
            if linea.startswith('POSTGRES_PASSWORD='):
                valores = shlex.split(linea.split('=', 1)[1])
                if valores:
                    os.environ['PGPASSWORD'] = valores[0]

    try:
        yield
    finally:
        if clave_anterior is None:
            os.environ.pop('PGPASSWORD', None)


def capas_postgis():
    # Una nueva exportación conserva los identificadores y la configuración
    # existente. Reunir mapas no requiere que PostgreSQL esté encendido.
    if DESTINO.exists():
        existente = leer_proyecto(DESTINO)
        capas = [c for c in existente.findall('./projectlayers/maplayer')
                 if c.findtext('provider') == 'postgres']
        if len(capas) != len(TABLAS):
            raise RuntimeError('El proyecto existente no contiene las ocho capas PostGIS esperadas.')
        ids = {c.findtext('id') for c in capas}
        resultado = ET.Element('qgis')
        arbol = ET.SubElement(resultado, 'layer-tree-group')
        for nodo in existente.findall('.//layer-tree-layer'):
            if nodo.get('id') in ids and not any(n.get('id') == nodo.get('id') for n in arbol):
                arbol.append(copy.deepcopy(nodo))
        contenedor = ET.SubElement(resultado, 'projectlayers')
        contenedor.extend(copy.deepcopy(capas))
        return resultado

    base = QgsProject()
    base.setCrs(QgsCoordinateReferenceSystem('EPSG:4326'))
    try:
        for tabla in TABLAS:
            uri = QgsDataSourceUri()
            uri.setConnection('127.0.0.1', '5434', 'bdg_entrerios', 'postgres', '')
            uri.setDataSource('entrerios', tabla, 'geom', '', 'id')
            capa = QgsVectorLayer(uri.uri(False), f'entrerios.{tabla}', 'postgres')
            if not capa.isValid():
                raise RuntimeError(f'No se pudo abrir entrerios.{tabla}; revisar la base local.')
            capa.setReadOnly(True)
            base.addMapLayer(capa)
        with tempfile.TemporaryDirectory() as temporal:
            ruta = Path(temporal) / 'postgis.qgz'
            if not base.write(str(ruta)):
                raise RuntimeError('No se pudo guardar el proyecto temporal de capas PostGIS.')
            return leer_proyecto(ruta)
    finally:
        base.clear()


def guardar_con_adjuntos(raiz):
    """QGIS administra las rutas y el archivo de adjuntos: no se inventan URI ZIP."""
    # El proyecto intermedio puede vivir fuera del repositorio. Solo él utiliza
    # rutas absolutas; el QGZ final tendrá identificadores nativos de adjuntos.
    for elemento in raiz.iter():
        if elemento.text and elemento.text.startswith('./'):
            elemento.text = str(OUT / elemento.text[2:])
        for atributo, valor in elemento.attrib.items():
            if valor.startswith('./'):
                elemento.set(atributo, str(OUT / valor[2:]))

    proyecto = QgsProject()
    with tempfile.TemporaryDirectory() as temporal:
        intermedio = Path(temporal) / 'intermedio.qgz'
        with ZipFile(intermedio, 'w', ZIP_DEFLATED) as archivo:
            archivo.writestr('intermedio.qgs', ET.tostring(raiz, encoding='utf-8'))
        try:
            if not proyecto.read(str(intermedio)):
                raise RuntimeError('No se pudo abrir el proyecto ensamblado.')
            adjuntos = {}

            def adjuntar(origen):
                origen = Path(origen).resolve()
                if origen not in adjuntos:
                    destino = proyecto.createAttachedFile(origen.name)
                    shutil.copyfile(origen, destino)
                    adjuntos[origen] = destino
                return adjuntos[origen]

            locales = 0
            for capa in proyecto.mapLayers().values():
                if capa.providerType() == 'ogr':
                    ruta, separador, opciones = capa.source().partition('|')
                    fuente = adjuntar(ruta) + separador + opciones
                    capa.setDataSource(fuente, capa.name(), 'ogr', False)
                    if not capa.isValid():
                        raise RuntimeError(f'No se pudo abrir el adjunto de {capa.name()}.')
                    locales += 1
            for layout in proyecto.layoutManager().layouts():
                for elemento in layout.items():
                    if isinstance(elemento, QgsLayoutItemPicture) and elemento.picturePath():
                        elemento.setPicturePath(adjuntar(elemento.picturePath()))
            for documento in ('LICENCIA-QGIS-SVG.txt', 'PROCEDENCIA-SVG.md'):
                adjuntar(OUT / documento)
            if locales != 39 or len(adjuntos) != 10:
                raise RuntimeError('Se esperaban 39 capas locales y 10 recursos adjuntos.')
            # QGIS conserva además su biblioteca interna styles.db. No es una
            # capa ni un archivo externo de entrega: la administra el propio QGZ.

            destino = Path(temporal) / DESTINO.name
            if not proyecto.write(str(destino)):
                raise RuntimeError('QGIS no pudo guardar el proyecto con sus adjuntos.')
            contenido = ET.tostring(leer_proyecto(destino), encoding='utf-8')
            if b'password=' in contenido or b'authcfg=' in contenido:
                raise RuntimeError('El proyecto contiene credenciales no compartibles.')
            # Reemplazo atómico; no deja una segunda copia externa de los datos.
            with tempfile.NamedTemporaryFile(dir=OUT, suffix='.qgz', delete=False) as archivo:
                copia = Path(archivo.name)
            try:
                shutil.copyfile(destino, copia)
                os.replace(copia, DESTINO)
            finally:
                copia.unlink(missing_ok=True)
        finally:
            proyecto.clear()


def ensamblar():
    app = QgsApplication([], False)
    app.initQgis()
    try:
        fuentes = []
        for numero in ACTIVIDADES:
            carpeta = OUT / f'actividad-{numero:02}'
            rutas = list(carpeta.glob('*.qgz'))
            if len(rutas) != 1:
                raise RuntimeError(f'Se esperaba un único proyecto en {carpeta.name}.')
            raiz = leer_proyecto(rutas[0])
            reubicar_rutas(raiz, carpeta)
            fuentes.append((numero, raiz))

        principal = copy.deepcopy(fuentes[0][1])
        principal.find('title').text = 'TP2 · Riesgo hídrico y accesibilidad sanitaria · Concordia'
        principal.find('homePath').set('path', '')
        arbol = principal.find('layer-tree-group')
        capas = principal.find('projectlayers')
        layouts = principal.find('Layouts')
        orden = principal.find('layerorder')
        for contenedor in (arbol, capas, layouts, orden):
            contenedor.clear()
        arbol.set('name', 'TP2 · Concordia')
        arbol.set('checked', 'Qt::PartiallyChecked')
        arbol.set('expanded', '1')
        orden_visual = []
        ids = set()

        for numero, raiz in fuentes:
            grupo = copy.deepcopy(raiz.find('layer-tree-group'))
            grupo.set('name', f'Actividad {numero:02}')
            grupo.set('checked', 'Qt::Checked' if numero == 14 else 'Qt::Unchecked')
            grupo.set('expanded', '0')
            orden_original = grupo.find('custom-order')
            if orden_original is not None:
                orden_visual.extend(x.text for x in orden_original.findall('item'))
                grupo.remove(orden_original)
            else:
                orden_visual.extend(x.get('id') for x in grupo.findall('.//layer-tree-layer'))
            arbol.append(grupo)
            for capa in raiz.findall('./projectlayers/maplayer'):
                identificador = capa.findtext('id')
                if identificador in ids:
                    raise RuntimeError(f'Identificador de capa repetido: {identificador}')
                ids.add(identificador)
                capas.append(copy.deepcopy(capa))
            for layout in raiz.findall('./Layouts/Layout'):
                layouts.append(copy.deepcopy(layout))

        with credenciales_postgis():
            postgis = capas_postgis()
        grupo = copy.deepcopy(postgis.find('layer-tree-group'))
        grupo.set('name', 'Capas PostGIS · entrerios · solo lectura')
        grupo.set('checked', 'Qt::Unchecked')
        grupo.set('expanded', '0')
        if grupo.find('custom-order') is not None:
            grupo.remove(grupo.find('custom-order'))
        arbol.insert(0, grupo)
        for capa in postgis.findall('./projectlayers/maplayer'):
            ids.add(capa.findtext('id'))
            orden_visual.append(capa.findtext('id'))
            capas.append(copy.deepcopy(capa))

        orden_personalizado = ET.SubElement(arbol, 'custom-order', {'enabled': '1'})
        for identificador in dict.fromkeys(orden_visual):
            ET.SubElement(orden_personalizado, 'item').text = identificador
            ET.SubElement(orden, 'layer', {'id': identificador})
        if len(ids) != 48 or len(layouts) != 16:
            raise RuntimeError('Inventario inesperado: se esperaban 48 capas y 16 composiciones.')

        contenido = ET.tostring(principal, encoding='utf-8', xml_declaration=True)
        # Las credenciales no deben aparecer ni en URI, ni en propiedades de capas.
        if b'password=' in contenido or b'authcfg=' in contenido:
            raise RuntimeError('El proyecto contiene una referencia de autenticación no compartible.')
        with credenciales_postgis():
            guardar_con_adjuntos(principal)
        print(f'Generado: {DESTINO.relative_to(ROOT)} '
              '(48 capas, 16 composiciones, 10 recursos adjuntos)')
    finally:
        app.exitQgis()


if __name__ == '__main__':
    ensamblar()
