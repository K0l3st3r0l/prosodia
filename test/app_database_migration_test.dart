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
}
