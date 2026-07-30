# ProsodIA — Product Brief

## Nombre del producto
**ProsodIA** — app nativa Android para tablets

## Propósito
Evaluar fluidez lectora en escolares de 1° a 8° básico, midiendo precisión, velocidad (PCPM) y expresión/prosodia.

## Distribución
- OTA desde `ota.laravas.com` (servidor propio, sin Play Store)
- Instalación manual del APK en tablets del colegio

## Autenticación
- Mismas credenciales que anahuac (JWT 24h)
- Endpoint: `POST https://anahuac.laravas.com/api/users/login`

## Sincronización
- Offline-first: guarda evaluaciones localmente en SQLite (Drift)
- Sube resultados a `https://anahuac.laravas.com/api` cuando hay red

## Usuarios objetivo
- Profesores de 1° a 8° básico
- Equipo UTP del colegio

## Plataforma
- Android — tablets (uso principal) y teléfonos
- Tablets (`shortestSide >= 600dp`): forzado a modo Landscape
- Teléfonos (`shortestSide < 600dp`): ambas orientaciones, sin forzar
- **Superficie de lectura: siempre Landscape, en todo dispositivo.** El texto que
  el niño lee en voz alta es el instrumento de medición y su ancho afecta el
  PCPM; en portrait el contenedor se angosta y ninguna de las dos salidas
  (achicar la fuente o aceptar ~29 cpl) es aceptable. El resto de la app
  —login, selección de alumno, resultados— sí rota en teléfono.
- Mínimo Android 8.0 (API 26)
