# Arquitectura Flutter — ProsodIA

## Stack técnico

| Componente | Tecnología |
|------------|------------|
| Framework | Flutter/Dart |
| Orientación | Landscape (tablets Android) |
| Arquitectura | Clean Architecture, feature-first |
| Estado | Riverpod |
| DB local | Drift (SQLite, offline-first estricto) |
| Audio | `record` package (captura WAV/PCM) |
| Playback | `just_audio` |
| HTTP | `dio` |
| OTA | `android_package_installer` + `dio` |

## Estructura de carpetas

```
lib/
  core/
    auth/           — manejo JWT, sesión
    network/        — cliente Dio con interceptor
    database/       — Drift app_database.dart
    constants.dart  — BASE_URL, OTA_URL
  features/
    auth/           — login, pantalla de inicio de sesión
    students/       — lista estudiantes, sincronización
    assessment/     — pantalla evaluación, lógica pedagógica
    audio/          — grabación, playback, guardado WAV
    results/        — historial local de evaluaciones
    sync/           — cola offline→online con anahuac
    ota_update/     — descarga e instalación de actualizaciones
```

## Principios de diseño

- **Offline-first estricto**: toda interacción se guarda en Drift primero
- **Sin distracciones**: UI limpia para uso en aula con niños
- **Landscape obligatorio**: bloqueado por `setPreferredOrientations`
- **Material 3**: design system de Flutter
- **Sync optimista**: envía al servidor cuando hay red, no bloquea al usuario
