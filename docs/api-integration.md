# Integración API — ProsodIA

## Base URL
`https://anahuac.laravas.com/api`

## Endpoints utilizados

### Autenticación
```
POST /users/login
Body: { "email": "...", "password": "..." }
Response: { "token": "...", "user": { "id", "email", "roles" } }
```

### Estudiantes
```
GET /students?activo=true
Headers: Authorization: Bearer <token>
Response: [{ id, rut, nombre1, nombre2, apellido_paterno, apellido_materno, curso }]
```

### Cursos
```
GET /utp/school-courses
Headers: Authorization: Bearer <token>
Response: [{ id, name }]
```

### Guardar evaluación
```
POST /utp/velocidad-lectora
Headers: Authorization: Bearer <token>
Body: {
  "student_id": 43,
  "pcpm": 75.5,
  "velocidad": "Rápida",
  "nivel_logro_velocidad": "Lo Esperado",
  "calidad": "fluida",
  "nivel_logro_calidad": "Lo Esperado",
  "prosodia": "adecuada",
  "fecha": "2026-04-29"
}
Response 201: { "message": "Evaluación guardada", "data": { ... } }
```

## OTA (servidor propio)

### Verificar versión
```
GET https://ota.laravas.com/version.json
Response: { "version": "1.0.0", "build": 1, "url": "...", "changelog": "..." }
```

### Descargar APK
```
GET https://ota.laravas.com/prosodia-latest.apk
```

## Manejo de errores

| HTTP | Acción |
|------|--------|
| 401 | Limpiar token, redirigir a login |
| 404 | Estudiante no encontrado — mostrar mensaje |
| 500 | Guardar en cola offline, reintentar |
| Sin red | Usar datos locales Drift, encolar sync |
