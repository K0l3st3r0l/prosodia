import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Students extends Table {
  IntColumn get id => integer()();
  TextColumn get rut => text()();
  TextColumn get nombreCompleto => text()();
  TextColumn get curso => text()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class AssessmentSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId => integer().references(Students, #id)();
  DateTimeColumn get fecha => dateTime()();
  RealColumn get pcpm => real()();
  TextColumn get velocidad => text()();
  TextColumn get nivelLogro => text()();
  TextColumn get calidad => text()();
  TextColumn get nivelLogroCalidad => text()();
  TextColumn get prosodia => text()();
  TextColumn get audioPath => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// Build de la app (`PackageInfo.buildNumber`) al momento de la evaluación.
  ///
  /// Nullable a propósito: las filas anteriores a esta columna quedan en
  /// `null`, que es "condiciones desconocidas" — un dato correcto, no uno
  /// faltante que haya que rellenar.
  IntColumn get appBuild => integer().nullable()();

  /// Caracteres por línea **efectivos** del texto de lectura en el render real
  /// de esa evaluación (ver `AppTypeScale.effectiveCplFor` y
  /// `ReadingView.onReadingCplMeasured`). Varía por breakpoint y por el ancho
  /// realmente disponible, no es la constante de diseño (~64).
  RealColumn get readingCpl => real().nullable()();
}

class ReadingTexts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text()();
  TextColumn get contenido => text()();
  TextColumn get nivel => text()();
  IntColumn get totalPalabras => integer()();
}

@DriftDatabase(tables: [Students, AssessmentSessions, ReadingTexts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Para tests: permite abrir sobre un [QueryExecutor] propio (p. ej. una
  /// base file-based creada a mano con un esquema previo) en vez del archivo
  /// real de la app.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(assessmentSessions, assessmentSessions.appBuild);
        await m.addColumn(assessmentSessions, assessmentSessions.readingCpl);
      }
    },
  );

  Future<List<Student>> getAllStudents() => select(students).get();

  Future<List<Student>> getStudentsByCurso(String curso) =>
      (select(students)..where((s) => s.curso.equals(curso))).get();

  Future<void> upsertStudents(List<StudentsCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(students, rows);
    });
  }

  Future<int> insertAssessment(AssessmentSessionsCompanion entry) =>
      into(assessmentSessions).insert(entry);

  Future<List<AssessmentSession>> getPendingSync() =>
      (select(assessmentSessions)..where((a) => a.synced.equals(false))).get();

  /// Evaluaciones sin enviar con su alumno, la más reciente primero.
  ///
  /// `leftOuterJoin` y no `join`: si el alumno dejó de venir en la
  /// sincronización, la evaluación igual tiene que aparecer.
  Future<List<(AssessmentSession, Student?)>> getPendingWithStudent() async {
    final query = select(assessmentSessions).join([
      leftOuterJoin(
        students,
        students.id.equalsExp(assessmentSessions.studentId),
      ),
    ])
      ..where(assessmentSessions.synced.equals(false))
      ..orderBy([OrderingTerm.desc(assessmentSessions.fecha)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        (row.readTable(assessmentSessions), row.readTableOrNull(students)),
    ];
  }

  Future<void> markSynced(int id) =>
      (update(assessmentSessions)..where((a) => a.id.equals(id))).write(
        AssessmentSessionsCompanion(
          synced: const Value(true),
          syncedAt: Value(DateTime.now()),
        ),
      );

  /// Niveles que tienen lecturas sembradas, ordenados.
  ///
  /// Es la fuente de cursos del **modo prueba**: ahí no hay sesión iniciada ni
  /// alumnos sincronizados, así que la lista no puede salir de la tabla de
  /// estudiantes como en el flujo normal. Las lecturas se siembran localmente
  /// al arrancar, así que esto funciona sin red y sin credenciales.
  Future<List<String>> getNivelesConLecturas() async {
    final rows = await (selectOnly(readingTexts, distinct: true)
          ..addColumns([readingTexts.nivel])
          ..orderBy([OrderingTerm.asc(readingTexts.nivel)]))
        .get();
    return rows
        .map((r) => r.read(readingTexts.nivel))
        .whereType<String>()
        .toList();
  }

  Future<List<ReadingText>> getTextsByNivel(String nivel) =>
      (select(readingTexts)
            ..where((t) => t.nivel.equals(nivel))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'prosodia.sqlite'));
    return NativeDatabase(file);
  });
}
