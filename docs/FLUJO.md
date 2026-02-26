# Flujo Git-First: de la idea al portfolio

Este documento describe el protocolo paso a paso para llevar un proyecto desde la idea inicial hasta que aparezca en el portfolio, manteniendo el historial de commits y sin editar HTML a mano.

## Resumen

1. Crear el repositorio en GitHub desde el principio.
2. Desarrollar con commits frecuentes en ese repo.
3. Cuando el proyecto esté listo para mostrarse, añadir una entrada en `data/projects.json` (o anclar el repo si usas la automatización).
4. Hacer commit y push en el repo del portfolio. GitHub Pages sirve la nueva versión.

---

## Paso 1: Crear el repositorio (minuto 1)

En cuanto tengas una idea (por ejemplo, un script de automatización, un análisis o una herramienta):

1. Ve a [GitHub](https://github.com/new).
2. Crea un repositorio nuevo (puede estar vacío o con un README).
3. El repo ya existe; todo el trabajo posterior tendrá historial desde el inicio.

**No esperes a “terminar” el proyecto para crear el repo.** Crear el repo al final es lo que te hacía perder el historial de commits.

---

## Paso 2: Desarrollar en local

1. Clona el repositorio:
   ```bash
   git clone https://github.com/lobatojorge/NOMBRE-DEL-REPO.git
   cd NOMBRE-DEL-REPO
   ```
2. Desarrolla en una rama (por ejemplo `main` o `dev`).
3. Haz commits con frecuencia:
   ```bash
   git add .
   git commit -m "Descripción del cambio"
   git push origin main
   ```

Todo el historial queda en GitHub.

---

## Paso 3: Subir cambios al repo

Cada vez que quieras guardar el estado del proyecto:

```bash
git add .
git commit -m "Mensaje descriptivo"
git push
```

No hace falta tocar el portfolio en este paso.

---

## Paso 4: Añadir el proyecto al portfolio

Cuando el proyecto esté listo para mostrarse públicamente:

1. Abre el repositorio del **portfolio** (este repo).
2. Edita el archivo **`data/projects.json`**.
3. Añade una nueva entrada con el mismo formato que las existentes:

   **Si el proyecto solo enlaza al repo de GitHub** (sin página de detalle en el portfolio):

   ```json
   {
     "id": "nombre-corto",
     "title": "Nombre visible en la tarjeta",
     "slug": "nombre-corto",
     "image": "imagenes/icono.png",
     "url": "https://github.com/lobatojorge/NOMBRE-DEL-REPO",
     "external": true
   }
   ```

   **Si el proyecto tiene página de detalle dentro del portfolio** (como TFG/TFM):

   ```json
   {
     "id": "nombre-corto",
     "title": "Nombre visible en la tarjeta",
     "slug": "nombre-corto",
     "image": "imagenes/icono.png",
     "url": "proyectos/nombre.html",
     "external": false
   }
   ```

4. Si usas una imagen nueva, añádela en `portfolio/imagenes/`.
5. Si el proyecto tiene página de detalle, crea o copia el archivo correspondiente en `portfolio/proyectos/` (por ejemplo `nombre.html`).

---

## Paso 5: Publicar el cambio en el portfolio

1. En el repo del portfolio:
   ```bash
   git add data/projects.json
   # y, si aplica, los archivos nuevos en proyectos/ e imagenes/
   git commit -m "Añadir proyecto: Nombre del proyecto"
   git push origin main
   ```
2. GitHub Pages publicará automáticamente la nueva versión en `https://lobatojorge.github.io/portfolio/`.

Si en el repo del portfolio tienes activado GitHub Actions, un workflow validará que `data/projects.json` existe y tiene la estructura correcta cada vez que ese archivo se modifique en un push o pull request.

---

## Resumen del flujo

| Paso | Dónde       | Acción                                                                 |
|------|-------------|------------------------------------------------------------------------|
| 1    | GitHub      | Crear repo del proyecto (vacío o con README).                          |
| 2    | Local       | Clonar, desarrollar, commits frecuentes.                              |
| 3    | Git         | Push al repo del proyecto.                                             |
| 4    | Portfolio   | Añadir entrada en `data/projects.json` (y opcionalmente página en `proyectos/`). |
| 5    | Portfolio   | Commit + push del portfolio; GitHub Pages actualiza el sitio.         |

El repositorio del proyecto existe desde el minuto 1; el portfolio solo “apunta” a él (o a una página interna) mediante los datos en `projects.json`, sin editar el HTML del index.
