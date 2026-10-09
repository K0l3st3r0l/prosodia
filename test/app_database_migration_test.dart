import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prosodia/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Verifica la migración real de `AssessmentSessions` v1 → v2 (agrega
/// `appBuild`/`readingCpl` nullable): las filas existentes no se pierden ni
/// se alteran, y quedan con las columnas nuevas en `null` — "condiciones de
/// render desconocidas", no un dato faltante.
///
/// El esquema v1 se arma a mano con `sqlite3` porque el proyecto no usa el
/// tooling de snapshots de `drift_dev`; esto reproduce el archivo tal como
/// habría quedado instalado en una tablet antes de este cambio.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('prosodia_migration_test');
    dbFile = File(p.join(tempDir.path, 'prosodia.sqlite'));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('la migración v1 → v2 preserva las filas existentes', () async {
    final fecha = DateTime.utc(2026, 5, 4, 10, 30);
    final fechaEpoch = fecha.millisecondsSinceEpoch ~/ 1000;

    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE assessment_sessions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students (id),
        fecha INTEGER NOT NULL,
        pcpm REAL NOT NULL,
        velocidad TEXT NOT NULL,
        nivel_logro TEXT NOT NULL,
        calidad TEXT NOT NULL,
        nivel_logro_calidad TEXT NOT NULL,
        prosodia TEXT NOT NULL,
        audio_path TEXT,
        synced INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)),
        synced_at INTEGER
      );
    ''');
    raw.execute(
      '''
      INSERT INTO assessment_sessions
        (id, student_id, fecha, pcpm, velocidad, nivel_logro, calidad,
         nivel_logro_calidad, prosodia, audio_path, synced, synced_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        1,
        42,
        fechaEpoch,
        87.5,
        'Medio Alta',
        'Adecuado',
        'unidades_cortas',
        'Adecuado',
        'básica',
        null,
        1,
        fechaEpoch,
      ],
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final rows = await db.select(db.assessmentSessions).get();
    expect(rows, hasLength(1));

    final historical = rows.single;
    expect(historical.id, 1);
    expect(historical.studentId, 42);
    expect(historical.pcpm, 87.5);
    expect(historical.velocidad, 'Medio Alta');
    expect(historical.nivelLogro, 'Adecuado');
    expect(historical.calidad, 'unidades_cortas');
    expect(historical.nivelLogroCalidad, 'Adecuado');
    expect(historical.prosodia, 'básica');
    expect(historical.synced, isTrue);
    expect(
      historical.appBuild,
      isNull,
      reason: 'fila previa a la migración: condiciones de render desconocidas',
    );
    expect(historical.readingCpl, isNull);

    // Una fila nueva, guardada después de la migración, sí trae las
    // condiciones de render reales.
    final newId = await db.insertAssessment(
      AssessmentSessionsCompanion.insert(
        studentId: 42,
        fecha: DateTime.utc(2026, 7, 30),
        pcpm: 95.0,
        velocidad: 'Rápida',
        nivelLogro: 'Sobresaliente',
        calidad: 'fluida',
        nivelLogroCalidad: 'Sobresaliente',
        prosodia: 'adecuada',
        appBuild: const Value(36),
        readingCpl: const Value(62.5),
      ),
    );
    final fresh = await (db.select(
      db.assessmentSessions,
    )..where((t) => t.id.equals(newId))).getSingle();
    expect(fresh.appBuild, 36);
    expect(fresh.readingCpl, 62.5);
  });

  // v3 agrega los datos crudos de la lectura (palabras leídas, errores,
  // duración, si hubo análisis de Whisper) para que anahuac muestre PPM.
  test('la migración v2 → v3 preserva las filas existentes', () async {
    final fechaEpoch = DateTime.utc(2026, 10, 8).millisecondsSinceEpoch ~/ 1000;

    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE assessment_sessions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        student_id INTEGER NOT NULL REFERENCES students (id),
        fecha INTEGER NOT NULL,
        pcpm REAL NOT NULL,
        velocidad TEXT NOT NULL,
        nivel_logro TEXT NOT NULL,
        calidad TEXT NOT NULL,
        nivel_logro_calidad TEXT NOT NULL,
        prosodia TEXT NOT NULL,
        audio_path TEXT,
        synced INTEGER NOT NULL DEFAULT 0 CHECK ("synced" IN (0, 1)),
        synced_at INTEGER,
        app_build INTEGER,
        reading_cpl REAL
      );
    ''');
    raw.execute(
      '''
      INSERT INTO assessment_sessions
        (id, student_id, fecha, pcpm, velocidad, nivel_logro, calidad,
         nivel_logro_calidad, prosodia, synced, app_build, reading_cpl)
      VALUES (1, 389, ?, 1.44, 'Lenta', 'Muy Bajo lo Esperado', 'fluida',
              'Muy Bajo lo Esperado', 'adecuada', 0, 50, 64.0)
      ''',
      [fechaEpoch],
    );
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final historical = (await db.select(db.assessmentSessions).get()).single;
    expect(historical.pcpm, 1.44);
    expect(historical.appBuild, 50);
    expect(historical.readingCpl, 64.0);
    expect(historical.synced, isFalse, reason: 'sigue pendiente de envío');
    expect(historical.palabrasLeidas, isNull);
    expect(historical.errores, isNull);
    expect(historical.duracionSegundos, isNull);
    expect(historical.whisperAnalizado, isNull);

    final newId = await db.insertAssessment(
      AssessmentSessionsCompanion.insert(
        studentId: 389,
        fecha: DateTime.utc(2026, 10, 9),
        pcpm: 42.5,
        velocidad: 'Medio Baja',
        nivelLogro: 'Bajo lo Esperado',
        calidad: 'fluida',
        nivelLogroCalidad: 'Bajo lo Esperado',
        prosodia: 'adecuada',
        palabrasLeidas: const Value(90),
        errores: const Value(5),
        duracionSegundos: const Value(120),
        whisperAnalizado: const Value(true),
      ),
    );
    final fresh = await (db.select(
      db.assessmentSessions,
    )..where((t) => t.id.equals(newId))).getSingle();
    expect(fresh.palabrasLeidas, 90);
    expect(fresh.errores, 5);
    expect(fresh.duracionSegundos, 120);
    expect(fresh.whisperAnalizado, isTrue);
  });
}
