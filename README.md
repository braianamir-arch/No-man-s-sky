# Cielo Infinito

Juego de exploración espacial procedural inspirado en **No Man's Sky**, hecho en
**Godot 4.3** (renderer *Mobile*) para **Android e iOS**. También funciona en PC
con teclado y ratón, así que podés probarlo en el editor.

Todo el mundo se genera por código a partir de una semilla: no hay modelos ni
texturas externas.

## Qué incluye

- **Universo infinito**: cada sistema estelar sale de una semilla (estrella,
  3 a 5 planetas, cinturón de asteroides). Con una *célula de curvatura* saltás
  a un sistema nuevo.
- **Planetas esféricos de verdad**: terreno con ruido sobre una cubo-esfera,
  gravedad hacia el centro, océanos, atmósfera, día y noche según la posición
  de la estrella.
- **6 biomas**: exuberante, tóxico, helado, abrasador, yermo y exótico, cada uno
  con sus colores, su flora, sus peligros y sus recursos.
- **Transición sin cortes entre planeta y espacio**: despegás, salís de la
  atmósfera, encendés el **motor de pulso** y aterrizás en otro planeta.
- **Explorador en primera persona** con jetpack, nado y sprint.
- **Multiherramienta**: minás rocas, plantas y cristales (con sobrecalentamiento).
- **Recursos**: Carbono, Ferrita, Sodio, Oxígeno, Di-hidrógeno y Tritio
  (este último sale de los asteroides, disparando desde la nave).
- **Supervivencia**: soporte vital, protección contra peligros (toxicidad,
  frío, calor, radiación) y salud.
- **Fauna procedural** que deambula y huye de vos; con el **escáner** descubrís
  especies y depósitos cercanos.
- **Descubrimientos** que dan unidades, **fabricación**, recargas y **mejoras**
  (exotraje, jetpack, motores).
- **Guardado** automático al pausar o cerrar la app, y también manual desde el menú.
- **Controles táctiles multitouch**: joystick dinámico, deslizar para mirar y botones.

## Controles

| Acción | Táctil | PC |
|---|---|---|
| Moverse / dirigir la nave | Joystick (mitad izquierda) | WASD / ratón |
| Mirar | Deslizar en la mitad derecha | Ratón (clic para capturarlo, Esc para soltarlo) |
| Minar / disparar | MINAR / FUEGO | Clic izquierdo o F |
| Saltar / jetpack (mantener) | SALTO | Espacio |
| Escáner | ESCÁNER | C |
| Subir, bajar o aterrizar la nave | USAR / SALIR / ATERRIZAR | E |
| Despegar / acelerar / frenar | DESPEGAR · ACEL. · FRENO | W / S |
| Rolar la nave | — | A / D |
| Motor de pulso (lejos de los planetas) | PULSO (mantener) | Shift |
| Salto de curvatura | SALTO CURV. | J |
| Menú (inventario y fabricación) | MENÚ | Tab / I |

En el suelo, empujar el joystick hasta el borde activa el sprint.

## Cómo empezar a jugar

1. Recogé Ferrita (rocas), Carbono, Sodio y Oxígeno (plantas) y Di-hidrógeno (cristales azules).
2. Recargá el soporte vital y la protección desde el **MENÚ** cuando bajen.
3. Subí a la nave, despegá y dispará a los asteroides para conseguir **Tritio**.
4. Fabricá una **célula de curvatura** (50 Tritio, 40 Ferrita, 30 Di-hidrógeno).
5. Alejate de los planetas y usá **SALTO CURV.** para ir a un sistema nuevo.

## Abrir y ejecutar

1. Instalá [Godot 4.3](https://godotengine.org/download) o una versión 4.x posterior.
2. En el gestor de proyectos, **Importar** → elegí `project.godot`.
3. Pulsá **F5**.

## Exportar a Android

1. En Godot: *Editor → Gestionar plantillas de exportación* → descargá las plantillas.
2. Configurá el Android SDK y un keystore de depuración en *Editor → Configuración del editor → Exportar → Android*.
3. *Proyecto → Exportar* → preset **Android** (ya está creado, arm64) → *Exportar proyecto* para generar el APK,
   o usá el botón de *Despliegue remoto* con el teléfono conectado por USB.

## Exportar a iOS

Necesitás una Mac con Xcode y una cuenta de Apple Developer.

1. Completá *App Store Team ID* en el preset **iOS**.
2. Exportá: Godot genera un proyecto de Xcode.
3. Abrilo en Xcode, elegí tu equipo de firma y ejecutalo en el iPhone o iPad.

## Prueba automática

Hay una prueba de humo que carga el juego y recorre el ciclo completo: caminar,
minar, subir a la nave, despegar, ir al espacio, aterrizar en otro planeta,
bajar, hacer un salto de curvatura y abrir el menú.

```bash
godot --headless --fixed-fps 60 --path . res://tests/autotest.tscn
```

Si definís `SHOTS_DIR=/ruta` y la ejecutás con pantalla (sin `--headless`), además guarda capturas.

## Estructura

```
scenes/main.tscn              Escena principal (todo se crea por código)
scripts/main.gd               Bucle de juego, cambio entre explorador y nave, cielo y luz, saltos
scripts/autoload/game_state.gd  Inventario, estadísticas, recetas, descubrimientos, guardado, controles
scripts/autoload/touch_input.gd Puente entre los controles táctiles o el ratón y el juego
scripts/world/star_system.gd  Generación del sistema estelar y asteroides
scripts/world/planet.gd       Terreno procedural, biomas, océano, atmósfera, detalle por celdas
scripts/world/creature.gd     Fauna procedural
scripts/world/resource_node.gd  Depósitos minables
scripts/actors/player.gd      Explorador: gravedad radial, jetpack, minado, soporte vital
scripts/actors/ship.gd        Nave: despegue, vuelo, pulso, aterrizaje, láseres
scripts/ui/                   HUD, menú y controles táctiles
shaders/                      Cielo con estrellas y nebulosas, atmósfera
```

## Próximos pasos posibles

- Centinelas que vigilan el minado excesivo.
- Estaciones espaciales con comercio.
- Construcción de bases.
- Terreno con más detalle (LOD por quadtree) y cuevas.
- Sonido y música.
- Multijugador.

*Proyecto fan no oficial. No Man's Sky es una marca de Hello Games.*
