# ProsodIA — Audit responsive (Fase 0)

> Documento de diagnóstico. **No se modificó código de producción para producirlo.**
> Fecha: 2026-07-30 · Commit base: `8390e1a` · Flutter 3.32.0
> Ruta: `/root/apps/prosodia`

---

## 1. Superficie y modo

| Campo | Valor |
|---|---|
| Superficie principal | `AssessmentScreen` (`lib/features/assessment/presentation/assessment_screen.dart`) |
| Superficie secundaria | `LoginScreen` (`lib/features/auth/presentation/login_screen.dart`) |
| Superficie terciaria | `LogScreen` (debug, 5 taps en el título) |
| **Modo** | **Operate** — el docente completa una tarea cronometrada con un niño al lado. Prioridad: escaneabilidad, claridad de estado, cero fricción. No es una superficie de persuasión. |
| Usuario | Profesor de 1° a 8° básico / equipo UTP (`docs/product-brief.md`) |
| Tarea principal | Curso → estudiante → lectura → grabar → revisar IA → guardar |
| Estados | `idle`, `recording`, `analyzing`, `reviewing` (`EvalState`) + offline, sin estudiantes, sin lecturas, Whisper caído |

### Verdad de producto relevante

`docs/product-brief.md` declara: **"Android (tablets) en modo Landscape"**. `lib/main.dart:17-20` lo hace cumplir con `setPreferredOrientations([landscapeLeft, landscapeRight])`.

**Esto contradice parcialmente el encargo**, que pide verificar portrait a 360x640 / 411x891 / 768x1024. Ver §6.

---

## 2. Método

1. Grafo del proyecto (`graphify-out/graph.json`, `GRAPH_REPORT.md`) para ubicar comunidades y responsabilidades antes de cualquier grep.
2. Lectura completa de las 3 superficies + `app_theme.dart` + `main.dart` + widgets core.
3. Conteo determinista de anti-patrones con `grep -nE` sobre el árbol `lib/`.
4. Baseline de gates: `flutter analyze` → **No issues found (6.6s)**.

**Límite honesto:** no hay browser/CUA aplicable (app Flutter nativa) y no hay device Android conectado a este VPS. Las afirmaciones marcadas `[inspección]` son riesgo derivado del código, no overflow observado. Se convierten en `[verificado]` o se descartan en Fase 3 con un harness de widget tests que mide overflow real por viewport.

---

## 3. Inventario de anti-patrones

### Conteo determinista

| Métrica | Valor | Detalle |
|---|---|---|
| `assessment_screen.dart` | 3.415 líneas | 1 sola clase `State`, 30+ métodos `_buildX` |
| Dimensiones fijas (`width:`/`height:` numéricos) | **80** | 55 dentro de `_buildReadingCoverArt` (arte decorativo), **25 en layout real** |
| `fontSize:` literales | 6 | líneas 733, 1577, 1959, 2083, 3376, 3406 |
| `size:` literales (iconos) | 12 | |
| `EdgeInsets` literales | 45 | |
| `SizedBox` de separación | 76 | |
| Usos de `MediaQuery`/`LayoutBuilder`/`SafeArea` en toda la app | **7** | y 4 de ellos están en un solo `build()` |
| `OrientationBuilder` | **0** | |
| Capa responsive | **no existe** | |

### Hallazgos priorizados

---

#### 🔴 P0-1 — El layout de dos paneles es incondicional; no existe layout de una columna

`assessment_screen.dart:3181-3341`

El `build()` siempre devuelve un `Row` con `SizedBox(width: leftPanelWidth)` + `Expanded`. `leftPanelWidth` (línea 2650) vale `w * 0.38` cuando `w < 700`.

- A 360 dp de ancho (teléfono portrait) el panel izquierdo mide **137 dp**, con ~101 dp útiles tras padding. Ahí viven dos `DropdownButtonFormField`, el cronómetro y todo el bloque de revisión manual.
- No hay ninguna rama que apile los paneles. El "layout teléfono apilado y scrolleable" del encargo **no existe hoy en ninguna forma**.

`[inspección]` Overflow horizontal garantizado en los dropdowns y en `_buildAudioPlayer` bajo 500 dp de ancho total.

---

#### 🔴 P0-2 — `isPhoneLandscape` es un proxy de altura, no una clasificación de dispositivo

`assessment_screen.dart:550, 2506, 2649` → `MediaQuery.sizeOf(context).height < 450`

Este único booleano controla 30+ decisiones visuales (paddings, tamaños de portada, altura de tarjetas, tipografía del cronómetro, visibilidad de subtítulos). Problemas:

1. Se recalcula en tres lugares distintos, dos de ellos con fuentes diferentes (`MediaQuery` vs `constraints`), que **divergen** cuando hay teclado en pantalla o insets del sistema.
2. Confunde "pantalla baja" con "teléfono". Una tablet 800x1280 en landscape (h=800) y un teléfono 411x891 en landscape (h=411) caen en clases distintas por altura, pero la decisión correcta (¿cuánta densidad de información cabe?) depende del **lado corto del dispositivo**, que es invariante a la rotación.
3. `isCompact = w < 700` (línea 2648) es un segundo eje no coordinado con el primero. Las combinaciones `isCompact && !isPhoneLandscape` producen mezclas nunca diseñadas (p. ej. tablet portrait 768x1024 → `isCompact=false`, `isPhoneLandscape=false`, panel de 352 dp fijo y galería a 1 columna).

---

#### 🟠 P1-1 — Tarjeta de lectura con altura fija que no acomoda su contenido

`assessment_screen.dart:2283-2410` (tarjeta) + `2423, 2486-2490` (caja fija)

```dart
final cardHeight = isPhoneLandscape ? 200.0 : (isCompact ? 322.0 : 352.0);
...
SizedBox(width: cardWidth, height: cardHeight, child: _buildReadingCard(...))
```

Dentro: portada de altura fija (196/168/100) + `Expanded` con título (`maxLines: 2`), extracto (`maxLines: 3..4`) y una fila de pie.

Presupuesto a `isCompact` (322 – 168 = **154 dp** para el bloque de texto), con `textScaler = 1.3`:

| Elemento | 1.0x | 1.3x |
|---|---|---|
| Título 2 líneas (titleMedium 16, h≈1.2) | 38 | 50 |
| Gap | 8 | 8 |
| Extracto 3 líneas (bodyMedium 14, h=1.45) | 61 | 79 |
| Fila de pie (chip v8 + texto) | ~38 | ~44 |
| Padding vertical de la tarjeta | 34 | 34 |
| **Total** | **179** | **215** |
| **Disponible** | **154** | **154** |

`[inspección]` Desborda **ya a 1.0x** con títulos de 2 líneas, y por ~61 dp a 1.3x. Es el candidato número uno a `RenderFlex overflowed`.

---

#### 🟠 P1-2 — Filas sin `Expanded` que desbordan con texto largo

`assessment_screen.dart:471-479` (`_resultRow`)

```dart
Row(children: [ Text('$label: '), Text(value) ])   // ningún Flexible
```

Se usa en el diálogo de guardado (línea 437-441) y en `_buildResultsCard` (1851-1855). El valor más largo real es `'Muy Bajo lo Esperado'` (`assessment_calculator.dart`), que con la etiqueta da `Nivel de logro: Muy Bajo lo Esperado` ≈ 35 caracteres.

`[inspección]` En un `AlertDialog` sobre 360 dp (ancho interno ≈ 268 dp) desborda a 1.0x. En `_buildResultsCard` dentro del panel derecho comprimido, también.

Mismo patrón sin `Expanded`:
- `_buildAudioPlayer` (2203-2276): botón 48 + `Expanded` + pastilla de estado de ancho intrínseco (`'Reproduciendo'` + icono ≈ 110 dp). En el panel izquierdo compacto (137 dp) desborda.
- `_buildReviewTextCard` (754-786): etiqueta + badge `'N palabras totales'` sin `Flexible`.

---

#### 🟠 P1-3 — `AppBar` con presupuesto horizontal no acotado

`assessment_screen.dart:2509-2641`

`actions` contiene: pastilla de estado con texto (`'Analizando audio'`), pastilla de versión, y hasta 3 `IconButton` de 48 dp = 144 dp. El `title` es un `Row` con `mainAxisSize: MainAxisSize.min` que contiene logo + dos líneas de texto sin `Flexible`.

Presupuesto a 360 dp de ancho: título ≈ 200 + acciones ≈ 300 = 500 dp sobre 360 disponibles.

`[inspección]` Overflow en el `AppBar` en cualquier ancho < ~520 dp, y en 640 dp (teléfono landscape) cuando `textScaler` ≥ 1.2 ensancha las pastillas.

---

#### 🟠 P1-4 — Tap targets bajo 48 dp en el control más usado de la revisión

`assessment_screen.dart:3393-3413` (`_chipSelector`) + `app_theme.dart:209-219` (`chipTheme`)

```dart
ChoiceChip(label: Text(_formatChoiceLabel(o), style: const TextStyle(fontSize: 11)))
// chipTheme.padding = symmetric(horizontal: 10, vertical: 8)
```

Altura resultante ≈ 11 × 1.2 + 16 + 2 = **~31 dp**. Son 8 chips (4 de calidad + 4 de prosodia) que el docente toca en cada evaluación, con el dedo, con un niño esperando. Mínimo Material/WCAG 2.5.5: 44–48 dp.

`fontSize: 11` hardcodeado además ignora la escala tipográfica del theme.

---

#### 🟠 P1-5 — Falta `SafeArea` en el cuerpo de `AssessmentScreen`

`assessment_screen.dart:2642-2645`

`LoginScreen` sí lo tiene (`login_screen.dart:66`). `AssessmentScreen` no. En landscape —la orientación de producción— el display cutout y la barra de gestos quedan en los **bordes laterales**, exactamente donde vive el panel izquierdo de selección. El `AppBar` cubre el inset superior pero nada cubre los laterales ni el inferior.

---

#### 🟠 P1-6 — Estados sin scroll que dependen de que el contenido "quepa"

- `_buildEmptyState` (636-687): `Center` → `Column` sin scroll. Logo 88 + título + párrafo + 3 chips ≈ 300 dp; a 1.3x ≈ 380 dp. En un panel de 360 dp de alto (teléfono landscape) desborda.
- `_buildAnalyzingPanel` (1635-1685): `Center` → círculo fijo de 92 + dos textos. Mismo patrón.

---

#### 🟡 P2-1 — Números mágicos de breakpoint dispersos y sin justificación

| Línea | Valor | Significado implícito |
|---|---|---|
| 550, 2506, 2649 | `450` | "pantalla baja" |
| 2648 | `700` | "compacto" |
| 2417-2421 | `980`, `520` | columnas de la galería |
| 2650 | `352.0` | ancho del panel izquierdo |
| `login_screen.dart:95` | `980` | "compacto" (¡mismo número, otra semántica!) |

Cinco umbrales, ninguno derivado de contenido ni compartido entre pantallas. `980` significa dos cosas distintas en dos archivos.

---

#### 🟡 P2-2 — La medida de lectura no está acotada

`assessment_screen.dart:3308-3332`

El texto de lectura ocupa `Expanded` → `width: double.infinity`. En una tablet grande landscape (1280 dp – panel 352 – paddings ≈ 850 dp útiles) a `fontSize: 25` la línea alcanza **~95 caracteres**. El rango legible para lectura sostenida es 45–75 cpl, y este texto lo lee **un niño en voz alta bajo cronómetro**: la vuelta de línea es precisamente donde se pierde y se penaliza su PCPM.

Es el defecto responsive con mayor impacto pedagógico del audit: aprovechar el ancho de la tablet no significa estirar el párrafo.

---

#### 🟡 P2-3 — El arte de portada de respaldo no escala con su contenedor

`assessment_screen.dart:1051-1604` — 55 dimensiones fijas dibujadas para un lienzo de 196 dp.

`coverHeight` puede valer 100 (`isPhoneLandscape`), pero las escenas siguen posicionando elementos a `bottom: 44`, `height: 72`, etc. El `Stack` no lanza error (recorta), así que el síntoma es arte cortado, no una excepción.

Solo afecta al **fallback** cuando falta el PNG en `assets/reading_covers/` (24 portadas presentes hoy).

---

#### 🟡 P2-4 — Gráficos con geometría fija

- `_buildDistributionChart` (1926-1979): `SizedBox(height: 150)`, `barWidth: 18`, `reservedSize: 28`, etiquetas a `fontSize: 8`. A 1.3x las etiquetas (10.4 dp) colisionan entre sí en 6 categorías.
- `_buildProgressionChart` (2041-2098): `height: 150` fija; etiqueta de línea a `fontSize: 9`.

`fontSize: 8` y `9` están por debajo de cualquier mínimo de legibilidad y no participan de la escala tipográfica.

---

#### 🔵 P3-1 — Tokens de color duplicados fuera del theme

`Color(0xFFCEC7F0)` aparece **12 veces** literal en `assessment_screen.dart` (es `colorScheme.outline`, ya definido en `app_theme.dart:42`). Igual `0xFFEF4444` (danger), `0xFFB91C1C`/`0xFFFEE2E2` (resaltado de error de lectura), `0xFFB54708`/`0xFFFFF5E8` (warning).

#### 🔵 P3-2 — Parámetro muerto

`_buildReviewPanel(bool isCompact, double textFontSize)` (línea 1687): `textFontSize` no se usa en el cuerpo. El analyzer no marca parámetros no usados.

#### 🔵 P3-3 — Una sola clase `State` de 3.415 líneas

30+ métodos `_buildX` acoplados al `State`, por lo que **ninguno es testeable sin montar la pantalla completa** (que arrastra Drift/SQLite, `AudioRecorder`, `AudioPlayer`, `PackageInfo` y red). Esta es la razón estructural por la que no existe hoy ninguna verificación de overflow: no hay nada que montar aisladamente.

---

## 4. Breakpoints propuestos

### Eje 1 — Clase de dispositivo, por `shortestSide`

| Clase | `shortestSide` | Dispositivos objetivo |
|---|---|---|
| `phone` | `< 600` | 360x640, 411x891 |
| `tablet` | `600 – 1024` | 768x1024, 800x1280 |
| `tabletLarge` | `> 1024` | 1200x1920 |

**Justificación de los cortes:**

- **`shortestSide` en vez de `width`**: es invariante a la rotación. Una tablet de 800x1280 es la misma tablet en portrait y en landscape; con `width` cambiaría de clase al rotar y la densidad de información saltaría sin motivo. Es también el criterio que usa el propio Flutter en `MediaQueryData` para deducir formato de dispositivo.
- **600**: es la frontera canónica `sw600dp` de Android. El sistema operativo ya conmuta sus propios recursos ahí, así que alinearse evita que la app cambie de personalidad en un punto distinto al del sistema. En contenido: bajo 600 dp de lado corto no caben simultáneamente un panel de control (~320 dp mínimo para dropdowns con nombres completos) y una medida de lectura legible (≥45 caracteres ≈ 340 dp a 18 sp). Es exactamente el punto donde el layout de dos paneles deja de ser viable.
- **1024**: `sw1024dp` ≈ tablet de 10″+ . Por encima aparece presupuesto para la tercera columna de la galería y para subir la lectura a 26 sp manteniendo la medida acotada. Debajo, la tercera columna deja tarjetas bajo los 260 dp donde el título se parte en 3 líneas.

Los tres viewports objetivo del encargo caen limpios: 360/411 → `phone`; 768/800 → `tablet`; 1200 → `tabletLarge`.

### Eje 2 — Estrategia de paneles, por ancho disponible (`LayoutBuilder`, no `MediaQuery`)

Independiente del eje 1, porque el ancho útil del cuerpo no es el ancho de la pantalla (padding, insets, futuros paneles).

| Estrategia | Ancho disponible | Composición |
|---|---|---|
| `stacked` | `< 720` | Una columna scrolleable: preparación → cronómetro → lectura → revisión |
| `dual` | `≥ 720` | Panel de control fijo + área de trabajo (layout actual, corregido) |

**720** = 320 (panel mínimo utilizable) + 12 (gap) + 340 (medida de lectura mínima legible) + 48 (paddings). Es un corte derivado del contenido, no un número redondo.

### Eje 3 — Holgura vertical

| Flag | Condición | Efecto |
|---|---|---|
| `isShortViewport` | altura disponible `< 480` | Reduce el ritmo vertical, oculta subtítulos secundarios, baja la portada |

Reemplaza al actual `height < 450` calculado en tres sitios, con **una sola fuente** derivada de `constraints`, no de `MediaQuery` (así el teclado en pantalla no lo dispara falsamente).

---

## 5. Matriz superficies × breakpoints

Estado **actual** (`✗` roto · `⚠` degradado · `✓` correcto). Portrait marcado `(bloqueado)` donde el lock de orientación impide que ocurra en producción hoy.

### `AssessmentScreen`

| Viewport | Clase | Landscape (producción) | Portrait |
|---|---|---|---|
| 360x640 | phone | ⚠ 640x360 · AppBar al límite, tarjetas 200 dp, panel 260 dp | ✗ (bloqueado) panel de 137 dp, dropdowns inservibles |
| 411x891 | phone | ⚠ 891x411 · panel 260 dp, extracto oculto | ✗ (bloqueado) panel de 156 dp |
| 768x1024 | tablet | ✓ 1024x768 · caso mejor cubierto hoy | ⚠ (bloqueado) panel 352 fijo, galería a 1 columna, mucho aire muerto |
| 800x1280 | tablet | ✓ 1280x800 · medida de lectura ya larga (~95 cpl) | ⚠ (bloqueado) |
| 1200x1920 | tabletLarge | ⚠ 1920x1200 · panel 352 desproporcionado, lectura ~140 cpl | ⚠ (bloqueado) |

### `LoginScreen`

| Viewport | Landscape | Portrait |
|---|---|---|
| 360x640 | ⚠ hero + form apilados, tipografía sin bajar | ✓ (bloqueado) |
| 768x1024 | ⚠ `isCompact` a 1024 → apilado cuando cabría lado a lado | ✓ (bloqueado) |
| 1200x1920 | ✓ dos columnas, panel de 440 fijo | ✓ (bloqueado) |

`LoginScreen` está notablemente mejor: tiene `SafeArea`, `SingleChildScrollView` y `LayoutBuilder`. Sus defectos son de escala tipográfica y de un umbral (`980`) que no coincide con ningún breakpoint del sistema.

### `LogScreen`

| Todos los viewports | ⚠ `fontSize: 12` fijo, `ListView` sin `SafeArea`; superficie de debug, prioridad baja |

---

## 6. Contradicción de alcance: el lock de orientación

`main.dart:17-20` bloquea la app en landscape, y `docs/product-brief.md:26` lo declara como decisión de producto.

El encargo pide verificar portrait en cinco viewports. Ambas cosas no pueden ser ciertas a la vez en producción.

**Cómo lo resuelvo, salvo indicación contraria:**

1. **No toco `main.dart`.** El lock es comportamiento de producto, no refactor visual; el encargo de la Fase 2 dice explícitamente "refactor visual puro".
2. **Construyo los layouts portrait de todas formas.** El layout `stacked` es la respuesta correcta tanto a "teléfono portrait" como a "ancho disponible chico", así que se paga solo. Además vuelve la app defensiva ante un `setPreferredOrientations` no honrado (kioskos, launchers educativos, ventanas de Android en escritorio).
3. **Verifico portrait igualmente** en Fase 3, como robustez.

Desbloquear la orientación es **una línea** en `main.dart` y queda a decisión tuya. Lo dejo señalado, no ejecutado.

---

## 7. Plan de implementación

| Fase | Alcance | Gate |
|---|---|---|
| **1** | `lib/core/responsive/` — breakpoints, escala de espaciado, escala tipográfica. Extensión de `app_theme.dart` con los tokens de color que hoy están literales. Cero cambios de layout. | `flutter analyze` limpio |
| **2** | Extracción de `assessment_screen.dart` a `lib/features/assessment/presentation/widgets/`. Widgets sin estado, con datos por parámetro. `AssessmentScreen` conserva **toda** la lógica: grabación, Whisper, `AssessmentCalculator`, guardado, sync. Layout `dual` + `stacked`. | `flutter analyze` limpio |
| **3** | Harness de overflow: cada widget extraído × 5 viewports × 2 orientaciones × `textScaler` 1.0/1.3. `SafeArea`, tap targets, medida de lectura acotada. | tests verdes + `flutter analyze` limpio |

### Resultado (cerrado 2026-07-30)

| Hallazgo | Estado |
|---|---|
| P0-1 layout de dos paneles incondicional | Resuelto — `PaneStrategy.stacked` bajo 720 dp |
| P0-2 `isPhoneLandscape` triple e incoordinado | Resuelto — tres ejes en `Responsive`, una sola resolución |
| P1-1 tarjeta de lectura con altura fija | Resuelto — `minHeight`, la tarjeta crece |
| P1-2 filas sin `Expanded` | Resuelto y **verificado por test** (`ResultRow` desbordaba de verdad) |
| P1-3 `AppBar` sin presupuesto | Resuelto — degradación explícita subtítulo → versión → etiqueta de estado |
| P1-4 tap targets < 48 dp | Resuelto — `chipTheme` + `androidTapTargetGuideline` como gate |
| P1-5 falta `SafeArea` | Resuelto |
| P1-6 estados sin scroll | Resuelto |
| P2-1 umbrales mágicos | Resuelto — cinco umbrales → tres ejes justificados |
| P2-2 medida de lectura sin acotar | Resuelto — ~64 cpl, con test de rango |
| P2-3 arte de portada sin escalar | Resuelto — lienzo de diseño 320×196 + `FittedBox` |
| P2-4 gráficos con geometría fija | Resuelto — alto y ancho de barra derivados del espacio real |
| P3-1 tokens de color duplicados | Resuelto — roles nuevos en `app_theme.dart` |
| P3-2 parámetro muerto | Resuelto |
| P3-3 clase `State` de 3.415 líneas | Resuelto — 682 líneas + 11 widgets |

**Defectos que la inspección no había previsto y encontró el harness:**

1. `ReadingView` con encabezado fijo: con título de varias líneas y texto
   escalado, el encabezado solo superaba la altura del panel y el contenido
   quedaba inalcanzable. Se unificó en un solo scroll.
2. `AlertDialog` de resultado sin scroll de contenido.
3. Título de la barra superior (tocable por el gesto de 5 toques) a 30 dp de alto
   en modo compacto.

**Gates:** `flutter analyze` limpio · 169 tests verdes.

**Verificación visual: DEGRADED** — sin emulador ni dispositivo Android en el
VPS; no aplica browser/CUA por ser Flutter nativo. Lo verificado es geometría de
layout y áreas táctiles, no apariencia.

### Invariantes que no se tocan

- `assessment_calculator.dart` — intacto.
- Flujo de grabación (`_startRecording`, `_stopRecording`), llamada a Whisper (`_transcribeAudio`), guardado (`_saveEvaluation`), sync — intactos.
- **Fix MediaTek** (`assessment_screen.dart:1606-1633`): `BoxFit.cover` + `ColoredBox` opaco + `cacheHeight` calculado con `devicePixelRatio`. Se preserva literalmente. Ver `wiki/projects/prosodia/bugs/mediatek-image-banding.md`.
- Gesto oculto de 5 taps al título → `LogScreen`.
- `scripts/release.sh` sigue siendo la única vía de build. No se ejecuta `flutter build` directo. Gradle `Xmx2g` sin tocar.
