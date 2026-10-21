# Histórico Cubiscan

Panel web para analizar el histórico de mediciones Cubiscan (dimensiones, peso, empaques, bloqueos, VAS) y generar reportes de incidencia.

Es una página estática: no necesita servidor ni base de datos instalada. El panel (`index.html`) descarga `db/cubiscan.db` y la lee directamente en el navegador con [sql.js](https://sql.js.org) (SQLite compilado a JavaScript). Chart.js, jsPDF y sql.js vienen incluidos dentro del HTML, así que funciona sin depender de otros sitios.

## Estructura

```
index.html          Panel de análisis e incidencias
db/cubiscan.db      Base SQLite con el histórico (≈50.600 mediciones)
db/schema.sql       Esquema de la base (tablas, índices y vistas)
db/data.sql         Los mismos datos en formato SQL, para regenerar la base
```

## Abrir el panel

**En línea:** publicar el repositorio en Cloudflare Pages o GitHub Pages (ver abajo) y abrir la dirección del sitio.

**En el computador:** el navegador no permite que una página abierta con doble clic lea otros archivos, así que el panel pedirá seleccionar `db/cubiscan.db` a mano. Para que la cargue sola, servir la carpeta con un servidor local:

```
python -m http.server 8000
```

y abrir `http://localhost:8000`.

Para usar otra base, agregar `?db=ruta/otra.db` a la dirección.

## Publicar en Cloudflare Pages (repositorio privado)

1. Crear una cuenta gratis en [dash.cloudflare.com](https://dash.cloudflare.com).
2. Ir a **Workers & Pages → Create → Pages → Connect to Git** y autorizar el acceso a GitHub, eligiendo solo este repositorio.
3. En la configuración de compilación:
   - Framework preset: **None**
   - Build command: *(vacío)*
   - Build output directory: `/`
4. Pulsar **Save and Deploy**. El sitio queda en `https://<nombre>.pages.dev` y se actualiza solo con cada cambio que se suba a `main`.
5. Opcional, para que solo entren personas autorizadas: en el proyecto, **Settings → Access policy**, activar Cloudflare Access y agregar los correos permitidos.

Con esta opción el repositorio puede ser privado.

## Publicar en GitHub Pages (repositorio público)

1. En GitHub, abrir el repositorio → **Settings → Pages**.
2. En **Source** elegir **Deploy from a branch**, rama `main`, carpeta `/ (root)`, y guardar.
3. En uno o dos minutos el sitio queda en `https://cesarflores74-ops.github.io/Cubiscan-2026/`.

En la cuenta gratis de GitHub, Pages solo funciona con repositorios públicos: cualquiera podrá ver y descargar la base de datos.

## Regenerar la base desde los archivos SQL

```
sqlite3 db/cubiscan.db < db/schema.sql
sqlite3 db/cubiscan.db < db/data.sql
```

(Borrar antes el `db/cubiscan.db` existente.)

## Importante

Los registros ingresados y los reportes de incidencia creados en el panel se guardan solo en el navegador de quien los crea (`localStorage`). No se escriben en `db/cubiscan.db`, no los ven otras personas y se pierden si se borran los datos del navegador.
