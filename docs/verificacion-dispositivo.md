# Pauta de verificación en dispositivo real

Los tests automatizados de este proyecto verifican **geometría de layout y áreas
táctiles**, no apariencia. Hay una clase entera de defectos que solo aparece en
hardware: bugs de GPU (ver `bugs/mediatek-image-banding` en la wiki), migraciones
de base de datos sobre datos reales, y si el texto le resulta cómodo o no a un
niño de básica.

Esta pauta es reutilizable en cada release. Marca lo que falle y repórtalo con el
número de ítem.

---

## 0. Primero: una sola tablet, no la flota

**Antes de dejar que todas las tablets tomen la actualización OTA.**

Esta versión incluye la primera migración de esquema de drift que corre en
producción (`schemaVersion` 1 → 2, agrega `appBuild` y `readingCpl`). Es
aditiva y hay un test que prueba que las filas existentes sobreviven, pero el
test corre sobre un archivo sintético, no sobre la base de una tablet con meses
de uso.

- [ ] **0.1** Elige una tablet que ya tenga evaluaciones locales y actualízala primero.
- [ ] **0.2** Tras el primer arranque, abre una evaluación anterior y confirma que el historial del alumno sigue ahí.
- [ ] **0.3** Si el historial se perdió, **detén el rollout** y avisa. Hay rollback disponible: `ota/releases/prosodia-prev.apk` y `version-prev.json`.

Recién con 0.2 confirmado, deja que el resto actualice.

---

## 1. Ícono y marca

El logo cambió por completo esta versión. El adaptive icon de Android tiene tres
capas y cada una puede fallar distinto.

- [ ] **1.1** El ícono en el launcher es el anillo de cronómetro naranja con la onda blanca al centro.
- [ ] **1.2** El anillo **no** se ve cortado por el borde de la máscara ni flotando diminuto en el centro. Debe llenar el círculo con holgura pareja.
- [ ] **1.3** El fondo del ícono es violeta con degradado, **no** azul marino.
- [ ] **1.4** *(Android 13+)* Activa "iconos temáticos" en ajustes del launcher. El ícono debe verse como un **arco incompleto** con la onda — si aparece un círculo sólido y relleno, la capa monocroma está mal.
- [ ] **1.5** El splash de arranque y la pantalla de login muestran el logo nuevo, no el anterior.

---

## 2. Orientación

Regla nueva: la app sigue la clase de dispositivo, **pero la superficie de
lectura va siempre en landscape**.

### En tablet
- [ ] **2.1** Todo landscape, sin cambios respecto de antes. Girarla no rota nada.

### En teléfono (si tienes uno a mano)
- [ ] **2.2** Login, selección de curso y de alumno **sí rotan** al girar el teléfono.
- [ ] **2.3** Al abrir un texto de lectura, la app **se fuerza a landscape** aunque tengas el teléfono vertical.
- [ ] **2.4** Con la lectura abierta, girar el teléfono a vertical **no** la rota.
- [ ] **2.5** Al tocar "cambiar lectura" y volver atrás, el teléfono **vuelve a rotar libre**.
- [ ] **2.6** Al salir de la evaluación por completo, el teléfono no queda trabado en horizontal.

---

## 3. Lectura y layout

Acá el criterio no es "no desborda" — eso ya lo cubren los tests. El criterio es
si funciona para un niño leyendo en voz alta bajo cronómetro.

- [ ] **3.1** El texto de lectura se ve **cómodo**: ni apretado ni con líneas tan largas que cueste encontrar el renglón siguiente.
- [ ] **3.2** Las portadas de los textos se ven limpias, **sin bandas ni franjas** de color. Este es el bug de GPU MediaTek — si aparece, anota el modelo exacto de tablet.
- [ ] **3.3** El panel de control (cronómetro, botones de grabación) queda accesible sin scroll incómodo.
- [ ] **3.4** Los botones son fáciles de tocar con el dedo, no requieren precisión.
- [ ] **3.5** Nada queda cortado ni tapado en ninguna pantalla del flujo.

---

## 4. Flujo completo de evaluación

Una evaluación de punta a punta, con un alumno real o de prueba.

- [ ] **4.1** Seleccionar curso → el listado de alumnos carga.
- [ ] **4.2** Seleccionar alumno → aparece la galería de textos de su nivel.
- [ ] **4.3** Seleccionar texto → se abre la lectura (y se fuerza landscape, ver 2.3).
- [ ] **4.4** Grabar → el cronómetro corre y el audio se captura.
- [ ] **4.5** Detener → el análisis con Whisper responde sin error.
- [ ] **4.6** El resultado muestra PCPM, velocidad, calidad y prosodia.
- [ ] **4.7** Las palabras incorrectas/omitidas aparecen resaltadas en el texto original.
- [ ] **4.8** El diálogo de resultado se puede scrollear completo, sin cortarse.

---

## 5. Sincronización con anahuac

Esta versión arregla un bug por el que las evaluaciones de ProsodIA quedaban
invisibles en el gráfico de comparación interanual de UTP.

- [ ] **5.1** Tras guardar la evaluación, aparece en el dashboard de UTP (`/utp/velocidad-lectora`).
- [ ] **5.2** **Aparece también en el gráfico de comparación interanual** al filtrar por el semestre actual. Este es el bug recién corregido — si no aparece ahí, `semestre` sigue llegando nulo.
- [ ] **5.3** *(opcional, en la base)* Confirmar que `app_build` y `reading_cpl` llegaron con valor y no nulos:
  ```sql
  SELECT id, fecha, pcpm, semestre, app_build, reading_cpl
  FROM velocidad_lectora
  WHERE student_id IS NOT NULL
  ORDER BY id DESC LIMIT 5;
  ```
  `reading_cpl` debería estar entre 45 y 75.

- [ ] **5.4** Evaluar con la tablet **sin conexión** y confirmar que al recuperar red la evaluación se sincroniza sola.

---

## Si algo falla

1. Anota el número de ítem y el modelo de tablet.
2. El panel de logs de la app (gesto de 5 toques) tiene el detalle técnico.
3. Rollback disponible: `ota/releases/prosodia-prev.apk` y `version-prev.json`.
