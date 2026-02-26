# Portfolio - Jorge Lobato

Portfolio personal que muestra proyectos de análisis de datos, bioinformática y ecología computacional.

## 🌐 Visita el Portfolio

El portfolio está disponible en: [https://lobatojorge.github.io/portfolio/](https://lobatojorge.github.io/portfolio/)

## 📋 Descripción

Este portfolio presenta proyectos académicos y profesionales relacionados con:

- **Análisis de biodiversidad multidimensional** (diversidad taxonómica, filogenética y funcional)
- **Bioinformática aplicada** a estudios ecológicos
- **Análisis estadísticos** en R
- **Visualización de datos** y comunicación científica

## 🚀 Proyectos Incluidos

### 1. Análisis del patrón espacial y temporal de la diversidad de arañas en el PN del Teide

**Trabajo de Fin de Máster (TFM)**

- **Objetivo**: Comparar la biodiversidad de arañas entre 1995 y 2024 en el Parque Nacional del Teide
- **Metodología**: Análisis multidimensional (TD, PD, FD)
- **Tecnologías**: R, QGIS, Geneious
- **Código**: Disponible en `proyectos/tfm.html` y archivos R (`TAXO.R`, `FILO.R`, `Funcional.R`)

### 2. [Otros proyectos que quieras mencionar]

## 🛠️ Tecnologías Utilizadas

- **Frontend**: HTML5, CSS3, JavaScript
- **Análisis de datos**: R, RStudio
- **Visualización**: ggplot2, Prism.js
- **GIS**: QGIS
- **Bioinformática**: Geneious
- **Control de versiones**: Git, GitHub

## 📁 Estructura del Proyecto

```
portfolio/
├── index.html              # Página principal (las tarjetas se cargan desde data/projects.json)
├── styles.css              # Estilos globales
├── data/
│   └── projects.json       # Lista de proyectos mostrados en el portfolio (editar aquí para añadir/quitar)
├── proyectos/
│   ├── tfm.html            # Página del proyecto TFM
│   ├── tfg.html            # Página del proyecto TFG
│   └── ...
├── docs/
│   └── FLUJO.md            # Flujo Git-First: de la idea al portfolio (paso a paso)
└── README.md               # Este archivo
```

## 🔄 Flujo Git-First

Para añadir un proyecto nuevo sin tocar el HTML: edita `data/projects.json` y haz push. El protocolo completo (crear repo desde el inicio, desarrollar, publicar en el portfolio) está en [docs/FLUJO.md](docs/FLUJO.md).

## 🎯 Cómo Visualizar el Portfolio

1. **Opción 1: GitHub Pages**
   - Activa GitHub Pages en la configuración del repositorio
   - El sitio estará disponible en `https://lobatojorge.github.io/portfolio/`

2. **Opción 2: Localmente**
   - Clona el repositorio: `git clone https://github.com/lobatojorge/portfolio.git`
   - Abre `index.html` en tu navegador

## 📊 Código de Análisis

Los scripts R están disponibles directamente en la página del proyecto TFM (`proyectos/tfm.html`) o puedes descargarlos:

- **TAXO.R**: Análisis de diversidad taxonómica (riqueza, NMDS, beta diversidad, curvas de acumulación)
- **FILO.R**: Análisis de diversidad filogenética (PD, MPD, MNTD)
- **Funcional.R**: Análisis de diversidad funcional (rasgos funcionales, árbol funcional)

## 📝 Licencia

Este portfolio es de uso personal. Los proyectos académicos incluidos son propiedad de sus respectivos autores.

## 📧 Contacto

- **GitHub**: [@lobatojorge](https://github.com/lobatojorge)
- **LinkedIn**: [Jorge Lobato](https://linkedin.com/in/jorge-lobato)

---

*Última actualización: 2024*

