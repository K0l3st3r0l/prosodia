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
- Android (tablets) en modo Landscape
- Mínimo Android 8.0 (API 26)
