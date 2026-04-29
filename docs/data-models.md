# Modelos de datos — ProsodIA

## Entidades locales (Drift / SQLite en la tablet)

### Student
```
id           int       PK — mismo id que en anahuac
rut          String
nombreCompleto String  — "apellido nombre1"
curso        String    — "1°", "2°", ..., "8°", "kinder", "prekinder"
activo       bool
syncedAt     DateTime
```

### AssessmentSession
```
id                 int       PK local, autoincrement
studentId          int       FK → Student.id
fecha              DateTime
pcpm               double    — palabras correctas por minuto
velocidad          String    — "Muy Lenta" | "Lenta" | ... | "Muy Rápida"
nivelLogro         String    — "Muy Bajo lo Esperado" | "Bajo lo Esperado" | "Lo Esperado"
calidad            String    — "silábica" | "palabra_a_palabra" | "unidades_cortas" | "fluida"
nivelLogroCalidad  String
prosodia           String
audioPath          String?   — ruta al archivo WAV local (opcional)
synced             bool      — false hasta enviarlo a anahuac
syncedAt           DateTime?
```

### ReadingText
```
id            int     PK
titulo        String
contenido     String
nivel         String  — curso objetivo ("1°", "2°", etc.)
totalPalabras int
```

## Mapeo con anahuac API

| Campo local (Drift) | Campo API (anahuac) |
|---------------------|---------------------|
| studentId | student_id |
| pcpm | pcpm |
| velocidad | velocidad |
| nivelLogro | nivel_logro_velocidad |
| calidad | calidad |
| nivelLogroCalidad | nivel_logro_calidad |
| prosodia | prosodia |
| fecha | fecha |
