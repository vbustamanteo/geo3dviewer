# Geo 3D Viewer (Godot Engine)

Visualizador interactivo tridimensional para representación y análisis de datos geoespaciales (Modelos Digitales de Elevación y mapas de vegetación espectral NDVI) desarrollado en **Godot Engine 4**.

Forma parte de la suite **Geo 3D Processing & Visualization**, actuando como el cliente de renderizado y exploración 3D en tiempo real para las texturas generadas por el módulo de procesamiento geoespacial en C++ ([geo3dprocessing](https://github.com/vbustamanteo/geo3dprocessing)).

---

## 🚀 Características Principales

- **Deformación de Terreno por GPU (Vertex Displacement)**: Desplazamiento dinámico en el vertex shader (`main_3d.gdshader`) utilizando mapas de altura de alta precisión de 16 bits (`heightmap_16bit.png`), eliminando el efecto de escalonamiento (*banding*).
- **Reconstrucción Analítica de Normales**: Cálculo en tiempo real de normales de superficie en el shader mediante diferencias finitas en texeles vecinos para sombreado e iluminación precisos.
- **Mapeo Espectral NDVI (Colormap)**: Gradiente de color procedural para representar índices de vegetación desde cuerpos de agua/sombras hasta coberturas vegetales densas.
- **Inspector Interactivo con Raycasting 3D (`TerrainInspector.gd`)**:
  - Proyección de rayos 3D desde el cursor en pantalla hacia la superficie del terreno.
  - Conversión de punto de impacto espacial a coordenadas locales y normalización UV.
  - Muestreo directo del píxel exacto de la textura NDVI.
  - Reconstrucción matemática del índice NDVI continuo $[-1.0, +1.0]$:
    $$\text{NDVI} = (\text{Pixel}_R \times 2.0) - 1.0$$
  - Clasificación en tiempo real del estado de cobertura terrestre (Agua/Sombra, Suelo Expuesto/Roca, Vegetación Escasa, Vegetación Densa/Bosque).
  - Telemetría en pantalla (Coordenadas UV, Elevación en metros y valor cualitativo/cuantitativo de NDVI).
- **Cámara Orbital Esférica 3D (`camera_3d.gd`)**:
  - Control de órbita azimutal y polar mediante coordenadas esféricas convertidas a cartesianas.
  - Zoom suave con limitadores de distancia (*clamping*) y restricción angular para evitar inversiones de perspectiva.

---

## 📁 Estructura del Proyecto

```text
geo-3d-viewer/
├── project.godot           # Archivo principal de configuración de Godot 4.x
├── main_3d.scn             # Escena principal 3D (Terreno, Iluminación, Colisionador y UI)
├── main_3d.gdshader        # Shader espacial (desplazamiento vertical y rampa NDVI)
├── TerrainInspector.gd     # Lógica de raycasting, muestreo de texturas e interfaz HUD
├── camera_3d.gd            # Controlador de cámara orbital en coordenadas esféricas
├── heightmap_16bit.png     # Textura ráster de elevación cuantizada a 16 bits (DEM)
├── ndvi_data.png           # Textura ráster con datos normalizados de vegetación (NDVI)
├── icon.svg                # Ícono de la aplicación
└── README.md               # Documentación del proyecto
```

---

## 🛠️ Requisitos del Sistema

- **Godot Engine**: Versión **4.x** (configurado con motor 4.6 / compatibilidad GL).
- **Motor de Física**: Jolt Physics 3D (configurado en el proyecto).
- **Controlador de Renderizado**: Compatibilidad GL (OpenGL 3.3 / ES 3.0 / WebGL 2) o Forward+ / Vulkan / Direct3D 12.

---

## 🎮 Controles de Navegación e Interacción

| Acción | Control | Descripción |
|---|---|---|
| **Orbitar Cámara** | `Clic Derecho + Arrastrar` | Rota la cámara alrededor del punto central del terreno. |
| **Zoom In / Out** | `Rueda del Mouse (Scroll)` | Acerca o aleja la cámara dentro del rango configurado (10 a 250 unidades). |
| **Inspeccionar Punto** | `Clic Izquierdo` | Lanza un rayo 3D al terreno, consulta la elevación y calcula el NDVI exacto del píxel seleccionado. |

---

## 🔬 Componentes Técnicos

### 1. Shader de Terreno (`main_3d.gdshader`)
El shader espacial realiza dos tareas esenciales:
- **Etapa de Vértices (`vertex`)**:
  ```glsl
  float height = texture(heightmap_texture, UV).r;
  VERTEX.y += height * height_scale;
  
  // Reconstrucción vectorial de la Normal por diferencias centrales
  float h_L = texture(heightmap_texture, UV + vec2(-texel_size, 0.0)).r * height_scale;
  float h_R = texture(heightmap_texture, UV + vec2(texel_size, 0.0)).r * height_scale;
  float h_D = texture(heightmap_texture, UV + vec2(0.0, -texel_size)).r * height_scale;
  float h_U = texture(heightmap_texture, UV + vec2(0.0, texel_size)).r * height_scale;
  
  NORMAL = normalize(vec3(h_L - h_R, 2.0, h_D - h_U));
  ```
- **Etapa de Fragmentos (`fragment`)**: Aplica una paleta cromática interpolada basada en el valor de reflectancia espectral almacenado en `ndvi_texture`.

### 2. Inspector de Terreno (`TerrainInspector.gd`)
Interseca la física 3D con la geometría del plano y desnormaliza los datos del ráster:
```gdscript
# Recuperación del valor real NDVI (-1.0 a +1.0)
var raw_val = pixel_color.r
var real_ndvi = (raw_val * 2.0) - 1.0

# Clasificación biogeográfica
if real_ndvi < 0.0:
    status = "Cuerpo de Agua / Sombra"
elif real_ndvi < 0.2:
    status = "Suelo Expuesto / Roca"
elif real_ndvi < 0.5:
    status = "Vegetación Escasa / Pastizal"
else:
    status = "Vegetación Densa / Bosque"
```

### 3. Cámara Orbital (`camera_3d.gd`)
Transformación de coordenadas esféricas $(\rho, \theta, \phi)$ a cartesianas $(X, Y, Z)$ centradas en el objetivo:
```gdscript
pos.x = target_center.x + distance * cos(rot_x) * sin(rot_y)
pos.y = target_center.y - distance * sin(rot_x)
pos.z = target_center.z + distance * cos(rot_x) * cos(rot_y)
```

---

## 🔄 Integración con el Módulo de Procesamiento (C++)

Este visualizador espera recibir los rásteres procesados desde el backend en C++:

1. **Generar texturas en el backend**:
   ```bash
   cd ../geo-3d-viewer-c
   ./build/bin/GeoProcessingModule
   ```
2. **Copiar texturas al proyecto Godot**:
   ```bash
   cp data/output/heightmap_16bit.png ../geo-3d-viewer/
   cp data/output/ndvi_data.png ../geo-3d-viewer/
   ```
3. Al volver a abrir o recargar el proyecto en Godot, el motor reimportará automáticamente las texturas actualizadas conservando las asignaciones en el material del terreno.

---

## 📦 Ejecución del Proyecto

1. Abrir **Godot Engine 4**.
2. Seleccionar **Importar** y apuntar al archivo `project.godot` de este repositorio.
3. Presionar **F5** (o el botón de reproducción en la esquina superior derecha) para ejecutar la escena principal `main_3d.scn`.
